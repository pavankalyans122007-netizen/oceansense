# Verification on the target Mac

This is a test procedure, **not a record of passing macOS tests**. Linux checks validate portable code and generated assets; they cannot verify AppKit, SwiftUI, EventKit, Music Automation, Übersicht, Dock changes, display scaling, or actual power overhead. Record the Mac model, OS/build, architecture, display arrangement, tool versions, and every observed result when running this procedure.

## 1. Inspect before changing settings

From the `aero-blue` directory, run:

```bash
scripts/check-system.sh
sw_vers
uname -m
system_profiler SPHardwareDataType SPDisplaysDataType
xcode-select -p
xcrun swift --version
python3 --version
```

Confirm the native app's minimum macOS/toolchain requirements. Read the report for existing customization software and screen scaling. Save a personal record of your wallpaper per display/Space, Dock size/magnification/autohide, custom icons, native pointer colors, and any active menu-bar/widget software. Reports can contain identifying hardware details; keep the complete report local unless intentionally sharing it.

The Mac build is required. A clean Linux asset or unit-test run cannot substitute for it:

```bash
scripts/build-app.sh
```

Record the command's exit status and launch the resulting app. Verify that both executable targets were built, the app opens without a missing interpreter/helper/resource error, and the macOS usage-description strings are present before exercising permissions. A locally compiled app is not a notarized release.

## 2. Installation and the reversible baseline

Review the installer's planned operations before confirming them. Close unrelated customization utilities only if you choose to; do not let AERO BLUE replace their configuration. Use the installer documented in the main README, then note its backup identifier and destination.

Verify that application code/assets are under your Application Support project folder, that the app is under `~/Applications`, and that saved settings survive quitting and reopening the app. Run installation again and confirm that existing personal settings, tasks, and backups remain intact. No automatic Homebrew install, administrator prompt, Login Item, or background-service registration should occur.

Before applying a theme, ensure a backup was completed. Check that the backup records whether each modified Dock key originally existed, the original values, and wallpaper URLs/display identifiers. If your wallpaper is dynamic or varies by Space, check restoration behavior explicitly: an API's current-display image result may not capture every dynamic/Space choice.

## 3. Theme, displays, and accessibility

Apply a preset only after reviewing the confirmation. Verify the selected wallpaper and Dock preferences on the running Mac, then test each wallpaper and each preset. Check the 16:10 internal panel, a 16:9 external display if available, Retina scaling, an alternate scaling setting, and display hot-plugging. Note any cropping and confirm subjects remain well placed. Test multiple Spaces and Stage Manager when enabled.

In System Settings, enable **Reduce Motion**, then **Reduce Transparency**, and check the control center and widgets. Switch light/dark appearance and the project's global animation option. Confirm text contrast, keyboard focus, VoiceOver labels, target sizes, and absence of motion when the system setting forbids it. Do not infer power efficiency solely from attractive animations.

## 4. Icon rendering and exact restoration

Use a disposable folder in your home directory first. Capture its original custom-icon status and extended attributes with the project backup workflow. Apply one icon and inspect Finder at small, large, and Retina sizes. Restore it and confirm the original custom icon (or absence) returns. Repeat with a folder that already has a custom icon and with a supported ordinary file.

Verify that files inside the folder, unrelated extended attributes, labels, and Finder metadata remain intact. Try a signed `.app` bundle, a system directory, and a symlink: they must be refused before mutation. The artwork gallery does not imply those protected application's actual Dock/Finder icons were replaced.

## 5. Cursor validation

First test the built-in Accessibility pointer color/outline fallback. Record the settings before changing them and restore through the same OS panel afterwards.

If you independently establish that a cursor manager supports your OS/architecture, import the provided cursor artwork according to the asset guide. Do not enable a login helper before a successful interactive test. For **every cursor role**, test at normal and enlarged sizes and at 1×/2× screen scaling: pointer click tip, text caret insertion point, link-hand fingertip, loading center, horizontal/vertical/diagonal resize endpoints, move/crosshair center, and unavailable symbol. Test transitions between apps, menus, secure prompts, and attached displays. Some apps supply their own cursor images.

Record which roles were actually replaced, which reverted, and which manager/version was used. Reapply after a log-out only if you have deliberately enabled the manager's supported persistence option. Revert to the manager's default cape and uninstall its helper through its own UI if desired. AERO BLUE's normal restore cannot restore private helper state it never installed.

## 6. Widgets and data permissions

Install Übersicht separately only after checking compatibility and approving its installation. Configure its interaction shortcut and review its requested Accessibility access. Install the AERO BLUE widgets through the project workflow. Exercise each widget independently, then all six together; confirm enable/disable, position, width, configuration persistence, and no off-screen overlap at your scaled resolution.

| Widget | Required functional observation |
| --- | --- |
| Clock | Actual local time and weekday, correct 12/24-hour switch and time-zone change. |
| Weather | Explicit selected city/coordinates, plausible provider response and timestamp, unit change, forecast when returned, labeled offline/cache/unavailable state with networking disabled. No invented fallback temperature. |
| System | CPU responds to a temporary workload, memory changes when apps open, battery reflects charge/power source, disk values match the selected volume. Unknown values remain unavailable. |
| Music | With Music open, actual title/artist and artwork where supplied; play/pause and next work after the correct Automation prompt. Denial and a stopped player produce a useful state. |
| Calendar | Date/month view without permission; only an explicit permission action requests access; approved event data matches Calendar; denial remains usable. |
| Productivity | Add/toggle/remove a task; quit/reopen and verify persistence; start/stop a short focus timer and test system sleep/wake. |

Try a task containing quotes, apostrophes, Unicode, `$()`, backticks, and line breaks. The text must remain data and must not execute a command. Leave the clock/timer running across a widget refresh and verify there are no duplicated timers. Record JSX rendering or permission errors from Übersicht's debug console.

## 7. Menu bar, Dock, and resource use

Start with the native menu item. Confirm app activation, battery/clock values, and essential native controls remain reachable. Test a notched MacBook at the default scaled resolution and an external display. If opting into SketchyBar, review its supplied configuration first, keep a backup of your existing configuration, and start it manually. Check current app, workspace, Wi-Fi, battery, clock, and null/permission states; verify that the native menu remains accessible and no duplicate service was installed.

Confirm Dock size, autohide, and magnification after theme application, relaunch, and restoration. App ordering/grouping is not changed unless an explicitly supported workflow says so. Native Dock graphics remain native.

Use Activity Monitor and, if available, `top` to measure the control center, widget host, backend subprocesses, and optional bar for at least five minutes at idle and under normal use. Record average/peak CPU and memory, polling frequency, wakeups, and thermal/battery behavior. Test the same scene with animations disabled and enabled. A short idle sample cannot certify battery life; report measured conditions rather than an unsupported performance claim.

## 8. Restore, interruption, and uninstall

Restore using the specific baseline backup. Confirm wallpaper and all managed Dock keys match their original state, including deletion of keys that were originally absent. Confirm icon restore separately for every changed target. Add an unrelated user file/setting before restoration and verify it remains. Repeat restoration to test idempotence.

Test an unavailable wallpaper file or disconnected display without deleting the baseline backup. A failed operation should report what remains and preserve recoverable state. Do not deliberately kill processes during writes on your primary profile; interruption testing belongs in a disposable macOS user account or VM.

Uninstall only after reviewing its report. Confirm project-owned app/widget files are removed or retained exactly as documented, personal tasks and backups are preserved, and unrelated applications/configuration remain. Remove optional third-party software separately using its own supported method. The project never disables SIP or Gatekeeper, and none of these tests require doing so.

## 9. Login persistence and final evidence

The default installation does not register launch services or Login Items. Verify that theme preferences and task files persist after logout/login, while the control center/widgets run only when manually launched or when you have personally enabled their normal login options. If you choose login startup, enable the app in the OS Login Items UI and use Übersicht's own preferences; document those opt-in changes and how to reverse them.

Fill in a verification record rather than deleting failed or unrun checks:

| Area | Result: passed / failed / skipped / unrun | Mac/OS/tool version | Evidence or limitation |
| --- | --- | --- | --- |
| Native build and launch | unrun | — | Requires target Mac. |
| Settings/restart and installer repeatability | unrun | — | Requires target Mac. |
| Wallpaper/multiple displays/Spaces | unrun | — | Requires target Mac. |
| Icons and metadata restoration | unrun | — | Requires target Mac. |
| Cursor fallback | unrun | — | Requires target Mac. |
| System-wide cursor manager | unrun | — | Compatibility not established. |
| All six desktop widgets | unrun | — | Requires compatible Übersicht. |
| Calendar/Music permission paths | unrun | — | Requires target Mac. |
| Native menu and optional SketchyBar | unrun | — | Requires target Mac. |
| Dock/backup/restore/uninstall | unrun | — | Requires target Mac. |
| Accessibility/light-dark/Retina | unrun | — | Requires target Mac. |
| CPU/memory/battery overhead | unrun | — | No device measurements from Linux. |
| Logout/login behavior | unrun | — | User-controlled startup only. |
