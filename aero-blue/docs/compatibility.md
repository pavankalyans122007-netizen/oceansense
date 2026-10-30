# Compatibility and source evidence

Research recorded **30 October 2026**. This project was developed in a Linux x86_64 cloud workspace. The Mac model, macOS build, display scaling, installed customization tools, and permission state of the user's Mac are **unknown**. Source inspection is not a successful installation or a runtime compatibility test.

Run `scripts/check-system.sh` on the Mac before installation. The native app targets **macOS 13 or later**, with **Swift 5.9 / Xcode 15 or newer Command Line Tools** for building. The build runs for the host architecture; it is not a prebuilt, notarized universal distribution. Python 3 is also required for the local backend. No third-party app, developer tool, login item, privileged helper, or Homebrew package is installed automatically.

## Feature decisions

| Feature | Implementation | Evidence and limits |
| --- | --- | --- |
| Wallpapers | Original PNG artwork, previews, native `NSWorkspace` desktop-image APIs | macOS integration must be tested on every attached display and Space. Static images do not replace a live wallpaper engine. |
| Native control center | SwiftUI, AppKit materials, local settings, optional `MenuBarExtra` | Target macOS 13+. No macOS SDK was available in the development container, so a successful native build is not claimed. |
| Icons | PNG/ICNS gallery; user-file/folder customization with metadata backups | Signed app bundles and protected system locations are refused. Finder/Safari/etc. artwork remains useful in the gallery, personal folders, and manually created launchers; the app does not replace their system bundle icons. |
| Native Dock | Existing Dock plus per-user size, magnification, and autohide preferences | No binary patches, replacement Dock, or promise of true Aero-glass reflections. Dock preference keys are conventional macOS preferences, not a stable public theming API; verify them on the actual OS. |
| Cursor artwork | Original transparent assets, logical hotspots, manual import guide | Artwork generation and hotspot validation do not establish system-wide cursor replacement. |
| Cursor default fallback | macOS Accessibility pointer fill/outline color and size | Uses the user's System Settings UI; no private preference writes or protected cursor modifications. |
| Desktop widgets | Übersicht JSX, a local Python data backend, per-widget positions/settings | Upstream advertises macOS 12+. Actual app architecture, rendering, interaction, and OS compatibility require a Mac test. Übersicht is optional and installed separately by the user. |
| Calendar events | EventKit after an explicit permission action | Calendar permission differs by OS version. Denial must leave a working date/month view and a permission explanation. |
| Music | Apple Music AppleScript metadata and controls | Requires the relevant macOS Automation approval. Other music apps and arbitrary browser players are not assumed to work. Artwork may be unavailable for some tracks. |
| Menu bar | Optional native status menu; opt-in SketchyBar configuration | The native menu bar remains available. SketchyBar is a separately installed dependency and must be tested for display/notch/Space behavior. |
| Weather | Open-Meteo forecast/geocoding requests, cached/offline states | Requires Internet access and an explicitly selected location. No API key is required for the public noncommercial service; its usage terms apply. |
| Login persistence | Local settings/tasks persist; app startup is user controlled | No Login Item, LaunchAgent, daemon, or background helper is automatically registered. |

## Cursor manager research

[Mousecape's official repository](https://github.com/alexzielenski/Mousecape) describes a cursor manager for “Mac OS 10.8+” built using **private CoreGraphics APIs**. That broad historical claim does not establish compatibility with the user's current Mac. The `releases/latest` URL resolved during this research to [release 1813](https://github.com/alexzielenski/Mousecape/releases/tag/1813), whose page records **13 June 2020**. No current OS/architecture test was available here. AERO BLUE therefore neither installs Mousecape's helper nor applies a cape automatically.

The [upstream README](https://github.com/alexzielenski/Mousecape/blob/master/README.md) documents creating a cape with Command-N, editing with Command-E, adding cursor types, and dragging image representations into their fields. The [upstream sample cape](https://github.com/alexzielenski/Mousecape/blob/master/Mousecape/com.maxrudberg.svanslosbluehazard.cape) was read as a property list to confirm its representation/hotspot fields. Its third-party artwork was **not** copied. An understood file format still does not prove current system-wide behavior; follow the asset import guide and test before enabling any persistence helper.

[Mac Mouse Fix](https://github.com/noah-nuebling/mac-mouse-fix) was also reviewed as an actively developed mouse utility: its public release endpoint resolved to [3.1.0](https://github.com/noah-nuebling/mac-mouse-fix/releases/tag/3.1.0), and its [README](https://github.com/noah-nuebling/mac-mouse-fix/blob/master/Readme.md) documents modern mouse gestures, scrolling, buttons, and Apple Silicon support. Those features do not establish a system cursor-theme replacement capability. AERO BLUE does not install it or present it as a replacement for Mousecape. No maintained alternative with verified arbitrary global cursor-theme support on the user's unknown OS was established in this research.

The supported fallback is **System Settings → Accessibility → Display → Pointer**. Select a comfortable size, an aqua or sky-blue fill, and a dark ocean-blue outline. Use the settings panel's Reset control to restore its defaults. Setting labels can vary by macOS version. Apple's [Display accessibility guide](https://support.apple.com/guide/mac-help/change-display-settings-for-accessibility-mchlp1225/mac) is the reference for the actual OS; that page could not be fetched through the cloud network policy during this session. This fallback changes color/size, not the full pointer silhouette or every cursor role.

## Safe alternatives for application icons

For Finder, Safari, Mail, and other signed system apps, keep the application bundle intact. A practical manual alternative is a personal launcher folder containing Finder aliases: create `~/Aero Blue Launchers`, then hold **Option-Command** while dragging an application into that folder in Finder to create an alias. Confirm Finder identifies it as an alias before continuing. Open the corresponding original PNG in Preview, copy the image, open **Get Info on the alias**, select the small icon at the top of that Info window, and paste. Keep a copy of a preexisting alias before changing its icon. Open the alias to confirm it still launches the intended app.

This changes the personal alias representation, not the signed application. An alias may resolve to the original application icon when placed in the Dock, and its running-app Dock icon can remain the original; do not promise a replacement Dock icon. Keep the custom aliases in an ordinary folder or Dock folder stack if that fits your workflow. Delete only newly created aliases when reversing this manual customization, and preserve the target apps. The project's automated icon workflow refuses `.app` bundles.

## Übersicht evidence

The [official widget API README](https://github.com/felixhageloh/uebersicht/blob/master/README.md) documents `.jsx` widgets, React rendering, `command`, `refreshFrequency`, state updates, and the `run` API used by this project. It also states that clicks require an **interaction shortcut and Accessibility access**. Configure these in Übersicht after personally reviewing its permission request. Calendar and Music permissions are separate.

The [official update feed](https://raw.githubusercontent.com/felixhageloh/uebersicht/gh-pages/updates.xml.rss) advertises version **1.6.82**, minimum system version **12.0**, with a release note about fixing widget sizing on macOS Sonoma. The [website source](https://github.com/felixhageloh/uebersicht/blob/gh-pages/index.html) likewise advertises macOS 12+. These are upstream claims, not runtime results for later macOS releases. The old Node 8 developer-build instructions in the README are not required to use AERO BLUE's widgets and have not been adopted as project prerequisites.

Obtain Übersicht from its [official website](https://tracesof.net/uebersicht/) or official repository only if its release supports your Mac. The installer only integrates the widgets after an existing Übersicht installation is detected. If Übersicht does not run on the Mac, the native control center, wallpapers, icons, and Dock workflow remain usable, while desktop widgets remain unavailable.

## SketchyBar evidence

The [official repository](https://github.com/FelixKratz/SketchyBar) documents configurable bar items, scripts, events, aliases, and graph/pop-up support. Its `releases/latest` endpoint resolved to [v2.24.1](https://github.com/FelixKratz/SketchyBar/releases/tag/v2.24.1), dated **9 October 2026**. This establishes a recent upstream release, not successful use on the target Mac.

The [upstream installation guide](https://felixkratz.github.io/SketchyBar/setup) was blocked by the cloud network policy, so its current prerequisite list was not verified. Read that guide locally before opting in. The project does not install SketchyBar, replace an existing `sketchybarrc`, hide essential system controls, or enable a service at login. Use the native menu item unless you deliberately want the optional separate bar.

## Network destinations and permissions

The control center and local artwork do not need Internet access. Weather uses `api.open-meteo.com` and city lookup uses `geocoding-api.open-meteo.com`; enter coordinates manually if lookup is unavailable. When using a managed cloud environment, these hosts require its normal network settings workflow. No cloud allowlist was changed by this project, and no credentials are embedded in the repository.

Permission prompts must originate from the explicit feature selected by the user: Calendar access for events, Automation for controlling Music, and Übersicht's documented Accessibility access for widget interaction. No SIP, Gatekeeper, quarantine, or system-volume changes are required. If macOS refuses a third-party binary or the locally built app, use the normal OS security flow and official vendor guidance; the installer does not bypass security controls.

## Evidence boundaries

The source URLs above were fetched successfully on the research date except the explicitly noted Apple Support and SketchyBar documentation pages. Upstream README text can be stale, and a release date does not certify all supported architectures or OS versions. Use [the Mac verification checklist](mac-verification.md) to record actual results before describing the desktop transformation as fully applied or system-wide cursor theming as working.
