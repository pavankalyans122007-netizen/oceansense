# Glass widgets and menu bar

The six widgets use Übersicht's documented JSX / React interface. The complete installable bundle is `widgets/aero-blue/`; one command collects real readings every 15 seconds. The clock and focus countdown tick locally without starting a new process every second. Weather requests use the backend cache, so polling does not send a request to Open-Meteo every 15 seconds.

## Installation on your Mac

1. Run the system checker and build/install Aero Blue as described in the main README.
2. Review the official [Übersicht download](https://tracesof.net/uebersicht/) and install it yourself if desired. No script downloads or installs Übersicht automatically. The upstream site advertises macOS 12 or later; Aero Blue targets macOS 13 or later. Runtime compatibility still requires validation on your Mac.
3. Open Übersicht once, then use **Install Übersicht widgets** in Control Center, or run `python3 scripts/aero.py widgets install --yes` from the project directory. The installer configures absolute interpreter and CLI paths in the installed `runtime.json`. Do not manually copy the placeholder `runtime.json` as a configured widget.
4. Enable the theme and choose individual widgets in Control Center. Set each widget's X, Y and width in logical screen points. Start with only the clock, then add panels where there is room. Move widgets through these settings; dragging is not implemented.
5. In Übersicht preferences, choose its interaction shortcut and use that shortcut to click controls or type into tasks. Übersicht may request Accessibility access for interaction; grant it yourself in System Settings only if you want interactive widgets. Rendering does not imply that this permission has been granted.

Übersicht's own preferences control which display hosts a widget and whether Übersicht starts at login. Aero Blue does not add login items. Enable Übersicht at login yourself if desired. Tasks, timer end times and layout are stored in Aero Blue's user state directory, so app or widget restarts do not lose them.

## Features

| Widget | Real source and behavior |
| --- | --- |
| Glass Clock | Local device time and date, 12/24-hour preference. |
| Weather | Open-Meteo current weather and up to three daily forecasts. Choose a city and coordinates in Control Center. Cached readings are labeled when offline. No sample temperature is substituted. |
| System Monitor | Native host statistics, memory measurements, battery and startup-volume capacity. Missing battery data on a desktop is shown as unavailable. |
| Music | Apple Music via macOS Automation, only after enabling access explicitly in Control Center. Play/pause and next call the actual Music app; errors are shown. Actual artwork appears when the backend can provide it. A musical-note tile means artwork is unavailable. |
| Calendar | Local month grid always works. Upcoming EventKit events appear only after explicit Calendar permission; nothing is populated with example appointments. |
| Productivity | Editable local checklist, deletion and completion, daily greeting and a persistent 25-minute focus timer. Completion is visual; there is no notification or sound permission requirement. |

Panels use system fonts, readable blue text, translucent backgrounds and soft highlights. System Reduce Motion disables appearance animation; Reduce Transparency uses opaque panels. CSS also supports increased contrast and dark appearance. The panel controls expose text labels and keyboard focus styling. Actual VoiceOver, Retina scaling, multiple displays and power usage need macOS validation.

## Optional SketchyBar

The native Control Center menu extra is the default: no extra menu-bar replacement is required. `menu-bar/` contains a separate opt-in SketchyBar configuration for users who already run that tool. It displays an original ring mark, frontmost app updates, numbered Mission Control spaces, actual Wi-Fi power status, battery and clock. Wi-Fi power means the radio is on; it does not claim an internet connection or expose an SSID.

Review [SketchyBar's official repository](https://github.com/FelixKratz/SketchyBar) and installation instructions before installing it yourself. To preview the planned operation, run:

```bash
./menu-bar/start-sketchybar.sh
```

To start the optional session after review:

```bash
./menu-bar/start-sketchybar.sh --yes
```

The launcher refuses to start while another SketchyBar process is running. It uses the bundled config without overwriting `~/.config/sketchybar`, installing a service, hiding the native menu bar, or changing system settings. The optional strip sits at the bottom so macOS menu controls remain available. Depending on your Dock position and display, adjust its `y_offset` in the bundled config. Edit the four numbered spaces to match your Mission Control layout. Stop the session with Control-C. No supported public API exposes every workspace arrangement through the native Control Center menu extra.

## Validation

Run portable helper tests with `node widgets/aero-blue/helpers.test.mjs`. They verify safe shell argument quoting, invalid-data handling, missing device readings, leap-year calendar layout, persistent focus timing and position clamping. Shell syntax checks cover the optional menu scripts. These checks do **not** verify JSX rendering, Übersicht interaction permissions, desktop placement, SketchyBar rendering, Music Automation, Calendar permission, login persistence or CPU/GPU overhead on macOS; those remain in the Mac acceptance checklist.
