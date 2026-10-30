import AppKit
import SwiftUI

@main
struct AeroBlueApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("Aero Blue Control Center", id: "main") {
            ControlCenterView(model: model)
                .frame(minWidth: 930, minHeight: 660)
                .task {
                    guard model.manifest.wallpapers.isEmpty else { return }
                    model.perform("Loading your local configuration…") { try await model.load() }
                }
        }
        .defaultSize(width: 1080, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Check this Mac") { model.inspectSystem() }
                Button("Open project folder") { if let url = model.projectURL { NSWorkspace.shared.open(url) } }
            }
        }
        MenuBarExtra("Aero Blue", systemImage: "drop.fill", isInserted: $model.settings.menuBar) {
            AeroMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct AeroMenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill").foregroundStyle(AeroPalette.ocean)
                Text("Aero Blue").font(.headline)
                Spacer()
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(context.date, style: .time).monospacedDigit()
                }
            }
            Label(model.activeApplication, systemImage: "macwindow").lineLimit(1)
            if let battery = model.system["batteryPercent"] as? Double {
                Label("Battery \(Int(battery.rounded()))%", systemImage: "battery.100")
            }
            if let cpu = model.system["cpuPercent"] as? Double {
                Label("CPU \(Int(cpu.rounded()))%", systemImage: "gauge.medium")
            }
            Divider()
            Button("Open Control Center") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "Aero Blue Control Center" }) {
                    window.makeKeyAndOrderFront(nil)
                } else { openWindow(id: "main") }
            }
            Button("Quit Aero Blue") { NSApp.terminate(nil) }
        }
        .padding(18)
        .frame(width: 270)
        .task {
            while !Task.isCancelled {
                await model.refreshSystem()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }
}
