# Internal component contract

Target macOS 13+, Swift 5.9 / Xcode 15 Command Line Tools; Linux supports asset generation and portable tests only. All scripts must refuse macOS mutation on other platforms. No automatic sudo, brew installs, login items, system application modifications, or protected resource patches.

## Paths and data

- Source root: `aero-blue/`.
- Installed copy: `~/Library/Application Support/Aero Blue/project/`.
- User state root: `~/Library/Application Support/Aero Blue/`.
- Mutable configuration: state root `settings.json`, seeded from `config/defaults.json`.
- Backups: state root `backups/<timestamp>/`; explicit backup identifier on restore. Preserve personal data and unrelated preferences.
- Bundled Mac app: `~/Applications/Aero Blue Control Center.app`.
- Built helper: `swiftui-app/.build/release/AeroBridge`, installed into app `Contents/MacOS/AeroBridge`.
- Python CLI: `scripts/aero.py`; standard library only, JSON on stdout, errors on stderr and nonzero status. Invocation is argument arrays, never constructed shell code.

Settings schema version 1: `enabled` boolean, `preset` (`pure-aero`, `aqua-minimal`, `crystal-ocean`, `sky-blue-elegance`), `wallpaper` (`aero-sky-light`, `aero-sky-dark`, `crystal-ocean-light`, `crystal-ocean-dark`, `aero-meadow-light`, `aero-meadow-dark`), `animations` boolean, `menuBar` boolean, `clock24h` boolean, `weather` object with `city`, `latitude`, `longitude`, `units` (`celsius`/`fahrenheit`), `dock` object with `tilesize` integer, `magnification` boolean, `autohide` boolean, `widgets` mapping each of `clock`, `weather`, `system`, `music`, `calendar`, `productivity` to `{enabled: bool, x: number, y: number, width: number}`. Tasks and focus state are persisted separately in `productivity.json`.

## Python CLI interface

`check`, `settings get`, `settings set <JSON-object>`, `backup`, `apply --yes [--preset NAME]`, `restore --yes [--backup ID]`, `install --yes`, `uninstall --yes`, `status`, `system`, `weather`, `music get|playpause|next`, `calendar`, `productivity get|add TEXT|toggle ID|remove ID|focus MINUTES|stop`, `widget-data`, `icons apply TARGET ICON_PNG --yes`, `icons restore TARGET --yes`, `widgets install --yes`. Apply backs up before any changes; settings changes alone don't mutate Dock or wallpaper. No mutation without explicit flags; GUI must confirm external changes before supplying --yes. Shell scripts wrap these commands.

## Swift bridge interface

`AeroBridge wallpaper get` => JSON list `[{screen: integer, url: string}]`; `wallpaper set PATH` for all screens; `wallpaper restore JSON` restores exact screen mapping where available.

`AeroBridge icon backup TARGET BACKUP_DIRECTORY` => capture custom icon metadata only; `icon set TARGET PNG BACKUP_DIRECTORY`; `icon restore TARGET BACKUP_DIRECTORY`. Refuse application bundles, system locations and symlinks for icon mutation; use user folders/files or Finder aliases. The mandatory backup directory also records the applied fingerprint to protect newer external icon changes.

`AeroBridge calendar` => `{authorized: bool, events: [{title,start,end,allDay}]}` (never prompts); `calendar request` => explicitly prompts permission then same result.

`AeroBridge system` => JSON CPU/memory/battery/storage actual measurements (nullable unavailable fields); `appearance` => `{reduceMotion: bool, reduceTransparency: bool}`.

## Assets and widgets

`assets/manifest.json`: `{wallpapers:[{id,title,variant,file,thumbnail,width,height}], icons:[{id,title,file,icns}], cursors:[{id,title,file,retina,hotspot:[x,y]}]}`. All paths relative to project root. Wallpapers PNG, icon preferred file 128 or 256px PNG, cursor file 64px PNG/retina128. Native cursor hotspots use logical coordinates 32px (manifest also includes source pixel hotspots if needed; document precisely).

Übersicht entry `widgets/aero-blue/index.jsx` renders six independently positioned widgets from `widget-data`. Installation writes a local config file naming absolute interpreter/CLI paths and links/copies the widget directory under the user's Übersicht widgets; preserve preexisting files. Entry uses JSON actual measurements, supports offline/permission states, and sends actions safely through `run` with shell quoting. UI config is in Control Center. Native menu bar uses MenuBarExtra; optional SketchyBar configuration is opt-in.

## Ownership

Assets agent: `assets/`, `scripts/generate_assets.py`, asset docs.
Backend agent: `scripts/` except asset generator, `config/`, backend tests.
SwiftUI agent: `swiftui-app/Package.swift`, `swiftui-app/Sources/AeroBlue/`, app Info.plist, app build helper if coordinated with backend.
Bridge agent: `swiftui-app/Sources/AeroBridge/`, bridge docs.
Widgets agent: `widgets/`, `menu-bar/`, widget docs.
Root: integration, README, overall docs/tests; all agents coordinate deviations through messages.
