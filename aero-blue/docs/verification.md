# Verification report

Recorded 30 October 2026. Development host: Linux x86_64, Python 3.12.14, Node 24.19.0. No connected Mac, macOS SDK, Swift compiler, Übersicht or SketchyBar runtime was available. The user's Mac model, OS build, displays and installed customizations remain unknown until the local checker runs.

## Executed checks

| Check | Actual result |
| --- | --- |
| `python3 -m unittest discover -s tests -v` | **22 tests passed**, none skipped or expected-failure. |
| `node widgets/aero-blue/helpers.test.mjs` | **7 tests passed**, none skipped or cancelled. Direct invocation reports the individual Node tests in this environment. |
| Shell syntax | `bash -n` passed for all 11 shell/config scripts, including the optional SketchyBar config. |
| Python/JSON/plist parsing | Passed for all Python source, JSON configuration and the app's privacy/identity metadata. |
| Asset regeneration | Completed using the included generator and existing Pillow installation: six 3200×2000 wallpapers, 17 icon designs, ten cursor designs and the app icon. |
| Artwork validation | All 155 PNG/JPEG exports passed image decoding/integrity checks. Wallpaper and cursor dimensions, preview files, PNG checksums, icon counts, ICNS container lengths/chunks and hotspot bounds passed. Contact sheets were visually inspected. |
| Read-only system detection | Correctly reports Linux and unavailable macOS capabilities without changing user state. |
| Native build script | Invoked and stopped with its explicit macOS/Xcode requirement. **No native application was compiled here.** |
| Repository checks | Whitespace/diff validation passed; all changes are local project implementation files and assets. |

The Python suite exercises persistent settings and tasks across separate CLI processes, deep-merge validation, invalid updates leaving saved settings intact, explicit installer authorization, native-operation refusal on Linux, missing weather configuration, offline weather cache isolation, safe album-art encoding, permission guards, unmanaged-path protection, staged install rollback and scoped Dock restore. Mocked macOS failures verify that rollback is attempted, absent preference keys remain absent, unrelated keys are not changed, icon conflicts retain the installation, and disconnected displays retain the active restore snapshot.

The JavaScript suite exercises literal argument quoting with hostile-looking task text, runtime-path validation, missing/malformed device readings, weather-code mapping, a persistent timer, leap-year month layout and panel positioning. These are behavior tests, not desktop screenshots or macOS integration tests.

## Pending on an actual Mac

| Area | Remaining validation |
| --- | --- |
| Native build and launch | Compile both SwiftPM products with Xcode 15+; build the `.app`; verify its bundled icon, helper, local signing and normal launch. Swift source received static review only. |
| Permission attribution | Confirm Calendar permission works for the bundled helper and is available to the desired widget invocation context. Test Music Automation grant, denial and revocation. The helper refuses Calendar prompts without app privacy metadata. |
| Wallpaper and Dock | Apply and restore on the user's OS. Verify connected/disconnected displays, Retina scaling, Spaces and the original wallpaper's behavior. Public wallpaper APIs do not restore every dynamic-wallpaper scheduling option. |
| File icons | Use disposable files/folders, including a pre-existing custom icon. Check FinderInfo/resource-fork restoration and conflict refusal. Check Finder aliases separately; the file picker preserves alias paths. |
| Widgets | Load JSX in Übersicht, enable interaction deliberately, verify all six panels, local artwork, offline states, city lookup, events and persistent tasks. JSX rendering was not executable on the Linux host. |
| Weather service | Perform real geocoding/forecast requests on the Mac. Cloud tests use controlled responses and cache fixtures; they do not establish live Open-Meteo availability. |
| Menu bar | Verify native menu extra and optional SketchyBar layout on the actual display, notch, Dock position and Spaces. |
| Cursor | Test in-app preview hotspots at each scale. A compatible manager's manual import and global replacement remain unverified. No ready-to-apply system cape or global replacement is claimed. |
| Accessibility and power | Check VoiceOver, keyboard use, light/dark modes, reduced motion/transparency, actual CPU/GPU/battery overhead and multiple screen sizes. |
| Restart and login | Check settings/tasks across app/widget restarts, and manually configured Login Items. No login service is registered automatically. |
| Full restore/uninstall | Perform a complete apply → restore → apply → uninstall cycle on a disposable setup. Confirm personal files and retained backups/archives remain intact. |

Follow [the Mac acceptance checklist](mac-verification.md), recording actual outcomes. The GitHub Actions workflow includes portable tests and a macOS compilation job. This report records local validation before the separately authorized GitHub branch upload; **no GitHub Actions or native-build result is established by this report**. Check the branch's actual workflow results separately. Uploading the source branch does not publish or update the cloud environment.

## Installation boundary

The complete source and generated artwork are available in this checkout and the downloadable archive. Transferring them to the Mac and running the checker is the next step. `scripts/install.sh` displays its plan and requests explicit authorization before user-level installation. Applying the desktop theme is a separate confirmed action. Third-party applications, privacy permissions and manual Accessibility pointer changes stay under the user's control.
