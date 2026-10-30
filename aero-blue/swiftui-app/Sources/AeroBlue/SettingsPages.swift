import SwiftUI

struct WidgetsPage: View {
    @ObservedObject var model: AppModel
    @State private var cityQuery = ""

    var body: some View {
        SectionHeading(title: "Little windows into your day.", detail: "Six independently positioned glass widgets. They require Übersicht, a separate optional desktop app.")
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                FeatureLine(symbol: "rectangle.3.group", title: "Start with Übersicht", detail: "Install a compatible version yourself, then add Aero Blue's widget collection. Saved positions use desktop points. Enable the theme to show your chosen panels.")
                HStack {
                    Button("Install widget collection…") { model.installWidgets() }.buttonStyle(.borderedProminent)
                    Button("Übersicht website") { model.openURL("https://tracesof.net/uebersicht/") }
                    Button("Layout guide") { model.reveal("docs/widgets.md") }
                }
            }
        }
        ForEach(WidgetKind.allCases) { kind in
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: widgetBinding(kind, \.enabled, fallback: false)) {
                        Label(kind.title, systemImage: kind.symbol).font(.headline)
                    }.toggleStyle(.switch)
                    HStack(spacing: 18) {
                        numberField("Left", value: widgetBinding(kind, \.x, fallback: 32))
                        numberField("Top", value: widgetBinding(kind, \.y, fallback: 32))
                        numberField("Width", value: widgetBinding(kind, \.width, fallback: 280))
                    }
                    Text(widgetDescription(kind)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Clock & weather").font(.headline)
                Toggle("Use a 24-hour clock", isOn: $model.settings.clock24h)
                Divider()
                HStack {
                    TextField("Find a city", text: $cityQuery).textFieldStyle(.roundedBorder)
                        .onSubmit { model.searchWeather(cityQuery) }
                    Button("Search") { model.searchWeather(cityQuery) }
                }
                ForEach(model.weatherCities) { city in
                    Button {
                        model.settings.weather.city = city.city
                        model.settings.weather.latitude = city.latitude
                        model.settings.weather.longitude = city.longitude
                        model.weatherCities = []
                        model.message = "Location selected. Save settings to update the weather widget."
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(city.label)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
                TextField("City label", text: $model.settings.weather.city).textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Latitude", value: $model.settings.weather.latitude, format: .number).textFieldStyle(.roundedBorder)
                    TextField("Longitude", value: $model.settings.weather.longitude, format: .number).textFieldStyle(.roundedBorder)
                    Picker("Units", selection: $model.settings.weather.units) {
                        Text("°C").tag("celsius")
                        Text("°F").tag("fahrenheit")
                    }.frame(width: 130)
                }
                Text("Weather uses Open-Meteo's public noncommercial API. Your chosen coordinates are sent when the widget refreshes. No location permission or API key is required; cached readings are marked stale when offline.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear weather location") {
                    model.settings.weather.city = ""
                    model.settings.weather.latitude = nil
                    model.settings.weather.longitude = nil
                }
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your connections").font(.headline)
                HStack {
                    Label("Calendar", systemImage: "calendar")
                    Spacer()
                    if model.settings.permissions.calendar {
                        Button("Disconnect") {
                            model.settings.permissions.calendar = false
                            model.saveSettings()
                        }
                    } else { Button("Connect Calendar…") { model.connectCalendar() } }
                }
                HStack {
                    Label("Apple Music", systemImage: "music.note")
                    Spacer()
                    if model.settings.permissions.music {
                        Button("Disconnect") {
                            model.settings.permissions.music = false
                            model.saveSettings()
                        }
                    } else { Button("Connect Music…") { model.connectMusic() } }
                }
                Text("Connections are optional. macOS controls Calendar and Automation access. Disconnect stops Aero Blue queries; revoke the OS permission in System Settings if desired. Music artwork is shown only when the current track supplies it.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Privacy settings") { model.openURL("x-apple.systempreferences:com.apple.preference.security?Privacy") }
            }
        }
        Button("Save widget settings") { model.saveSettings() }.buttonStyle(.borderedProminent)
    }

    private func widgetBinding<Value>(_ kind: WidgetKind, _ key: WritableKeyPath<WidgetSettings, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { model.settings.widgets[kind.rawValue]?[keyPath: key] ?? fallback }, set: { value in
            var widget = model.settings.widgets[kind.rawValue] ?? WidgetSettings()
            widget[keyPath: key] = value
            model.settings.widgets[kind.rawValue] = widget
        })
    }

    private func numberField(_ label: String, value: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: value, format: .number).textFieldStyle(.roundedBorder)
                .frame(minWidth: 65, maxWidth: 95).accessibilityLabel("Widget \(label)")
        }
    }

    private func widgetDescription(_ kind: WidgetKind) -> String {
        switch kind {
        case .clock: return "Live time, weekday and date; select 12 or 24 hours below."
        case .weather: return "Current conditions and a three-day forecast for your chosen location."
        case .system: return "Measured CPU, memory, storage and battery; unavailable sensors stay empty."
        case .music: return "Current Apple Music track, supplied artwork, play/pause and next controls. Connect Music below."
        case .calendar: return "A minimal month view and optional upcoming events. Connect Calendar below."
        case .productivity: return "An editable local checklist and a persistent focus timer. No account required."
        }
    }
}

struct DockPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SectionHeading(title: "Familiar controls. A lighter feel.", detail: "Keep the native Dock and essential menu bar controls, with a compact layout that matches your desktop.")
        GlassPanel {
            VStack(alignment: .leading, spacing: 20) {
                Label("Native Dock", systemImage: "dock.rectangle").font(.headline)
                HStack {
                    Text("Icon size")
                    Spacer()
                    Stepper("\(model.settings.dock.tilesize) pt", value: $model.settings.dock.tilesize, in: 16...128, step: 4).frame(width: 140)
                }
                Toggle("Magnify icons on hover", isOn: $model.settings.dock.magnification)
                Toggle("Automatically hide and show the Dock", isOn: $model.settings.dock.autohide)
                Text("Apply the theme to update these preferences. The Dock restarts once so changes take effect. Add and reorder your own apps in the Dock normally; Aero Blue preserves your pinned applications.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Back up & apply Dock preferences…") { model.confirmApply() }.buttonStyle(.borderedProminent)
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label("Aero Blue menu", systemImage: "menubar.rectangle").font(.headline)
                Toggle("Show the compact Aero Blue status menu", isOn: $model.settings.menuBar)
                Text("A small drop opens a glass panel with time, the frontmost app and measured CPU/battery status. Readings refresh every 15 seconds while the panel is open. Save to remember your choice after restart.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("The normal macOS menu bar stays available for Wi-Fi, Control Center and Spaces. No duplicate full-width bar is enabled.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                FeatureLine(symbol: "square.stack.3d.up", title: "Optional SketchyBar configuration", detail: "A separate, opt-in configuration is included for users who already run a compatible SketchyBar. Read its setup notes and check your display and notch layout first.")
                Button("Open menu bar configuration") { model.reveal("menu-bar") }
            }
        }
        Button("Save settings") { model.saveSettings() }.buttonStyle(.borderedProminent)
    }
}

struct PreferencesPage: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        SectionHeading(title: "Comfort comes first.", detail: "Small adjustments, clear permissions and a way back to your own desktop.")
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Motion & accessibility").font(.headline)
                Toggle("Enable subtle transitions", isOn: $model.settings.animations)
                LabeledContent("macOS Reduce Motion", value: reduceMotion ? "Enabled — animations suppressed" : "Disabled")
                LabeledContent("macOS Reduce Transparency", value: reduceTransparency ? "Enabled — solid panels" : "Disabled")
                Text("System accessibility preferences take priority. The app uses system fonts and semantic text colors, and follows light or dark appearance automatically.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Save preferences") { model.saveSettings() }.buttonStyle(.borderedProminent)
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Start when you want to").font(.headline)
                Text("Settings and checklist tasks persist locally. No Login Item or background helper is added automatically. To launch at sign-in, add Aero Blue Control Center and optionally Übersicht in macOS Login Items yourself.")
                    .foregroundStyle(.secondary)
                Button("Open Login Items") { model.openURL("x-apple.systempreferences:com.apple.LoginItems-Settings.extension") }
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("This Mac").font(.headline)
                    Spacer()
                    Button("Run compatibility check") { model.inspectSystem() }
                }
                Text(model.compatibility).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                Button("Read compatibility notes") { model.reveal("docs/compatibility.md") }
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                Label("Restore your previous settings", systemImage: "arrow.uturn.backward").font(.headline)
                Text("Restore the preferences captured before the theme changed them. Your personal files and local checklist are preserved. Use the Icons page to restore an individual file or folder icon.")
                    .foregroundStyle(.secondary)
                Button("Restore previous desktop…") { model.confirmRestore() }
                Button("Open installation & restore guide") { model.reveal("README.md") }
            }
        }
    }
}
