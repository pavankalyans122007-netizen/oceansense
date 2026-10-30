# Calendar

The local month grid always works. Upcoming EventKit events require an explicit Calendar connection and permission; events are never fabricated.

The implementation is the `Calendar` component in [the installable Übersicht bundle](../aero-blue/index.jsx). Install the whole bundle once so it shares a single data poll. Configure `widgets.calendar.enabled`, `x`, `y` and `width` in Control Center. See [widget installation and permissions](../../docs/widgets.md).
