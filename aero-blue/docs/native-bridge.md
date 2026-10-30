# Native macOS helper

`AeroBridge` is a Swift 5.9 executable using AppKit, EventKit, Darwin Mach host statistics, IOKit power-source APIs, and CryptoKit. It targets macOS 13 and later. It runs as the logged-in user without elevation. No protected resources, signed application bundles, or cursor resources are changed.

The executable prints one JSON value on stdout. Failures print a diagnostic on stderr and return a nonzero exit status. Run it from the installed `Aero Blue Control Center.app/Contents/MacOS/AeroBridge`, or use the Python backend. A live graphical login is required for wallpaper operations.

## Commands

| Command | Result and behavior |
| --- | --- |
| `wallpaper get` | Array of `{screen, url, options}` using Core Graphics display identifiers, current image URLs, scaling, clipping, and fill color. Fails when macOS cannot expose a restorable current image. |
| `wallpaper set PATH` | Sets a readable image on all connected screens. Captures the prior state first and attempts rollback if one screen fails. |
| `wallpaper restore JSON` | Restores backed-up display IDs and their image options. Returns `disconnectedScreens` for displays currently absent. Validates referenced local files before changing a display. |
| `icon backup TARGET DIRECTORY` | Creates `DIRECTORY/icon-metadata.json`, refusing to overwrite an existing backup. |
| `icon set TARGET PNG DIRECTORY` | Requires the prior backup directory, applies a valid PNG with `NSWorkspace.setIcon`, records the applied metadata fingerprint, and rolls back if bookkeeping fails. |
| `icon restore TARGET DIRECTORY` | Restores the original custom-icon metadata; refuses replacement files or newer external icon changes. Repeated restore is harmless. |
| `calendar` | Reads the next seven calendar days only if access was already granted. It never prompts. |
| `calendar request` | Explicitly requests EventKit access, with a 120-second timeout. Requires the built app's privacy descriptions; the unbundled executable refuses to prompt. |
| `system` | Actual CPU, memory, internal battery, and home-volume storage measurements. Unavailable measurements are JSON `null`. |
| `appearance` | `{reduceMotion, reduceTransparency}` from macOS accessibility settings. |

### Icon protections and restoration

Only ordinary files and folders owned by the current user inside their home directory are supported. Symlinks, hidden paths, `~/Library`, and `.app`, `.bundle`, or `.framework` path components are refused. System application icon replacements require an alternative such as a user-created launcher; this helper never edits application bundles.

The backup records target identity (canonical path, device and inode), the presence and bytes of `com.apple.FinderInfo` and `com.apple.ResourceFork`, and any existing folder `Icon\r` file's data, extended attributes, mode, flags, and timestamps. Relevant icon metadata is restored without deleting other target attributes. The existing icon file is restored in place where possible; a theme-created icon file is removed only after its applied fingerprint matches. Personal file contents are untouched. If the user later changes the icon or replaces the target, restoration stops with a conflict instead of overwriting that change. Backups are retained.

The implementation does not promise bit-for-bit restoration of unrelated file-system bookkeeping such as inode change times, Finder caches, or ACLs on an icon file recreated by macOS. Finder may need a refresh to show restored metadata. Exact resource-fork and FinderInfo restoration needs on-device verification before using it on valuable customized folders.

### Measurement definitions

`system` returns `available`, `sampledAt`, `cpuPercent`, `memoryUsedBytes`, `memoryTotalBytes`, `memoryPercent`, `batteryPercent`, `batteryCharging`, `diskUsedBytes`, `diskTotalBytes`, and `diskPercent`. Percentages use a 0–100 scale. CPU measures the change in real host CPU ticks over 200 milliseconds. Memory is active + wired + compressed pages; it excludes reclaimable inactive pages and can differ from Activity Monitor's classifications. Disk usage uses capacity available for important usage, which includes purgeable capacity. Desktop Macs without an internal battery return `null` battery values.

`calendar` returns `{authorized, status, events}`. Each event has `id`, `title`, `start`, `end`, `allDay`, and `calendar`. Dates use ISO 8601. Results include ongoing and upcoming events through seven days from today's midnight, capped at 50. Denied, restricted, write-only, or unrequested permissions produce empty events with an explicit status. Events stay local; weather requests do not receive calendar data.

## Verification still required on a Mac

The implementation was created in a Linux workspace without Swift, AppKit, EventKit, or IOKit. Native compilation and live OS behavior have **not** been tested here. Before claiming native readiness:

1. Build with Xcode 15 or newer Command Line Tools. Confirm both SwiftPM products compile and run the packaged app.
2. Run read-only `system`, `appearance`, and `wallpaper get`; compare results with macOS settings and Activity Monitor.
3. On a disposable folder, back up, apply, and restore an icon. Include a folder with a pre-existing custom icon and verify original resource-fork/FinderInfo presence and bytes. Apply a different icon outside Aero Blue and verify restoration refuses to overwrite it.
4. Back up wallpaper state, apply a theme, then restore. Test Retina scaling and multiple displays. macOS Spaces and dynamic-wallpaper scheduling are not exposed fully by these APIs; this helper controls the desktops macOS reports for connected screens.
5. Test Calendar's unrequested, granted, denied, and revoked states using the packaged app. Confirm permission attribution and privacy descriptions on the specific macOS release. A standalone SwiftPM binary deliberately cannot trigger the prompt.
6. Confirm memory, battery, and CPU readings on both Apple Silicon and Intel hardware. No sample measurements or fabricated events are used as fallbacks.
