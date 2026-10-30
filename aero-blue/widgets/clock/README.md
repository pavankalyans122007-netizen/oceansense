# Glass Clock

Local device time, date and weekday; configure `clock24h` in Control Center. The clock ticks in the widget without spawning a process every second.

The implementation is the `Clock` component in [the installable Übersicht bundle](../aero-blue/index.jsx). Install the whole bundle once so it shares a single data poll. Configure `widgets.clock.enabled`, `x`, `y` and `width` in Control Center. See [widget installation and permissions](../../docs/widgets.md).
