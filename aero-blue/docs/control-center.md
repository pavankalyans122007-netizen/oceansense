# Aero Blue Control Center

The native application targets macOS 13+, using SwiftUI, AppKit and the system font. It is source code, not a prebuilt or notarized download. A macOS SDK was not available in the Linux development workspace; a successful native build or runtime test is **not claimed**. Follow the macOS verification checklist before relying on system integration.

## Build and launch

From the project root on a supported Mac with Swift 5.9 / Xcode 15 Command Line Tools and Python 3:

```sh
./scripts/check-system.sh
./scripts/build-app.sh
```

The build helper creates `swiftui-app/build/Aero Blue Control Center.app`. Open that bundle to test it. To install the complete project under your account, use `scripts/install.sh` and review its plan before using its explicit confirmation flag. No third-party software, login item, developer tools or privileged helper are installed automatically.

For source development, the app locates an installed project or its bundled `Contents/Resources/project` copy. `AERO_BLUE_PROJECT=/absolute/path/to/aero-blue` overrides that discovery for a deliberate development run. Do not point it at an untrusted project: it executes that project's local backend. The normal application bundle contains both `AeroBlue` and `AeroBridge` executables. Build-signing and Gatekeeper behavior must be checked on the real Mac; this project does not disable either protection.

## Workflows

- **Overview:** four presets and explicit enable/disable confirmations. Applying backs up and changes only supported wallpaper/Dock settings. Disabling restores the recorded original settings.
- **Wallpapers:** six actual artwork previews, light/dark variants, source resolutions, explicit application to connected displays.
- **Crystal Icons:** gallery and file/folder picker. Existing metadata is backed up first. Real application bundles, symlinks and protected locations are refused by the helper. For a system app, create a Finder alias manually and apply an icon to that alias; do not select the original bundle. Individual restore is available.
- **Crystal Cursor:** local 32-point `NSCursor` hover preview from original artwork and logical hotspots. This preview affects only the test panel. System-wide replacement requires a separately evaluated manager. The Accessibility fallback is manual and uses macOS's own pointer colors and size controls.
- **Desktop Widgets:** Übersicht installation, independent enable/position/width controls, 12/24-hour time, city search and explicit coordinate selection. Weather searches send the city query to Open-Meteo; forecasts send selected coordinates. Empty/offline state is presented rather than invented data. Calendar and Music connections are separate opt-in actions.
- **Dock & Menu Bar:** native Dock size/magnification/autohide, an optional compact native status menu, and a link to optional SketchyBar configuration. The menu samples real system readings while visible and leaves normal macOS controls available.
- **Preferences:** effective accessibility states, global animation preference, local hardware report, manual Login Items guidance and restoration.

Use **Save settings** after editing controls. Saving writes local Aero Blue configuration; **Apply theme** separately backs up and applies wallpaper/Dock changes after confirmation. Widget configuration and the menu preference persist across app restarts. No login launch is automatically configured.

## Privacy and failure behavior

Calendar access is requested only after clicking Connect Calendar and confirming. The application bundle declares the macOS 13/14 Calendar usage descriptions. Permission denial leaves the date/month widget usable. Music requires the Music app and macOS Automation permission; connection errors are surfaced without reporting success. Disconnecting stops Aero Blue queries, while OS permission revocation remains in System Settings.

The UI runs the Python backend using an executable URL and argument array, never by interpolating commands into a shell. Subprocess work and pipe reads run away from the main thread; diagnostics return to the status panel. Latitude/longitude may be cleared together, widget positions use whole desktop points, and the backend validates all saved settings.

The interface follows macOS appearance and semantic text colors. Reduce Motion suppresses UI transitions, and Reduce Transparency replaces glass panels with solid backgrounds. The original PNG cursor representations are scaled to 32 logical points with the manifest's corresponding point hotspot; the 64px/128px exports must not be interpreted as 64pt/128pt.

## Still to verify on macOS

Compile both Swift targets; launch the packaged app; exercise every panel; test permission allow/deny paths; test apply/restore and icon metadata against disposable files; check Dark Mode, Reduce Motion, Reduce Transparency, keyboard/VoiceOver navigation, Retina displays, multiple monitors, menu sampling and CPU overhead. Confirm configuration survives a restart and manual Login Items behavior works if the user enables it. See `docs/mac-verification.md` for the complete checklist.
