import EventKit
import Foundation

private func mayReadEvents(_ status: EKAuthorizationStatus) -> Bool {
    if #available(macOS 14.0, *) { return status == .fullAccess || status == .authorized }
    return status == .authorized
}

private func authorizationName(_ status: EKAuthorizationStatus) -> String {
    if mayReadEvents(status) { return "authorized" }
    if #available(macOS 14.0, *), status == .writeOnly { return "writeOnly" }
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    default: return "unavailable"
    }
}

func calendarCommand(_ args: [String]) throws -> Any {
    guard args.isEmpty || args == ["request"] else { throw BridgeError("Usage: AeroBridge calendar [request]") }
    let store = EKEventStore()
    var permissionError: String?
    if args == ["request"], !mayReadEvents(EKEventStore.authorizationStatus(for: .event)) {
        let privacyKey: String
        if #available(macOS 14.0, *) { privacyKey = "NSCalendarsFullAccessUsageDescription" }
        else { privacyKey = "NSCalendarsUsageDescription" }
        guard let explanation = Bundle.main.object(forInfoDictionaryKey: privacyKey) as? String,
              !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BridgeError("Calendar permission can only be requested from the built Aero Blue Control Center.app with its privacy descriptions. Build/install the app and use its Calendar permission button; do not request access from the standalone SwiftPM executable.")
        }
        // The explicit request command is the sole permission prompt path.
        let lock = NSLock()
        var complete = false
        let callback: (Bool, Error?) -> Void = { _, error in
            lock.lock()
            permissionError = error?.localizedDescription
            complete = true
            lock.unlock()
        }
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents(completion: callback)
        } else {
            store.requestAccess(to: .event, completion: callback)
        }
        let deadline = Date(timeIntervalSinceNow: 120)
        while true {
            lock.lock()
            let finished = complete
            lock.unlock()
            if finished { break }
            guard Date() < deadline else { throw BridgeError("Calendar permission request timed out; check System Settings > Privacy & Security > Calendars") }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }
    let status = EKEventStore.authorizationStatus(for: .event)
    var result: [String: Any] = ["authorized": mayReadEvents(status), "status": authorizationName(status), "events": []]
    if let permissionError { result["error"] = permissionError }
    guard mayReadEvents(status) else { return result }
    let now = Date()
    let start = Calendar.current.startOfDay(for: now)
    guard let end = Calendar.current.date(byAdding: .day, value: 7, to: start) else {
        throw BridgeError("Could not calculate the calendar date range")
    }
    let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
    let events = store.events(matching: predicate)
        .filter { $0.endDate > now }
        .sorted { $0.startDate < $1.startDate }
        .prefix(50)
    result["events"] = events.map { event -> [String: Any] in
        ["id": event.calendarItemIdentifier,
         "title": event.title ?? "Untitled event",
         "start": isoDate(event.startDate),
         "end": isoDate(event.endDate),
         "allDay": event.isAllDay,
         "calendar": event.calendar.title]
    }
    result["rangeStart"] = isoDate(start)
    result["rangeEnd"] = isoDate(end)
    return result
}
