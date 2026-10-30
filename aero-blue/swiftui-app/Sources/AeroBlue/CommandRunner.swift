import Foundation

struct CommandFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum CommandRunner {
    // Both pipes are drained concurrently so a large diagnostic cannot deadlock the UI.
    static func run(_ executable: URL, _ arguments: [String], directory: URL? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let output = Pipe()
                let errors = Pipe()
                process.executableURL = executable
                process.arguments = arguments
                process.currentDirectoryURL = directory
                process.standardOutput = output
                process.standardError = errors
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                let group = DispatchGroup()
                let errorData = LockedData()
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    errorData.set(errors.fileHandleForReading.readDataToEndOfFile())
                    group.leave()
                }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                group.wait()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: data)
                } else {
                    let diagnostic = String(data: errorData.get(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(throwing: CommandFailure(message: diagnostic?.isEmpty == false ? diagnostic! : "Command exited with status \(process.terminationStatus)."))
                }
            }
        }
    }

    private final class LockedData: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func set(_ value: Data) { lock.lock(); defer { lock.unlock() }; data = value }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }
}
