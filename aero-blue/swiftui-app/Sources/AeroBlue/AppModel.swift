import AppKit
import Combine
import Foundation

struct PendingChange: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let button: String
    let action: @MainActor () async throws -> Void
}

@MainActor
final class AppModel: ObservableObject {
    @Published var settings = ThemeSettings()
    @Published var manifest = AssetManifest.empty
    @Published var busy = false
    @Published var message = "Loading your local configuration…"
    @Published var errorMessage: String?
    @Published var confirmation: PendingChange?
    @Published var selectedSection: ControlSection? = .overview
    @Published var selectedCursor = "pointer"
    @Published var system: [String: Any] = [:]
    @Published var weatherCities: [WeatherCity] = []
    @Published var compatibility = "Run a compatibility check to inspect this Mac."
    @Published var activeApplication = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Finder"
    @Published var projectURL: URL?
    private var pythonURL: URL?
    private var activation: AnyCancellable?

    init() {
        projectURL = Self.findProject()
        activation = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.activeApplication = app.localizedName ?? "Application"
                }
            }
    }

    static func findProject() -> URL? {
        var candidates: [URL] = []
        if let explicit = ProcessInfo.processInfo.environment["AERO_BLUE_PROJECT"] {
            candidates.append(URL(fileURLWithPath: explicit))
        }
        candidates.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Aero Blue/project"))
        if let resource = Bundle.main.resourceURL { candidates.append(resource.appendingPathComponent("project")) }
        var cursor = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<6 {
            candidates.append(cursor)
            candidates.append(cursor.appendingPathComponent("aero-blue"))
            cursor.deleteLastPathComponent()
        }
        if let executable = Bundle.main.executableURL {
            cursor = executable.deletingLastPathComponent()
            for _ in 0..<6 { candidates.append(cursor); cursor.deleteLastPathComponent() }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("scripts/aero.py").path) }
    }

    func asset(_ relative: String) -> URL? {
        guard let projectURL else { return nil }
        let value = projectURL.appendingPathComponent(relative).standardizedFileURL
        guard value.path.hasPrefix(projectURL.standardizedFileURL.path + "/") else { return nil }
        return value
    }

    private func interpreter() async throws -> URL {
        if let pythonURL { return pythonURL }
        if let data = try? await CommandRunner.run(URL(fileURLWithPath: "/usr/bin/xcrun"), ["--find", "python3"]),
           let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           FileManager.default.isExecutableFile(atPath: path) {
            let url = URL(fileURLWithPath: path)
            pythonURL = url
            return url
        }
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/opt/homebrew/bin:/usr/local/bin").split(separator: ":")
        for path in paths {
            let url = URL(fileURLWithPath: String(path)).appendingPathComponent("python3")
            if FileManager.default.isExecutableFile(atPath: url.path) { pythonURL = url; return url }
        }
        throw CommandFailure(message: "Python 3 is required. Install Apple's Command Line Tools, then reopen Aero Blue. No software is installed automatically.")
    }

    @discardableResult
    func command(_ arguments: [String]) async throws -> Data {
        guard let projectURL else {
            throw CommandFailure(message: "Project resources were not found. Run scripts/install.sh from the Aero Blue checkout, or set AERO_BLUE_PROJECT for development.")
        }
        let python = try await interpreter()
        return try await CommandRunner.run(python, [projectURL.appendingPathComponent("scripts/aero.py").path] + arguments, directory: projectURL)
    }

    func bridge(_ arguments: [String]) async throws -> Data {
        var candidates: [URL] = []
        if let executable = Bundle.main.executableURL {
            candidates.append(executable.deletingLastPathComponent().appendingPathComponent("AeroBridge"))
        }
        if let projectURL {
            candidates.append(projectURL.appendingPathComponent("swiftui-app/.build/release/AeroBridge"))
            candidates.append(projectURL.appendingPathComponent("swiftui-app/.build/debug/AeroBridge"))
        }
        guard let executable = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw CommandFailure(message: "The native helper is missing. Rebuild the app with scripts/build-app.sh on your Mac.")
        }
        return try await CommandRunner.run(executable, arguments, directory: projectURL)
    }

    func perform(_ title: String, action: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        busy = true
        message = title
        errorMessage = nil
        Task {
            do { try await action() }
            catch { errorMessage = error.localizedDescription; message = "Action needs attention" }
            busy = false
        }
    }

    func load() async throws {
        let data = try await command(["settings", "get"])
        settings = try JSONDecoder().decode(ThemeSettings.self, from: data)
        if let url = asset("assets/manifest.json") {
            manifest = try JSONDecoder().decode(AssetManifest.self, from: Data(contentsOf: url))
        }
        message = settings.enabled ? "Your Aero Blue theme is enabled." : "Your settings are ready. Choose a look to begin."
    }

    func save() async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(settings), as: UTF8.self)
        _ = try await command(["settings", "set", json])
        message = "Settings saved. Apply the theme to update wallpaper and Dock."
    }

    func saveSettings() { perform("Saving settings…") { try await self.save() } }

    func confirmApply(preset: ThemePreset? = nil) {
        let chosen = preset?.title ?? "your selected look"
        confirmation = PendingChange(
            title: "Apply \(chosen)?",
            message: "Aero Blue will back up the settings it changes, set your desktop wallpaper on connected displays and update the native Dock preferences. The Dock may restart. Your applications and personal files are preserved.",
            button: "Back up & Apply",
            action: {
                try await self.save()
                var arguments = ["apply", "--yes"]
                if let preset { arguments += ["--preset", preset.rawValue] }
                _ = try await self.command(arguments)
                try await self.load()
                self.message = "Theme applied. Your previous settings are backed up locally."
            }
        )
    }

    func confirmRestore() {
        confirmation = PendingChange(
            title: "Restore your previous desktop?",
            message: "Restore wallpaper and the Dock settings saved before Aero Blue was enabled. Aero Blue will be disabled. Personal files and saved checklist tasks are kept. Icon metadata can also be restored individually from the Icons page.",
            button: "Restore previous settings",
            action: {
                _ = try await self.command(["restore", "--yes"])
                try await self.load()
                self.message = "Previous desktop settings restored."
            }
        )
    }

    func inspectSystem() {
        perform("Inspecting this Mac…") {
            let data = try await self.command(["check"])
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let pretty = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
                self.compatibility = String(decoding: pretty, as: UTF8.self)
            }
            self.message = "Compatibility report updated from this Mac."
        }
    }

    func refreshSystem() async {
        do {
            let data = try await command(["system"])
            system = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch {
            system = [:]
        }
    }

    func chooseTarget(for icon: IconAsset? = nil, restore: Bool = false) {
        let panel = NSOpenPanel()
        panel.title = restore ? "Restore a previous custom icon" : "Choose a file or folder"
        panel.message = "Use your own files or folders. Application bundles and protected system locations are excluded."
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.resolvesAliases = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            Task { @MainActor in
                guard response == .OK, let target = panel.url else { return }
                if restore {
                    self.confirmation = PendingChange(title: "Restore this icon?", message: target.path, button: "Restore icon", action: {
                        _ = try await self.command(["icons", "restore", target.path, "--yes"])
                        self.message = "Original icon metadata restored."
                    })
                } else if let icon, let path = self.asset(icon.file) {
                    self.confirmation = PendingChange(title: "Apply \(icon.title) icon?", message: "Back up the existing icon metadata and apply the crystal icon to:\n\(target.path)", button: "Back up & Apply", action: {
                        _ = try await self.command(["icons", "apply", target.path, path.path, "--yes"])
                        self.message = "Crystal icon applied. Original metadata was backed up."
                    })
                }
            }
        }
    }

    func installWidgets() {
        confirmation = PendingChange(title: "Install the desktop widgets?", message: "This adds Aero Blue's six widgets to your existing Übersicht widgets folder. Übersicht must already be installed. Existing unrelated widgets are preserved; no third-party software is installed.", button: "Install widgets", action: {
            try await self.save()
            _ = try await self.command(["widgets", "install", "--yes"])
            self.message = "Widgets installed. Open Übersicht to display them."
        })
    }

    func connectCalendar() {
        confirmation = PendingChange(title: "Connect Calendar?", message: "macOS will ask whether Aero Blue may read your calendars to display upcoming events. Aero Blue never changes calendar events.", button: "Request Calendar access", action: {
            let data = try await self.bridge(["calendar", "request"])
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            self.settings.permissions.calendar = object?["authorized"] as? Bool ?? false
            try await self.save()
            self.message = self.settings.permissions.calendar ? "Calendar connected." : "Calendar access was not granted. The widget still shows today's date."
        })
    }

    func connectMusic() {
        confirmation = PendingChange(title: "Connect Apple Music?", message: "Aero Blue will ask macOS for permission to read and control the Music app. Music must be open. You can revoke Automation access in System Settings.", button: "Connect Music", action: {
            self.settings.permissions.music = true
            try await self.save()
            let data = try await self.command(["music", "get"])
            let result = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if result?["authorized"] as? Bool != true {
                self.settings.permissions.music = false
                try await self.save()
                throw CommandFailure(message: result?["error"] as? String ?? "Music access was not granted. Review Automation permissions in System Settings.")
            }
            if result?["available"] as? Bool != true {
                self.message = result?["error"] as? String ?? "Music is not currently available."
            } else { self.message = "Music connected. The widget can display the current track." }
        })
    }

    func searchWeather(_ city: String) {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        perform("Finding cities…") {
            let data = try await self.command(["weather", "search", city])
            struct SearchResult: Decodable { let results: [WeatherCity] }
            self.weatherCities = try JSONDecoder().decode(SearchResult.self, from: data).results
            self.message = self.weatherCities.isEmpty ? "No cities found. Try a nearby city or enter coordinates." : "Choose a city, then save your settings."
        }
    }

    func reveal(_ relative: String) {
        if let url = asset(relative) { NSWorkspace.shared.open(url) }
    }

    func openURL(_ string: String) {
        if let url = URL(string: string) { NSWorkspace.shared.open(url) }
    }
}
