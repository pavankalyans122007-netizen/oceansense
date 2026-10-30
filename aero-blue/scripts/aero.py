#!/usr/bin/env python3
"""Aero Blue's user-level backend. Python standard library; never invokes a shell.

Settings-only commands are portable. macOS mutations require --yes and macOS 13+.
The caller must disclose external effects before supplying --yes on the user's behalf.
"""
from __future__ import annotations

import argparse
import base64
import contextlib
import copy
import datetime as dt
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
STATE = Path(os.environ.get("AERO_BLUE_STATE", str(Path.home() / "Library/Application Support/Aero Blue")))
APP = Path.home() / "Applications/Aero Blue Control Center.app"
MARKER = ".aero-blue-managed"
DOCK_KEYS = {"tilesize": "int", "magnification": "bool", "autohide": "bool"}
WIDGET_NAMES = ("clock", "weather", "system", "music", "calendar", "productivity")


class AeroError(Exception):
    pass


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def run(args, *, timeout=30, check=True):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, timeout=timeout)
    if check and result.returncode:
        raise AeroError((result.stderr or result.stdout or "Command failed").strip())
    return result


def read_json(path, fallback=None):
    if not path.exists():
        return copy.deepcopy(fallback)
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise AeroError(f"Cannot read JSON at {path}: {exc}") from exc


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".aero-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


@contextlib.contextmanager
def state_lock():
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / ".lock").open("a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def merge(base, patch):
    result = copy.deepcopy(base)
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def validate(settings):
    defaults = read_json(ROOT / "config/defaults.json")

    def shape(value, reference, path="settings"):
        if not isinstance(value, dict):
            raise AeroError(f"{path} must be an object")
        if set(value) != set(reference):
            raise AeroError(f"Invalid fields at {path}: {sorted(set(value) ^ set(reference))}")
        for key, item in value.items():
            expected = reference[key]
            label = f"{path}.{key}"
            if isinstance(expected, dict):
                shape(item, expected, label)
            elif expected is None:
                if item is not None and (type(item) not in (int, float) or not math.isfinite(item)):
                    raise AeroError(f"{label} must be a finite number or null")
            elif isinstance(expected, bool):
                if type(item) is not bool:
                    raise AeroError(f"{label} must be boolean")
            elif isinstance(expected, int):
                if type(item) is not int:
                    raise AeroError(f"{label} must be an integer")
            elif not isinstance(item, str):
                raise AeroError(f"{label} must be text")

    shape(settings, defaults)
    if settings["schemaVersion"] != 1:
        raise AeroError("Unsupported settings schema")
    if settings["preset"] not in read_json(ROOT / "config/presets.json"):
        raise AeroError("Unknown preset")
    if settings["wallpaper"] not in {f"{theme}-{variant}" for theme in ("aero-sky", "crystal-ocean", "aero-meadow") for variant in ("light", "dark")}:
        raise AeroError("Unknown wallpaper")
    if not 16 <= settings["dock"]["tilesize"] <= 128:
        raise AeroError("Dock tile size must be 16–128")
    weather = settings["weather"]
    if weather["units"] not in ("celsius", "fahrenheit"):
        raise AeroError("Unknown temperature units")
    if len(weather["city"]) > 200:
        raise AeroError("City must be at most 200 characters")
    for key, limit in (("latitude", 90), ("longitude", 180)):
        if weather[key] is not None and not -limit <= weather[key] <= limit:
            raise AeroError(f"Invalid {key}")
    if (weather["latitude"] is None) != (weather["longitude"] is None):
        raise AeroError("Latitude and longitude must be configured together")
    for key, widget in settings["widgets"].items():
        if not 180 <= widget["width"] <= 900 or not all(0 <= widget[axis] <= 30000 for axis in ("x", "y")):
            raise AeroError(f"Invalid position or width for {key}")
    return settings


def settings_get():
    return validate(merge(read_json(ROOT / "config/defaults.json"), read_json(STATE / "settings.json", {})))


def settings_set(patch):
    if not isinstance(patch, dict):
        raise AeroError("Settings patch must be an object")
    with state_lock():
        result = validate(merge(settings_get(), patch))
        atomic_json(STATE / "settings.json", result)
    return result


def require_mac():
    if platform.system() != "Darwin":
        raise AeroError("This operation requires macOS 13 or later. No system settings were changed.")
    version = platform.mac_ver()[0]
    if not version or int(version.split(".")[0]) < 13:
        raise AeroError("Aero Blue requires macOS 13 or later")


def require_yes(args):
    if not args.yes:
        raise AeroError("Review the plan, then pass --yes to authorize this operation. No system settings were changed.")


def bridge_path():
    candidates = [ROOT / "swiftui-app/.build/release/AeroBridge", APP / "Contents/MacOS/AeroBridge"]
    # A bundled copy keeps the executable next to the resource directory.
    if ROOT.name == "project" and ROOT.parent.name == "Resources":
        candidates.insert(0, ROOT.parent.parent / "MacOS/AeroBridge")
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    raise AeroError("AeroBridge is unavailable. Run scripts/build-app.sh on your Mac first.")


def bridge(*args, timeout=30):
    require_mac()
    value = run([bridge_path(), *args], timeout=timeout).stdout
    return json.loads(value or "{}")


def maybe_bridge(*args):
    try:
        return bridge(*args)
    except (AeroError, ValueError, subprocess.SubprocessError) as exc:
        return {"available": False, "error": str(exc)}


def check_system():
    is_mac = platform.system() == "Darwin"
    tools = {name: shutil.which(name) for name in ("swift", "xcode-select", "brew", "python3", "osascript", "sketchybar")}
    report = {"platform": platform.system(), "architecture": platform.machine(), "macOS": platform.mac_ver()[0] or None,
              "supported": is_mac and bool(platform.mac_ver()[0]) and int(platform.mac_ver()[0].split(".")[0]) >= 13,
              "tools": tools, "python": platform.python_version(), "project": str(ROOT),
              "changesMade": False, "cursorSystemWideTested": False,
              "customizations": {"ubersicht": any(p.exists() for p in [Path('/Applications/Übersicht.app'), Path.home()/'Applications/Übersicht.app']),
                "mousecape": any(p.exists() for p in [Path('/Applications/Mousecape.app'), Path.home()/'Applications/Mousecape.app']),
                "sketchybar": bool(tools['sketchybar'])}}
    if is_mac:
        for field, command in (("versionBuild", ["sw_vers"]), ("developerDirectory", ["xcode-select", "-p"]),
                               ("swiftVersion", ["swift", "--version"])):
            if not shutil.which(command[0]):
                report[field] = None
                continue
            result = run(command, check=False)
            report[field] = result.stdout.strip() if result.returncode == 0 else None
        result = run(["system_profiler", "SPHardwareDataType", "SPDisplaysDataType", "-json"], timeout=60, check=False)
        if result.returncode == 0:
            hardware = json.loads(result.stdout)
            # Exclude hardware identifiers from logs; these aren't needed for compatibility.
            for row in hardware.get("SPHardwareDataType", []):
                for key in list(row):
                    if any(word in key.lower() for word in ("serial", "uuid", "provisioning")):
                        row.pop(key)
            report["hardwareAndDisplays"] = hardware
        report["wallpapers"] = maybe_bridge("wallpaper", "get")
        report["dock"] = dock_snapshot()
        for key in ("_HIHideMenuBar", "AppleInterfaceStyle"):
            result = run(["defaults", "read", "NSGlobalDomain", key], check=False)
            report[key] = result.stdout.strip() if result.returncode == 0 else None
        report["appearance"] = maybe_bridge("appearance")
    else:
        report["limitation"] = "Linux/cloud can generate assets and run portable tests; Mac hardware, displays, native build and customizations require your Mac."
    return report


def dock_snapshot():
    result = run(["defaults", "export", "com.apple.dock", "-"], check=False)
    if result.returncode:
        # An absent domain is normal on a fresh account; other errors are not.
        if "does not exist" not in (result.stderr + result.stdout).lower():
            raise AeroError("Unable to read Dock preferences: " + result.stderr.strip())
        data = {}
    else:
        data = plistlib.loads(result.stdout.encode())
    return {key: {"present": key in data, "value": data.get(key)} for key in DOCK_KEYS}


def make_backup():
    require_mac()
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8]
    folder = STATE / "backups" / stamp
    payload = {"version": 1, "id": stamp, "createdAt": now(), "dock": dock_snapshot(),
               "wallpapers": bridge("wallpaper", "get"), "settings": settings_get()}
    atomic_json(folder / "snapshot.json", payload)
    atomic_json(STATE / "latest-backup.json", {"id": stamp})
    return {"id": stamp, "path": str(folder)}


def latest_backup():
    return read_json(STATE / "latest-backup.json", {}).get("id")


def load_backup(identifier=None):
    identifier = identifier or read_json(STATE / "active-theme.json", {}).get("backup") or latest_backup()
    if not identifier or Path(identifier).name != identifier or identifier in (".", ".."):
        raise AeroError("No valid backup was selected")
    payload = read_json(STATE / "backups" / identifier / "snapshot.json")
    if not isinstance(payload, dict) or payload.get("version") != 1 or payload.get("id") != identifier:
        raise AeroError("Backup is missing or invalid")
    return payload


def dock_write(values):
    for key, value in values.items():
        if key not in DOCK_KEYS:
            raise AeroError("Refusing unrelated Dock preference")
        run(["defaults", "write", "com.apple.dock", key, "-" + DOCK_KEYS[key], str(value).lower()])


def restore_snapshot(snapshot):
    errors = []
    for key in DOCK_KEYS:
        original = snapshot["dock"][key]
        try:
            if original["present"]:
                dock_write({key: original["value"]})
            else:
                result = run(["defaults", "delete", "com.apple.dock", key], check=False)
                if result.returncode and "does not exist" not in (result.stderr + result.stdout).lower():
                    raise AeroError(result.stderr.strip())
        except AeroError as exc:
            errors.append(f"Dock {key}: {exc}")
    try:
        wallpaper_result = bridge("wallpaper", "restore", json.dumps(snapshot["wallpapers"]))
        if isinstance(wallpaper_result, dict) and wallpaper_result.get("disconnectedScreens"):
            errors.append("Wallpaper: reconnect displays " + str(wallpaper_result["disconnectedScreens"]) + " and retry this restore; the backup remains active")
    except AeroError as exc:
        errors.append("Wallpaper: " + str(exc))
    run(["killall", "Dock"], check=False)
    if errors:
        raise AeroError("Restore incomplete; backup retained. " + "; ".join(errors))
    atomic_json(STATE / "settings.json", snapshot["settings"])


def apply_theme(args):
    require_mac()
    require_yes(args)
    with state_lock():
        settings = settings_get()
        if args.preset:
            presets = read_json(ROOT / "config/presets.json")
            settings = validate(merge(settings, merge(presets[args.preset], {"preset": args.preset})))
        manifest = read_json(ROOT / "assets/manifest.json")
        asset = next((w for w in manifest["wallpapers"] if w["id"] == settings["wallpaper"]), None)
        if not asset:
            raise AeroError("Selected wallpaper is missing")
        wallpaper = (ROOT / asset["file"]).resolve()
        if not wallpaper.is_file() or not wallpaper.is_relative_to(ROOT):
            raise AeroError("Selected wallpaper is outside the project or missing")
        active = read_json(STATE / "active-theme.json", {})
        saved = make_backup()  # A snapshot precedes each attempted modification.
        original = active.get("backup", saved["id"])
        try:
            bridge("wallpaper", "set", str(wallpaper))
            dock_write(settings["dock"])
            run(["killall", "Dock"], check=False)
            settings["enabled"] = True
            atomic_json(STATE / "settings.json", settings)
            atomic_json(STATE / "active-theme.json", {"backup": original, "lastApplyBackup": saved["id"], "updatedAt": now()})
        except Exception as exc:
            try:
                restore_snapshot(load_backup(saved["id"]))
            except Exception as restore_error:
                raise AeroError(f"Apply failed: {exc}. Rollback incomplete: {restore_error}. Backup {saved['id']} retained.") from exc
            raise AeroError(f"Apply failed and was rolled back: {exc}") from exc
    return {"applied": True, "backup": original, "wallpaper": str(wallpaper), "dock": settings["dock"],
            "note": "Native Dock preferences and wallpaper applied. Cursor manager, icons, widgets and privacy permissions remain opt-in."}


def restore_theme(args):
    require_mac()
    require_yes(args)
    with state_lock():
        snapshot = load_backup(args.backup)
        restore_snapshot(snapshot)
        active = STATE / "active-theme.json"
        if active.exists():
            active.unlink()
    return {"restored": True, "backup": snapshot["id"], "preserved": "Backups, personal files, tasks and unrelated system preferences"}


def archive_managed(path):
    if not path.exists():
        return None
    if path.is_symlink() or not (path / MARKER).is_file():
        raise AeroError(f"Refusing to replace unowned path: {path}")
    destination = STATE / "archives" / (dt.datetime.now().strftime("%Y%m%dT%H%M%S") + "-" + uuid.uuid4().hex[:8] + "-" + path.name)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(destination))
    return str(destination)


def copy_project(destination):
    shutil.copytree(ROOT, destination, ignore=shutil.ignore_patterns(".git", ".build", ".asset-venv", "build", "__pycache__", ".DS_Store", "*.pyc", "backups"))
    (destination / MARKER).write_text("Aero Blue managed installation v1\n")


def commit_install(pairs):
    """Install staged paths with recoverable rollback; never delete old or new trees."""
    previous, installed = [], []
    try:
        for source, target in pairs:
            archive = archive_managed(target)
            previous.append((target, archive))
        for source, target in pairs:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(source), str(target))
            installed.append((source, target))
    except Exception as exc:
        failures = []
        for source, target in reversed(installed):
            try:
                shutil.move(str(target), str(source))
            except OSError as error:
                failures.append(str(error))
        for target, archive in reversed(previous):
            if archive:
                try:
                    if target.exists():
                        raise OSError(f"Cannot restore archive over existing path: {target}")
                    shutil.move(archive, str(target))
                except OSError as error:
                    failures.append(f"Original retained at {archive}: {error}")
        suffix = "; rollback needs attention: " + "; ".join(failures) if failures else "; previous installations restored"
        raise AeroError(f"Install failed: {exc}{suffix}. Staged files were preserved.") from exc
    return [archive for _, archive in previous if archive]


def install(args):
    require_mac()
    require_yes(args)
    if not shutil.which("swift") or not shutil.which("xcode-select"):
        raise AeroError("Install Apple's Xcode 15+ Command Line Tools yourself, then retry. Aero Blue does not install third-party software automatically.")
    destination = STATE / "project"
    for target in (destination, APP):
        if target.exists() and (target.is_symlink() or not (target / MARKER).is_file()):
            raise AeroError(f"Existing unowned path will not be overwritten: {target}")
    run(["bash", ROOT / "scripts/build-app.sh"], timeout=600)
    built_app = ROOT / "swiftui-app/build/Aero Blue Control Center.app"
    if not built_app.is_dir():
        raise AeroError("Native build did not produce an application")
    STATE.mkdir(parents=True, exist_ok=True)
    # Stage first, preserving both previous installs and their unknown/user-added contents.
    stage = Path(tempfile.mkdtemp(prefix="install-", dir=STATE))
    copy_project(stage / "project")
    shutil.copytree(built_app, stage / "Aero Blue Control Center.app")
    (stage / "Aero Blue Control Center.app" / MARKER).write_text("Aero Blue managed installation v1\n")
    archived = commit_install([(stage / "project", destination), (stage / "Aero Blue Control Center.app", APP)])
    stage.rmdir()
    settings_set({})
    return {"installed": True, "app": str(APP), "project": str(destination), "archives": archived,
            "changes": "App and assets installed for this user only. Wallpaper and Dock are unchanged until Apply Theme.",
            "next": "Open the Control Center, review choices, and explicitly apply. Install Übersicht separately to use desktop widgets."}


def status():
    return {"installed": (APP / MARKER).is_file(), "enabled": settings_get()["enabled"], "platform": platform.system(),
            "project": str(ROOT), "stateDirectory": str(STATE), "latestBackup": latest_backup(),
            "widgetsInstalled": (Path.home() / "Library/Application Support/Übersicht/widgets/aero-blue" / MARKER).is_file(),
            "capabilities": {"macOS": platform.system() == "Darwin", "systemWideCursorVerified": False,
                             "signedApplicationIconMutation": False, "loginPersistence": "manual System Settings Login Items"}}


def widget_install(args):
    require_mac()
    require_yes(args)
    if not any(p.exists() for p in (Path('/Applications/Übersicht.app'), Path.home()/'Applications/Übersicht.app')):
        raise AeroError("Übersicht is not installed. Review its compatibility and install it yourself from https://tracesof.net/uebersicht/; no software was installed.")
    source = ROOT / "widgets/aero-blue"
    target = Path.home() / "Library/Application Support/Übersicht/widgets/aero-blue"
    if target.exists() and (target.is_symlink() or not (target / MARKER).is_file()):
        raise AeroError("An unrelated aero-blue widget directory exists; it was not overwritten")
    target.parent.mkdir(parents=True, exist_ok=True)
    STATE.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="widget-stage-", dir=STATE))
    staged_widget = stage / "aero-blue"
    shutil.copytree(source, staged_widget)
    atomic_json(staged_widget / "runtime.json", {"python": str(Path(sys.executable).resolve()), "cli": str(ROOT / "scripts/aero.py")})
    (staged_widget / MARKER).write_text("Aero Blue managed widget v1\n")
    archives = commit_install([(staged_widget, target)])
    stage.rmdir()
    return {"installed": True, "path": str(target), "archives": archives, "next": "Open Übersicht or refresh its widgets; enable panels in Control Center."}


def restore_all_icons():
    restored = []
    for folder in sorted((STATE / "backups/icons").glob("*")):
        record = read_json(folder / "target.json", {})
        metadata = read_json(folder / "icon-metadata.json", {})
        if not record.get("target") or not metadata.get("appliedFingerprint"):
            continue
        target = record["target"]
        try:
            bridge("icon", "restore", target, str(folder))
        except (AeroError, OSError, ValueError, subprocess.SubprocessError) as exc:
            raise AeroError(f"Cannot restore icon for {target}: {exc}. Installation retained; inspect the backup at {folder}.") from exc
        restored.append(target)
    return restored


def uninstall(args):
    require_mac()
    require_yes(args)
    restored_icons = restore_all_icons()
    restored = None
    if (STATE / "active-theme.json").exists():
        restored = restore_theme(argparse.Namespace(yes=True, backup=None))
    archives = []
    for path in (APP, STATE / "project", Path.home() / "Library/Application Support/Übersicht/widgets/aero-blue"):
        if path.exists():
            archived = archive_managed(path)
            if archived:
                archives.append(archived)
    return {"uninstalled": True, "restored": restored, "restoredIcons": restored_icons, "archives": archives,
            "preserved": "All backups, tasks, settings and archived installation files. Remove optional login items manually in System Settings."}


def icon_operation(args):
    require_mac()
    require_yes(args)
    target = Path(args.target).expanduser()
    if target.is_symlink():
        raise AeroError("Symlink icon targets are unsupported")
    target = target.resolve(strict=True)
    if not target.is_relative_to(Path.home()) or any(p.lower().endswith('.app') for p in target.parts):
        raise AeroError("Only user-owned files/folders are supported; application bundles and system paths are protected")
    key = hashlib.sha256(str(target).encode()).hexdigest()
    folder = STATE / "backups/icons" / key
    if args.action == "apply":
        if not folder.exists():
            folder.mkdir(parents=True)
            try:
                bridge("icon", "backup", str(target), str(folder))
                atomic_json(folder / "target.json", {"target": str(target), "createdAt": now()})
            except Exception:
                # Keep incomplete snapshots for diagnosis; do not use them on retry.
                raise
        if not (folder / "target.json").is_file():
            raise AeroError("Incomplete icon backup exists; inspect it before retrying")
        image = Path(args.image).expanduser().resolve(strict=True)
        bridge("icon", "set", str(target), str(image), str(folder))
    else:
        record = read_json(folder / "target.json", {})
        if record.get("target") != str(target):
            raise AeroError("No valid icon backup exists for this target")
        bridge("icon", "restore", str(target), str(folder))
    return {"success": True, "action": args.action, "target": str(target), "backup": str(folder)}


WEATHER_CODES = {0:"Clear sky", 1:"Mainly clear", 2:"Partly cloudy", 3:"Overcast", 45:"Fog", 48:"Rime fog", 51:"Light drizzle", 53:"Drizzle", 55:"Heavy drizzle", 56:"Freezing drizzle", 57:"Freezing drizzle", 61:"Light rain", 63:"Rain", 65:"Heavy rain", 66:"Freezing rain", 67:"Freezing rain", 71:"Light snow", 73:"Snow", 75:"Heavy snow", 77:"Snow grains", 80:"Rain showers", 81:"Rain showers", 82:"Heavy showers", 85:"Snow showers", 86:"Snow showers", 95:"Thunderstorm", 96:"Thunderstorm with hail", 99:"Thunderstorm with hail"}


def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": "AeroBlue/1.0 (personal desktop widget)"})
    # Standard TLS verification remains enabled. No credentials are required.
    with urllib.request.urlopen(request, timeout=8) as response:
        if int(response.headers.get("Content-Length", "0")) > 2_000_000:
            raise AeroError("Weather response unexpectedly large")
        data = response.read(2_000_001)
        if len(data) > 2_000_000:
            raise AeroError("Weather response unexpectedly large")
        return json.loads(data)


def weather_search(city):
    if not city.strip() or len(city) > 200:
        raise AeroError("Enter a city name (1–200 characters)")
    data = fetch_json("https://geocoding-api.open-meteo.com/v1/search?" + urllib.parse.urlencode({"name": city, "count": 8, "language": "en", "format": "json"}))
    return {"results": [{"city": r["name"], "country": r.get("country", ""), "region": r.get("admin1", ""), "latitude": r["latitude"], "longitude": r["longitude"]} for r in data.get("results", [])]}


def weather_data():
    config = settings_get()["weather"]
    if config["latitude"] is None or config["longitude"] is None:
        return {"available": False, "error": "Choose a city or coordinates in Control Center.", "city": config["city"], "stale": False}
    cache_file = STATE / "weather-cache.json"
    cache = read_json(cache_file, {})
    match = cache.get("config") == config
    if match and time.time() - cache.get("fetched", 0) < 900:
        return cache["data"]
    query = {"latitude":config["latitude"], "longitude":config["longitude"], "current":"temperature_2m,weather_code", "daily":"temperature_2m_max,temperature_2m_min,weather_code", "forecast_days":3, "temperature_unit":config["units"], "timezone":"auto"}
    try:
        raw = fetch_json("https://api.open-meteo.com/v1/forecast?" + urllib.parse.urlencode(query))
        current, daily = raw["current"], raw["daily"]
        result = {"available":True, "city":config["city"], "temperature":current["temperature_2m"], "unit":"°F" if config["units"] == "fahrenheit" else "°C", "code":current["weather_code"], "condition":WEATHER_CODES.get(current["weather_code"], "Unknown condition"), "updatedAt":now(), "stale":False,
                  "forecast":[{"date":date, "high":daily["temperature_2m_max"][i], "low":daily["temperature_2m_min"][i], "code":daily["weather_code"][i]} for i,date in enumerate(daily["time"])], "attribution":"Weather data by Open-Meteo.com"}
        atomic_json(cache_file, {"config":config, "fetched":time.time(), "data":result})
        return result
    except (OSError, ValueError, KeyError, IndexError, AeroError) as exc:
        if match and cache.get("data"):
            return dict(cache["data"], stale=True, error="Offline: showing cached forecast. " + str(exc))
        return {"available":False, "city":config["city"], "stale":False, "error":"Weather unavailable: " + str(exc)}


def music_data(action="get"):
    if platform.system() != "Darwin":
        return {"available":False, "authorized":False, "error":"Music integration requires macOS", "artwork":None}
    if not settings_get()["permissions"]["music"]:
        return {"available":False, "authorized":False, "error":"Enable Music integration in Control Center; macOS may request Automation permission.", "artwork":None}
    if run(["pgrep", "-x", "Music"], check=False).returncode:
        return {"available":False, "authorized":True, "error":"Open Apple Music to display the current track.", "artwork":None}
    script = '''var m = Application('Music');
var result = {available:true, authorized:true, artwork:null};
try { var t=m.currentTrack(); result.title=t.name(); result.artist=t.artist(); result.album=t.album(); } catch(e) { result.title='No track selected'; result.artist=''; result.album=''; }
result.playing = m.playerState() === 'playing';
JSON.stringify(result);'''
    if action in ("playpause", "next"):
        control = "playpause" if action == "playpause" else "nextTrack"
        command = run(["osascript", "-l", "JavaScript", "-e", f"Application('Music').{control}();"], check=False)
        if command.returncode:
            return {"available":False,"authorized":False,"error":command.stderr.strip(), "artwork":None}
    result = run(["osascript", "-l", "JavaScript", "-e", script], check=False)
    if result.returncode:
        return {"available":False,"authorized":False,"error":result.stderr.strip(), "artwork":None}
    data = json.loads(result.stdout)
    if data.get("title") and data["title"] != "No track selected":
        data["artwork"] = music_artwork(data)
    return data


def music_artwork(track):
    """Ask Music for its actual artwork; missing/streaming artwork is nullable."""
    identity = hashlib.sha256(json.dumps([track.get(k) for k in ("title", "artist", "album")]).encode()).hexdigest()
    folder = STATE / "music-artwork"
    folder.mkdir(parents=True, exist_ok=True)
    destination = folder / (identity + ".img")
    if destination.is_file():
        return artwork_data_url(destination)
    quoted = str(destination).replace("\\", "\\\\").replace('"', '\\"')
    script = '''set artFile to missing value
try
    tell application "Music" to set artData to raw data of artwork 1 of current track
    set artFile to open for access POSIX file "''' + quoted + '''" with write permission
    set eof artFile to 0
    write artData to artFile
    close access artFile
    return "saved"
on error
    if artFile is not missing value then
        try
            close access artFile
        end try
    end if
    return "unavailable"
end try'''
    result = run(["osascript", "-e", script], check=False)
    if result.returncode == 0 and result.stdout.strip() == "saved" and destination.is_file() and destination.stat().st_size:
        return artwork_data_url(destination)
    # Only this attempt's cache output is removed; user files are never targets.
    if destination.exists():
        destination.unlink()
    return None


def artwork_data_url(path):
    """Übersicht cannot reliably load local file URLs; embed bounded real image data."""
    if path.stat().st_size > 2_000_000:
        return None
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        mime = "image/png"
    elif data.startswith(b"\xff\xd8\xff"):
        mime = "image/jpeg"
    else:
        return None
    return "data:" + mime + ";base64," + base64.b64encode(data).decode("ascii")


def calendar_data(request=False):
    if request:
        return bridge("calendar", "request", timeout=120)
    if not settings_get()["permissions"]["calendar"]:
        return {"authorized":False,"events":[],"error":"Connect Calendar in Control Center to grant access."}
    return maybe_bridge("calendar")


def productivity(action="get", value=None):
    with state_lock():
        path = STATE / "productivity.json"
        data = read_json(path, {"tasks":[], "focus":{"endsAt":None,"durationMinutes":25}})
        if action == "add":
            if not value or not value.strip() or len(value) > 500:
                raise AeroError("Task text must contain 1–500 characters")
            if len(data["tasks"]) >= 200:
                raise AeroError("Limit reached: 200 tasks")
            data["tasks"].append({"id":uuid.uuid4().hex, "text":value.strip(), "completed":False, "createdAt":now()})
        elif action in ("toggle", "remove"):
            task = next((t for t in data["tasks"] if t["id"] == value), None)
            if not task:
                raise AeroError("Task not found")
            if action == "toggle":
                task["completed"] = not task["completed"]
            else:
                data["tasks"].remove(task)
        elif action == "focus":
            try:
                minutes = int(value)
            except (TypeError, ValueError) as exc:
                raise AeroError("Focus duration must be whole minutes") from exc
            if not 1 <= minutes <= 240:
                raise AeroError("Focus duration must be 1–240 minutes")
            data["focus"] = {"endsAt":int((time.time() + minutes * 60) * 1000), "durationMinutes":minutes}
        elif action == "stop":
            data["focus"]["endsAt"] = None
        if action != "get":
            atomic_json(path, data)
    hour = dt.datetime.now().hour
    data["greeting"] = "Good morning" if hour < 12 else "Good afternoon" if hour < 18 else "Good evening"
    return data


def widget_data():
    config = settings_get()
    enabled = lambda name: config["enabled"] and config["widgets"][name]["enabled"]
    return {"settings": config, "system": maybe_bridge("system") if enabled("system") else {"available":False},
            "weather":weather_data() if enabled("weather") else {"available":False},
            "music":music_data() if enabled("music") else {"available":False},
            "calendar":calendar_data() if enabled("calendar") else {"authorized":False,"events":[]},
            "productivity":productivity(), "appearance":maybe_bridge("appearance"), "generatedAt":now()}


def parser():
    p = argparse.ArgumentParser(description="Aero Blue — reversible user-level macOS customization")
    sub = p.add_subparsers(dest="command", required=True)
    for command in ("check", "backup", "status", "system", "widget-data"):
        sub.add_parser(command)
    for command in ("apply", "restore", "install", "uninstall"):
        command_parser = sub.add_parser(command)
        command_parser.add_argument("--yes", action="store_true", help="Authorize the displayed changes")
        if command == "apply":
            command_parser.add_argument("--preset", choices=list(read_json(ROOT / "config/presets.json")))
        if command == "restore":
            command_parser.add_argument("--backup")
    settings = sub.add_parser("settings")
    settings.add_argument("action", choices=("get", "set"))
    settings.add_argument("value", nargs="?")
    weather = sub.add_parser("weather")
    weather.add_argument("action", nargs="?", choices=("get","search"), default="get")
    weather.add_argument("city", nargs="?")
    music = sub.add_parser("music")
    music.add_argument("action", choices=("get", "playpause", "next"), default="get", nargs="?")
    calendar = sub.add_parser("calendar")
    calendar.add_argument("action", choices=("get", "request"), default="get", nargs="?")
    tasks = sub.add_parser("productivity")
    tasks.add_argument("action", choices=("get", "add", "toggle", "remove", "focus", "stop"))
    tasks.add_argument("value", nargs="?")
    icons = sub.add_parser("icons")
    icons.add_argument("action", choices=("apply", "restore"))
    icons.add_argument("target")
    icons.add_argument("image", nargs="?")
    icons.add_argument("--yes", action="store_true")
    widgets = sub.add_parser("widgets")
    widgets.add_argument("action", choices=("install",))
    widgets.add_argument("--yes", action="store_true")
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        command = args.command
        if command == "check": result = check_system()
        elif command == "status": result = status()
        elif command == "settings":
            if args.action == "set" and not args.value:
                raise AeroError("settings set requires a JSON object")
            result = settings_get() if args.action == "get" else settings_set(json.loads(args.value))
        elif command == "backup":
            with state_lock(): result = make_backup()
        elif command == "apply": result = apply_theme(args)
        elif command == "restore": result = restore_theme(args)
        elif command == "install": result = install(args)
        elif command == "uninstall": result = uninstall(args)
        elif command == "system": result = maybe_bridge("system")
        elif command == "weather": result = weather_search(args.city or "") if args.action == "search" else weather_data()
        elif command == "music": result = music_data(args.action)
        elif command == "calendar": result = calendar_data(args.action == "request")
        elif command == "productivity": result = productivity(args.action, args.value)
        elif command == "widget-data": result = widget_data()
        elif command == "icons":
            if args.action == "apply" and not args.image: raise AeroError("icons apply requires a PNG file")
            result = icon_operation(args)
        elif command == "widgets": result = widget_install(args)
        else: raise AeroError("Unsupported command")
        print(json.dumps(result, ensure_ascii=False, allow_nan=False))
        return 0
    except (AeroError, OSError, ValueError, subprocess.SubprocessError) as exc:
        print(json.dumps({"error":str(exc)}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
