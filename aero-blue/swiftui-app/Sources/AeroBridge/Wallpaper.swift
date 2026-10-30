import AppKit
import Foundation

private func displayID(_ screen: NSScreen) throws -> UInt32 {
    guard let value = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        throw BridgeError("Cannot identify a connected display")
    }
    return value.uint32Value
}

private func wallpaperOptions(_ screen: NSScreen) -> [String: Any] {
    let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
    var result: [String: Any] = [:]
    if let scaling = options[.imageScaling] as? NSNumber { result["scaling"] = scaling }
    if let clipping = options[.allowClipping] as? NSNumber { result["clipping"] = clipping }
    if let color = (options[.fillColor] as? NSColor)?.usingColorSpace(.deviceRGB) {
        result["fillColor"] = [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent]
    }
    return result
}

private func nativeOptions(_ data: [String: Any]) -> [NSWorkspace.DesktopImageOptionKey: Any] {
    var result: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
    if let number = data["scaling"] as? NSNumber { result[.imageScaling] = number }
    if let number = data["clipping"] as? NSNumber { result[.allowClipping] = number }
    if let color = data["fillColor"] as? [Double], color.count == 4,
       color.allSatisfy({ $0.isFinite && (0...1).contains($0) }) {
        result[.fillColor] = NSColor(deviceRed: CGFloat(color[0]), green: CGFloat(color[1]), blue: CGFloat(color[2]), alpha: CGFloat(color[3]))
    }
    return result
}

private func currentWallpapers() throws -> [[String: Any]] {
    guard !NSScreen.screens.isEmpty else { throw BridgeError("A logged-in macOS graphical session is required") }
    return try NSScreen.screens.map { screen in
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            throw BridgeError("macOS did not expose the current wallpaper; refusing to make an unrestorable change")
        }
        return ["screen": try displayID(screen), "url": url.absoluteString, "options": wallpaperOptions(screen)]
    }
}

func wallpaperCommand(_ args: [String]) throws -> Any {
    guard let action = args.first else { throw BridgeError("Expected wallpaper get|set|restore") }
    switch action {
    case "get":
        try requireCount(args, 1, "wallpaper get")
        return try currentWallpapers()
    case "set":
        try requireCount(args, 2, "wallpaper set PATH")
        let imageURL = URL(fileURLWithPath: args[1]).standardizedFileURL
        guard FileManager.default.isReadableFile(atPath: imageURL.path),
              let image = NSImage(contentsOf: imageURL), image.isValid else {
            throw BridgeError("Wallpaper must be a readable image file")
        }
        let previous = try currentWallpapers()
        do {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true
                ])
            }
        } catch {
            // Restore displays already changed if another display failed.
            let rollback = try JSONSerialization.data(withJSONObject: previous)
            let rollbackText = String(decoding: rollback, as: UTF8.self)
            do { _ = try wallpaperCommand(["restore", rollbackText]) }
            catch { throw BridgeError("Wallpaper change failed and rollback also failed: \(error.localizedDescription). Use the saved backup.") }
            throw error
        }
        return ["ok": true, "screens": NSScreen.screens.count]
    case "restore":
        try requireCount(args, 2, "wallpaper restore JSON")
        guard let records = try JSONSerialization.jsonObject(with: Data(args[1].utf8)) as? [[String: Any]] else {
            throw BridgeError("Wallpaper backup must be a JSON array")
        }
        // Validate the whole backup before changing the first screen.
        var work: [(NSScreen, URL, [NSWorkspace.DesktopImageOptionKey: Any])] = []
        var missing: [UInt32] = []
        for record in records {
            guard let id = record["screen"] as? NSNumber,
                  let value = record["url"] as? String,
                  let url = URL(string: value), url.isFileURL,
                  FileManager.default.isReadableFile(atPath: url.path) else {
                throw BridgeError("Wallpaper backup references an invalid or missing local file")
            }
            guard let screen = try NSScreen.screens.first(where: { try displayID($0) == id.uint32Value }) else {
                missing.append(id.uint32Value)
                continue
            }
            work.append((screen, url, nativeOptions(record["options"] as? [String: Any] ?? [:])))
        }
        for (screen, url, options) in work {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options)
        }
        return ["ok": true, "restoredScreens": work.count, "disconnectedScreens": missing]
    default: throw BridgeError("Unknown wallpaper operation")
    }
}
