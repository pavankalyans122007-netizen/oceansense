# System Monitor

CPU, memory, battery and storage come from AeroBridge measurements. Missing sensors are displayed as unavailable; readings refresh every 15 seconds.

The implementation is the `System` component in [the installable Übersicht bundle](../aero-blue/index.jsx). Install the whole bundle once so it shares a single data poll. Configure `widgets.system.enabled`, `x`, `y` and `width` in Control Center. See [widget installation and permissions](../../docs/widgets.md).
