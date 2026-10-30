import AppKit
import Foundation

struct BridgeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func emit(_ value: Any) throws {
    let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    FileHandle.standardOutput.write(bytes)
    FileHandle.standardOutput.write(Data([10]))
}

func requireCount(_ args: [String], _ count: Int, _ usage: String) throws {
    guard args.count == count else { throw BridgeError("Usage: AeroBridge \(usage)") }
}

func isoDate(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

do {
    // NSWorkspace/NSScreen need an AppKit session. Never create a Dock tile.
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    let args = Array(CommandLine.arguments.dropFirst())
    guard let command = args.first else {
        throw BridgeError("Expected wallpaper, icon, calendar, system, or appearance")
    }
    switch command {
    case "wallpaper": try emit(wallpaperCommand(Array(args.dropFirst())))
    case "icon": try emit(iconCommand(Array(args.dropFirst())))
    case "calendar": try emit(calendarCommand(Array(args.dropFirst())))
    case "system":
        try requireCount(args, 1, "system")
        try emit(systemSnapshot())
    case "appearance":
        try requireCount(args, 1, "appearance")
        try emit([
            "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        ])
    default: throw BridgeError("Unknown command: \(command)")
    }
} catch {
    FileHandle.standardError.write(Data(("AeroBridge: \(error.localizedDescription)\n").utf8))
    exit(1)
}
