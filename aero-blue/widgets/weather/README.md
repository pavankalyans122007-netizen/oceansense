# Weather

Current conditions and three-day forecast from Open-Meteo. Select a city or coordinates in Control Center; stale cached readings are marked when offline.

The implementation is the `Weather` component in [the installable Übersicht bundle](../aero-blue/index.jsx). Install the whole bundle once so it shares a single data poll. Configure `widgets.weather.enabled`, `x`, `y` and `width` in Control Center. See [widget installation and permissions](../../docs/widgets.md).
