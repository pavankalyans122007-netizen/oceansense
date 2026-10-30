import AppKit
import SwiftUI

struct ControlCenterView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 27))
                        .foregroundStyle(LinearGradient(colors: [AeroPalette.aqua, AeroPalette.ocean], startPoint: .topLeading, endPoint: .bottomTrailing))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AERO BLUE").font(.system(size: 15, weight: .bold, design: .rounded)).tracking(1.7)
                        Text("A clearer kind of desktop").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(20)
                List(ControlSection.allCases, selection: $model.selectedSection) { section in
                    Label(section.rawValue, systemImage: section.symbol).tag(section)
                        .padding(.vertical, 6)
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 6) {
                    Label(model.settings.enabled ? "Theme enabled" : "Theme is off", systemImage: model.settings.enabled ? "checkmark.circle.fill" : "circle")
                        .font(.callout).foregroundStyle(model.settings.enabled ? AeroPalette.ocean : Color.secondary)
                    Text("Built for your Mac. Saved locally.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            .navigationSplitViewColumnWidth(min: 215, ideal: 230, max: 260)
        } detail: {
            ZStack {
                LinearGradient(colors: scheme == .dark ? [Color(hex: 0x142C42), Color(hex: 0x12202F)] : [AeroPalette.ice, AeroPalette.sky.opacity(0.7), AeroPalette.glass], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            switch model.selectedSection ?? .overview {
                            case .overview: OverviewPage(model: model)
                            case .wallpapers: WallpapersPage(model: model)
                            case .icons: IconsPage(model: model)
                            case .cursors: CursorsPage(model: model)
                            case .widgets: WidgetsPage(model: model)
                            case .dock: DockPage(model: model)
                            case .preferences: PreferencesPage(model: model)
                            }
                        }.padding(28)
                    }
                    .disabled(model.busy)
                    .animation(model.settings.animations && !reduceMotion ? .easeInOut(duration: 0.18) : nil, value: model.selectedSection)
                    statusBar
                }
            }
        }
        .tint(AeroPalette.ocean)
        .toolbar {
            ToolbarItemGroup {
                Button { model.saveSettings() } label: { Label("Save settings", systemImage: "square.and.arrow.down") }
                    .disabled(model.busy)
                Button { model.confirmApply() } label: { Label("Apply theme", systemImage: "sparkles") }
                    .disabled(model.busy)
            }
        }
        .alert(item: $model.confirmation) { request in
            Alert(title: Text(request.title), message: Text(request.message), primaryButton: .default(Text(request.button)) {
                model.perform("\(request.button)…", action: request.action)
            }, secondaryButton: .cancel())
        }
    }

    private var statusBar: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.busy { ProgressView().controlSize(.small) }
            else { Image(systemName: model.errorMessage == nil ? "info.circle" : "exclamationmark.triangle").foregroundStyle(model.errorMessage == nil ? Color.secondary : Color.orange) }
            Text(model.errorMessage ?? model.message).font(.caption).lineLimit(4).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
    }
}

struct OverviewPage: View {
    @ObservedObject var model: AppModel
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        SectionHeading(title: "Make room for a little blue.", detail: "Crystal light, quiet glass and the familiar comfort of Aqua. Your desktop, thoughtfully refreshed.")
        GlassPanel {
            HStack(spacing: 25) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [.white.opacity(0.8), AeroPalette.crystal, AeroPalette.ocean], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().strokeBorder(.white.opacity(0.75), lineWidth: 2)
                    Image(systemName: "drop.fill").font(.system(size: 48)).foregroundStyle(.white.opacity(0.9)).shadow(color: AeroPalette.ocean.opacity(0.3), radius: 8, y: 5)
                }.frame(width: 110, height: 110).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Aero desktop").font(.title2.weight(.semibold))
                    Text("Original wallpapers, crystal icons and matching cursors. Every system change starts with a backup.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(model.settings.enabled ? "Apply selected look" : "Enable theme") { model.confirmApply() }.buttonStyle(.borderedProminent)
                        Button("Disable & Restore") { model.confirmRestore() }.disabled(!model.settings.enabled)
                    }
                }
            }
        }
        Text("Choose your atmosphere").font(.title3.weight(.semibold))
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ThemePreset.allCases) { preset in
                GlassPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preset.title).font(.headline)
                            Spacer()
                            if model.settings.preset == preset.rawValue { Image(systemName: "checkmark.circle.fill").foregroundStyle(AeroPalette.ocean) }
                        }
                        Text(preset.detail).font(.callout).foregroundStyle(.secondary).frame(minHeight: 40, alignment: .topLeading)
                        Button("Apply preset") { model.confirmApply(preset: preset) }
                    }
                }
            }
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                FeatureLine(symbol: "lock.shield", title: "Native where it matters", detail: "The system Dock and menu bar retain their normal macOS controls. Signed application bundles stay intact.")
                FeatureLine(symbol: "rectangle.3.group", title: "Your widgets, your layout", detail: "Optional Übersicht widgets use real readings. Connect Calendar and Music only when you want them.")
                FeatureLine(symbol: "arrow.uturn.backward", title: "Return to your own settings", detail: "Restore your backed-up desktop, rather than replacing it with generic factory preferences.")
            }
        }
    }
}

struct WallpapersPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SectionHeading(title: "A view worth coming back to.", detail: "Three original scenes, each in light and dark. Choose a wallpaper, then apply the theme to update connected displays.")
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 18)], spacing: 18) {
            ForEach(model.manifest.wallpapers) { wallpaper in
                Button {
                    model.settings.wallpaper = wallpaper.id
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        AssetImage(url: model.asset(wallpaper.thumbnail), contentMode: .fill)
                            .frame(height: 164).clipped()
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(wallpaper.title).font(.headline)
                                Text("\(wallpaper.variant.capitalized) · \(wallpaper.width) × \(wallpaper.height)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: model.settings.wallpaper == wallpaper.id ? "checkmark.circle.fill" : "circle").foregroundStyle(AeroPalette.ocean)
                        }.padding(15)
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(model.settings.wallpaper == wallpaper.id ? AeroPalette.ocean : .white.opacity(0.6), lineWidth: model.settings.wallpaper == wallpaper.id ? 2 : 1))
                }.buttonStyle(.plain).accessibilityLabel("\(wallpaper.title), \(wallpaper.variant), \(model.settings.wallpaper == wallpaper.id ? "selected" : "not selected")")
            }
        }
        HStack {
            Button("Apply selected wallpaper & Dock") { model.confirmApply() }.buttonStyle(.borderedProminent)
            Button("Open wallpaper files") { model.reveal("assets/wallpapers") }
        }
        Text("Artwork is rendered at high resolution. The asset generator also accepts custom dimensions for your display; run the system check first to inspect its native resolution.")
            .font(.callout).foregroundStyle(.secondary)
    }
}

struct IconsPage: View {
    @ObservedObject var model: AppModel
    var body: some View {
        SectionHeading(title: "AERO BLUE CRYSTAL ICONS", detail: "Seventeen original symbols, with soft reflections and a shared sky-blue palette.")
        GlassPanel {
            FeatureLine(symbol: "folder.badge.gearshape", title: "Make your own files and folders feel at home", detail: "Apply a custom icon to a personal file, folder or Finder alias. For system apps, create a Finder alias and customize that alias. Aero Blue never changes signed application bundles.")
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 14)], spacing: 14) {
            ForEach(model.manifest.icons) { icon in
                GlassPanel {
                    VStack(spacing: 10) {
                        AssetImage(url: model.asset(icon.file)).frame(width: 74, height: 74)
                        Text(icon.title).font(.headline).lineLimit(1)
                        Button("Use on a file…") { model.chooseTarget(for: icon) }.controlSize(.small)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
        HStack {
            Button("Restore a previous icon…") { model.chooseTarget(restore: true) }
            Button("Open PNG & ICNS files") { model.reveal("assets/icons") }
        }
    }
}

struct CursorsPage: View {
    @ObservedObject var model: AppModel
    var selected: CursorAsset? { model.manifest.cursors.first(where: { $0.id == model.selectedCursor }) ?? model.manifest.cursors.first }
    var body: some View {
        SectionHeading(title: "AERO CRYSTAL CURSOR", detail: "Glossy aqua, a fine ocean-blue edge and precise hotspots. Test the artwork right here.")
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
            ForEach(model.manifest.cursors) { cursor in
                Button { model.selectedCursor = cursor.id } label: {
                    VStack(spacing: 8) {
                        AssetImage(url: model.asset(cursor.retina)).frame(width: 42, height: 42)
                        Text(cursor.title).font(.caption).lineLimit(2).multilineTextAlignment(.center).frame(height: 30)
                    }
                    .frame(maxWidth: .infinity).padding(12)
                    .background(model.selectedCursor == cursor.id ? AeroPalette.crystal.opacity(0.35) : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.65)))
                }.buttonStyle(.plain)
            }
        }
        if let selected {
            CursorTestArea(imageURL: model.asset(selected.retina), hotspot: selected.hotspot).frame(height: 140)
            Text("Preview uses a 32-point cursor with the exported logical hotspot. Only this preview area changes the cursor.").font(.caption).foregroundStyle(.secondary)
        }
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                FeatureLine(symbol: "cursorarrow.rays", title: "System-wide cursors need a compatible manager", detail: "Mousecape compatibility depends on your macOS version. Its system-wide behavior has not been tested in this project. Follow the compatibility notes and manual import guide before deciding whether to install it.")
                HStack {
                    Button("Open cursor guide") { model.reveal("docs/assets.md") }
                    Button("Open cursor artwork") { model.reveal("assets/cursors") }
                }
                Divider()
                FeatureLine(symbol: "accessibility", title: "A built-in fallback", detail: "In System Settings → Accessibility → Display → Pointer, choose a Crystal Blue fill (#65C7F7), a Deep Ocean outline (#2478B8) and your preferred size. Use Reset there to restore macOS's pointer colors.")
                Button("Open Accessibility settings") { model.openURL("x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display") }
            }
        }
    }
}
