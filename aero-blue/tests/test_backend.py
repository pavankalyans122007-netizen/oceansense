"""Portable safety tests. Mocked macOS operations are not native validation."""
import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[1] / "scripts/aero.py"
spec = importlib.util.spec_from_file_location("aero_backend", MODULE)
aero = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aero)


class BackendSafetyTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="aero-backend-test-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.state = self.base / "state"
        self.state_patch = patch.object(aero, "STATE", self.state)
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)

    def result(self, stdout="", stderr="", code=0):
        return subprocess.CompletedProcess([], code, stdout, stderr)

    def snapshot(self):
        return {"version":1, "id":"original", "dock": {
            "tilesize":{"present":True,"value":57},
            "magnification":{"present":False,"value":None},
            "autohide":{"present":True,"value":False}},
            "wallpapers":[{"screen":1,"url":"file:///original.png"}], "settings":aero.settings_get()}

    def test_restore_preserves_absent_preference_and_unrelated_keys(self):
        with patch.object(aero, "run", return_value=self.result()) as runner, patch.object(aero, "bridge") as bridge:
            aero.restore_snapshot(self.snapshot())
        commands = [call.args[0] for call in runner.call_args_list]
        self.assertIn(["defaults", "delete", "com.apple.dock", "magnification"], commands)
        self.assertIn(["defaults", "write", "com.apple.dock", "tilesize", "-int", "57"], commands)
        self.assertTrue(all(c[:2] != ["defaults", "import"] for c in commands))
        bridge.assert_called_once_with("wallpaper", "restore", json.dumps(self.snapshot()["wallpapers"]))

    def test_dock_snapshot_does_not_capture_unrelated_preferences(self):
        raw = plistlib.dumps({"tilesize":48,"persistent-apps":["private user app"],"magnification":True}).decode()
        with patch.object(aero, "run", return_value=self.result(raw)):
            snapshot = aero.dock_snapshot()
        self.assertEqual(set(snapshot), set(aero.DOCK_KEYS))
        self.assertEqual(snapshot["autohide"], {"present":False,"value":None})

    def test_restore_failure_preserves_settings_and_backup(self):
        aero.settings_set({"clock24h":False})
        before = (self.state / "settings.json").read_bytes()
        with patch.object(aero, "run", return_value=self.result()), patch.object(aero, "bridge", side_effect=aero.AeroError("Display unavailable")):
            with self.assertRaisesRegex(aero.AeroError, "Restore incomplete"):
                aero.restore_snapshot(self.snapshot())
        self.assertEqual((self.state / "settings.json").read_bytes(), before)

    def test_disconnected_wallpaper_display_retains_active_backup(self):
        snapshot = self.snapshot()
        aero.atomic_json(self.state / "active-theme.json", {"backup":"original"})
        with patch.object(aero, "require_mac"), patch.object(aero, "load_backup", return_value=snapshot), patch.object(aero, "run", return_value=self.result()), patch.object(aero, "bridge", return_value={"restoredScreens":[1],"disconnectedScreens":[2]}):
            with self.assertRaisesRegex(aero.AeroError, "reconnect displays"):
                aero.restore_theme(argparse.Namespace(yes=True,backup=None))
        self.assertEqual(aero.read_json(self.state / "active-theme.json"), {"backup":"original"})

    def test_install_move_failure_rolls_back_both_existing_trees(self):
        pairs = []
        for name in ("project", "app"):
            original = self.base / "installed" / name
            original.mkdir(parents=True)
            (original / aero.MARKER).write_text("managed")
            (original / "user-file.txt").write_text("personal-" + name)
            staged = self.base / "stage" / name
            staged.mkdir(parents=True)
            (staged / aero.MARKER).write_text("managed")
            (staged / "new.txt").write_text("new-" + name)
            pairs.append((staged, original))
        real_move = shutil.move
        def interrupted(source, target, *args, **kwargs):
            if Path(source) == pairs[1][0] and Path(target) == pairs[1][1]:
                raise OSError("simulated full disk")
            return real_move(source, target, *args, **kwargs)
        with patch.object(aero.shutil, "move", side_effect=interrupted):
            with self.assertRaisesRegex(aero.AeroError, "previous installations restored"):
                aero.commit_install(pairs)
        for staged, original in pairs:
            self.assertTrue((original / "user-file.txt").is_file())
            self.assertTrue((staged / "new.txt").is_file())

    def test_archive_refuses_unmanaged_and_symlink_paths(self):
        unmanaged = self.base / "unmanaged"
        unmanaged.mkdir()
        (unmanaged / "personal.txt").write_text("keep")
        symlink = self.base / "link"
        symlink.symlink_to(unmanaged, target_is_directory=True)
        for target in (unmanaged, symlink):
            with self.assertRaises(aero.AeroError): aero.archive_managed(target)
        self.assertEqual((unmanaged / "personal.txt").read_text(), "keep")

    def test_uninstall_icon_conflict_preserves_installation(self):
        folder = self.state / "backups/icons/key"
        aero.atomic_json(folder / "target.json", {"target":"/Users/test/Documents"})
        aero.atomic_json(folder / "icon-metadata.json", {"appliedFingerprint":"digest"})
        with patch.object(aero, "require_mac"), patch.object(aero, "bridge", side_effect=aero.AeroError("Icon changed externally")), patch.object(aero, "archive_managed") as archive:
            with self.assertRaisesRegex(aero.AeroError, "Installation retained"):
                aero.uninstall(argparse.Namespace(yes=True))
        archive.assert_not_called()

    def test_weather_offline_uses_only_matching_real_cached_location(self):
        settings = aero.settings_set({"weather":{"city":"Selected city","latitude":12.5,"longitude":79.2}})
        actual_cache = {"available":True,"temperature":22.7,"city":"Selected city","stale":False}
        aero.atomic_json(self.state / "weather-cache.json", {"config":settings["weather"],"fetched":time.time()-1000,"data":actual_cache})
        with patch.object(aero, "fetch_json", side_effect=OSError("offline")):
            weather = aero.weather_data()
            self.assertTrue(weather["stale"])
            self.assertEqual(weather["temperature"], 22.7)
            aero.settings_set({"weather":{"latitude":20.1,"longitude":81.0}})
            other = aero.weather_data()
            self.assertFalse(other["available"])
            self.assertNotIn("temperature", other)

    def test_music_permission_guard_never_invokes_automation(self):
        with patch.object(aero.platform, "system", return_value="Darwin"), patch.object(aero, "run") as runner:
            result = aero.music_data()
        self.assertFalse(result["authorized"])
        runner.assert_not_called()

    def test_artwork_is_bounded_and_encoded_for_widget(self):
        image = self.base / "art.img"
        image.write_bytes(b"\x89PNG\r\n\x1a\n" + b"example")
        self.assertTrue(aero.artwork_data_url(image).startswith("data:image/png;base64,"))
        image.write_bytes(b"not an image")
        self.assertIsNone(aero.artwork_data_url(image))
        image.write_bytes(b"\xff\xd8\xff" + b"x" * 2_000_001)
        self.assertIsNone(aero.artwork_data_url(image))

    def test_deep_merge_preserves_neighbors_and_rejects_bool_as_integer(self):
        before = aero.settings_set({"dock":{"tilesize":64},"permissions":{"music":True}})
        with self.assertRaises(aero.AeroError): aero.settings_set({"dock":{"tilesize":True}})
        with self.assertRaises(aero.AeroError): aero.settings_set({"weather":{"latitude":float("nan"),"longitude":1}})
        with self.assertRaises(aero.AeroError): aero.settings_set({"unknown":"field"})
        after = aero.settings_get()
        self.assertEqual(before, after)
        self.assertFalse(after["permissions"]["calendar"])

    def test_apply_failure_calls_rollback_before_reporting_error(self):
        snapshot = self.snapshot()
        with patch.object(aero, "require_mac"), patch.object(aero, "make_backup", return_value={"id":"original"}), patch.object(aero, "load_backup", return_value=snapshot), patch.object(aero, "bridge", side_effect=aero.AeroError("wallpaper denied")), patch.object(aero, "restore_snapshot") as rollback:
            with self.assertRaisesRegex(aero.AeroError, "rolled back"):
                aero.apply_theme(argparse.Namespace(yes=True,preset=None))
        rollback.assert_called_once_with(snapshot)

    def test_restore_rejects_backup_path_traversal(self):
        for identifier in ("../elsewhere", "/tmp/example", "..", "."):
            with self.assertRaises(aero.AeroError): aero.load_backup(identifier)


if __name__ == "__main__":
    unittest.main()
