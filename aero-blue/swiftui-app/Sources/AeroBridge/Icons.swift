import AppKit
import CryptoKit
import Darwin
import Foundation

private let iconMetadataNames = ["com.apple.FinderInfo", "com.apple.ResourceFork"]
private let fm = FileManager.default

private func fileInfo(_ path: String) throws -> stat {
    var info = stat()
    guard lstat(path, &info) == 0 else { throw BridgeError("Cannot inspect file: \(path): \(String(cString: strerror(errno)))") }
    return info
}

private func safeTarget(_ path: String) throws -> URL {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.resolvingSymlinksInPath()
    let resolved = url.resolvingSymlinksInPath()
    guard url.path == resolved.path else { throw BridgeError("Icon changes do not follow symbolic links") }
    guard url.path.hasPrefix(home.path + "/") else { throw BridgeError("Only files and folders inside your home directory can receive custom icons") }
    let relative = String(url.path.dropFirst(home.path.count + 1))
    let components = relative.split(separator: "/").map(String.init)
    guard components.first != "Library",
          !components.contains(where: { $0.hasPrefix(".") || ["app", "bundle", "framework"].contains(URL(fileURLWithPath: $0).pathExtension.lowercased()) }) else {
        throw BridgeError("Application bundles, Library files, and hidden configuration paths are protected; choose a regular user folder or file")
    }
    let info = try fileInfo(url.path)
    guard info.st_uid == getuid() else { throw BridgeError("The target must be owned by the current user") }
    let kind = info.st_mode & S_IFMT
    guard kind == S_IFREG || kind == S_IFDIR else { throw BridgeError("Only regular files and folders are supported") }
    guard (info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0 else {
        throw BridgeError("Locked or append-only files cannot receive custom icons")
    }
    return url
}

private func readAttribute(_ name: String, _ path: String) throws -> Data? {
    let length = getxattr(path, name, nil, 0, 0, XATTR_NOFOLLOW)
    if length < 0 {
        if errno == ENOATTR { return nil }
        throw BridgeError("Cannot read icon metadata \(name): \(String(cString: strerror(errno)))")
    }
    guard length <= 32 * 1024 * 1024 else { throw BridgeError("Icon metadata is too large for a safe backup") }
    if length == 0 { return Data() }
    var data = Data(count: length)
    let actual = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, length, 0, XATTR_NOFOLLOW) }
    guard actual == length else { throw BridgeError("Icon metadata changed while being read; retry the backup") }
    return data
}

private func allAttributeNames(_ path: String) throws -> [String] {
    let length = listxattr(path, nil, 0, XATTR_NOFOLLOW)
    guard length >= 0 else { throw BridgeError("Cannot enumerate existing icon metadata") }
    if length == 0 { return [] }
    var bytes = [CChar](repeating: 0, count: length)
    let result = listxattr(path, &bytes, length, XATTR_NOFOLLOW)
    guard result == length else { throw BridgeError("Icon metadata changed while being read") }
    return bytes.split(separator: 0).map { String(decoding: $0.map { UInt8(bitPattern: $0) }, as: UTF8.self) }
}

private func attributeSnapshot(_ path: String, names: [String]) throws -> [String: Any] {
    var result: [String: Any] = [:]
    for name in names {
        if let data = try readAttribute(name, path) { result[name] = data.base64EncodedString() }
        else { result[name] = NSNull() }
    }
    return result
}

private func setAttribute(_ name: String, data: Data?, path: String) throws {
    if let data {
        let result = data.withUnsafeBytes { setxattr(path, name, $0.baseAddress, data.count, 0, XATTR_NOFOLLOW) }
        guard result == 0 else { throw BridgeError("Cannot restore \(name): \(String(cString: strerror(errno)))") }
    } else {
        guard removexattr(path, name, XATTR_NOFOLLOW) == 0 || errno == ENOATTR else {
            throw BridgeError("Cannot remove theme-created icon metadata: \(String(cString: strerror(errno)))")
        }
    }
}

private func restoreAttributes(_ values: [String: Any], path: String, exact: Bool) throws {
    if exact {
        for name in try allAttributeNames(path) where values[name] == nil { try setAttribute(name, data: nil, path: path) }
    }
    for (name, value) in values {
        if value is NSNull { try setAttribute(name, data: nil, path: path) }
        else if let encoded = value as? String, let data = Data(base64Encoded: encoded) {
            try setAttribute(name, data: data, path: path)
        } else { throw BridgeError("Invalid icon backup metadata") }
    }
}

private func folderIconFile(_ target: URL) throws -> URL? {
    guard (try fileInfo(target.path)).st_mode & S_IFMT == S_IFDIR else { return nil }
    let icon = target.appendingPathComponent("Icon\r", isDirectory: false)
    var info = stat()
    if lstat(icon.path, &info) != 0 {
        guard errno == ENOENT else { throw BridgeError("Cannot inspect the existing folder icon") }
        return nil
    }
    guard info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else {
        throw BridgeError("The existing Icon carriage-return file is not a regular user-owned file")
    }
    guard info.st_size <= 32 * 1024 * 1024,
          (info.st_flags & UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)) == 0 else {
        throw BridgeError("The existing icon file is locked or too large for safe replacement")
    }
    return icon
}

private func iconSnapshot(_ target: URL) throws -> [String: Any] {
    let info = try fileInfo(target.path)
    var result: [String: Any] = [
        "target": target.path, "device": info.st_dev, "inode": info.st_ino,
        "attributes": try attributeSnapshot(target.path, names: iconMetadataNames),
        "folderIcon": NSNull()
    ]
    if let icon = try folderIconFile(target) {
        let subInfo = try fileInfo(icon.path)
        let attributes = try fm.attributesOfItem(atPath: icon.path)
        result["folderIcon"] = [
            "data": try Data(contentsOf: icon).base64EncodedString(),
            "attributes": try attributeSnapshot(icon.path, names: allAttributeNames(icon.path)),
            "permissions": subInfo.st_mode & 0o7777, "flags": subInfo.st_flags,
            "created": (attributes[.creationDate] as? Date).map { $0.timeIntervalSince1970 as Any } ?? NSNull(),
            "modified": Double(subInfo.st_mtimespec.tv_sec) + Double(subInfo.st_mtimespec.tv_nsec) / 1_000_000_000,
            "accessed": Double(subInfo.st_atimespec.tv_sec) + Double(subInfo.st_atimespec.tv_nsec) / 1_000_000_000
        ]
    }
    return result
}

private func fingerprint(_ snapshot: [String: Any]) throws -> String {
    var state = snapshot
    // Reading or writing a resource fork can update timestamps, which are not an icon conflict.
    if var icon = state["folderIcon"] as? [String: Any] {
        icon.removeValue(forKey: "accessed")
        icon.removeValue(forKey: "modified")
        icon.removeValue(forKey: "created")
        state["folderIcon"] = icon
    }
    let data = try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func backupURL(_ path: String) throws -> URL {
    let directory = URL(fileURLWithPath: path).standardizedFileURL
    let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.resolvingSymlinksInPath()
    guard directory.path.hasPrefix(home.path + "/"), directory.resolvingSymlinksInPath().path == directory.path else {
        throw BridgeError("Icon backups must be inside your home directory and cannot follow symbolic links")
    }
    return directory.appendingPathComponent("icon-metadata.json")
}

private func readBackup(_ url: URL, target: URL) throws -> [String: Any] {
    guard let backup = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
          backup["version"] as? Int == 1, let original = backup["original"] as? [String: Any],
          original["target"] as? String == target.path else {
        throw BridgeError("Icon backup does not belong to this target")
    }
    let info = try fileInfo(target.path)
    guard (original["device"] as? NSNumber)?.int32Value == info.st_dev,
          (original["inode"] as? NSNumber)?.uint64Value == info.st_ino else {
        throw BridgeError("The target was replaced since backup; refusing to modify the replacement")
    }
    return backup
}

private func writeBackup(_ value: [String: Any], to url: URL) throws {
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: url, options: .atomic)
    try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
}

private func restoreIcon(_ original: [String: Any], target: URL) throws {
    guard let attributes = original["attributes"] as? [String: Any] else { throw BridgeError("Missing icon backup metadata") }
    let isDirectory = (try fileInfo(target.path)).st_mode & S_IFMT == S_IFDIR
    if isDirectory {
        let path = target.appendingPathComponent("Icon\r").path
        _ = try folderIconFile(target) // Refuse symlinks or unexpected files before writing.
        if let saved = original["folderIcon"] as? [String: Any] {
            guard let encoded = saved["data"] as? String, let bytes = Data(base64Encoded: encoded),
                  let attrs = saved["attributes"] as? [String: Any],
                  let permissions = saved["permissions"] as? NSNumber,
                  let flags = saved["flags"] as? NSNumber else { throw BridgeError("Invalid folder icon backup") }
            // In-place writing preserves an existing inode and ACLs.
            if !fm.fileExists(atPath: path) { guard fm.createFile(atPath: path, contents: nil) else { throw BridgeError("Cannot recreate original icon file") } }
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: bytes)
            try handle.synchronize()
            try restoreAttributes(attrs, path: path, exact: true)
            guard chmod(path, mode_t(permissions.uint16Value)) == 0, chflags(path, flags.uint32Value) == 0 else {
                throw BridgeError("Cannot restore the original icon file permissions")
            }
            if let created = saved["created"] as? Double { try fm.setAttributes([.creationDate: Date(timeIntervalSince1970: created)], ofItemAtPath: path) }
            if let accessed = saved["accessed"] as? Double, let modified = saved["modified"] as? Double {
                var accessTime = timeval()
                accessTime.tv_sec = Int(accessed.rounded(.down))
                accessTime.tv_usec = Int32((accessed - floor(accessed)) * 1_000_000)
                var modifyTime = timeval()
                modifyTime.tv_sec = Int(modified.rounded(.down))
                modifyTime.tv_usec = Int32((modified - floor(modified)) * 1_000_000)
                var times = [accessTime, modifyTime]
                guard utimes(path, &times) == 0 else { throw BridgeError("Cannot restore the original icon file timestamps") }
            }
        } else if fm.fileExists(atPath: path) {
            // Fingerprint validation is required before this function is called.
            try fm.removeItem(atPath: path)
        }
    }
    try restoreAttributes(attributes, path: target.path, exact: false)
    NSWorkspace.shared.noteFileSystemChanged(target.path)
}

func iconCommand(_ args: [String]) throws -> Any {
    guard args.count >= 2 else { throw BridgeError("Usage: AeroBridge icon backup|set|restore TARGET ...") }
    let target = try safeTarget(args[1])
    switch args[0] {
    case "backup":
        try requireCount(args, 3, "icon backup TARGET BACKUP_DIRECTORY")
        let file = try backupURL(args[2])
        guard !fm.fileExists(atPath: file.path) else { throw BridgeError("An icon backup already exists here; it will not be overwritten") }
        let snapshot = try iconSnapshot(target)
        try writeBackup(["version": 1, "created": isoDate(Date()), "original": snapshot], to: file)
        return ["ok": true, "backup": file.path]
    case "set":
        guard args.count == 4 else { throw BridgeError("Usage: AeroBridge icon set TARGET PNG BACKUP_DIRECTORY (backup required)") }
        let file = try backupURL(args[3])
        var backup = try readBackup(file, target: target)
        let before = try iconSnapshot(target)
        if let applied = backup["appliedFingerprint"] as? String {
            guard try fingerprint(before) == applied else { throw BridgeError("The icon changed outside Aero Blue; keep the existing icon or create a fresh backup") }
        } else if let original = backup["original"] as? [String: Any] {
            guard try fingerprint(before) == fingerprint(original) else { throw BridgeError("The icon changed after backup; make a new backup before applying") }
        }
        let imageURL = URL(fileURLWithPath: args[2])
        let bytes = try Data(contentsOf: imageURL)
        guard bytes.prefix(8) == Data([137, 80, 78, 71, 13, 10, 26, 10]),
              let image = NSImage(data: bytes), image.isValid,
              image.size.width > 0, image.size.height > 0,
              image.size.width <= 4096, image.size.height <= 4096 else { throw BridgeError("Custom icons require a valid PNG image up to 4096×4096") }
        guard NSWorkspace.shared.setIcon(image, forFile: target.path, options: []) else {
            try restoreIcon(before, target: target)
            throw BridgeError("macOS could not apply this icon; the pre-change metadata was restored")
        }
        do {
            backup["appliedFingerprint"] = try fingerprint(iconSnapshot(target))
            try writeBackup(backup, to: file)
        } catch {
            try restoreIcon(before, target: target)
            throw error
        }
        return ["ok": true, "target": target.path]
    case "restore":
        try requireCount(args, 3, "icon restore TARGET BACKUP_DIRECTORY")
        let file = try backupURL(args[2])
        var backup = try readBackup(file, target: target)
        guard let original = backup["original"] as? [String: Any] else { throw BridgeError("Invalid icon backup") }
        let current = try iconSnapshot(target)
        if try fingerprint(current) == fingerprint(original) { return ["ok": true, "alreadyRestored": true] }
        guard let applied = backup["appliedFingerprint"] as? String, try fingerprint(current) == applied else {
            throw BridgeError("Icon metadata changed after Aero Blue applied it; refusing to overwrite your newer icon")
        }
        try restoreIcon(original, target: target)
        backup.removeValue(forKey: "appliedFingerprint")
        try writeBackup(backup, to: file)
        return ["ok": true, "target": target.path]
    default: throw BridgeError("Unknown icon operation")
    }
}
