import Darwin
import Foundation
import IOKit.ps

private func cpuTicks() -> [UInt32]? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    let capacity = Int(count)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
            host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
        }
    }
    guard status == KERN_SUCCESS else { return nil }
    return [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3]
}

private func cpuPercentage() -> Double? {
    guard let before = cpuTicks() else { return nil }
    Thread.sleep(forTimeInterval: 0.2)
    guard let after = cpuTicks() else { return nil }
    let delta = zip(after, before).map { UInt64($0.0 &- $0.1) }
    let total = delta.reduce(0, +)
    guard total > 0 else { return nil }
    return 100 * Double(total - delta[Int(CPU_STATE_IDLE)]) / Double(total)
}

private func memoryUsed() -> UInt64? {
    var statistics = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let capacity = Int(count)
    let status = withUnsafeMutablePointer(to: &statistics) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    guard status == KERN_SUCCESS else { return nil }
    var pageSize: vm_size_t = 0
    guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else { return nil }
    // App memory + wired + compressed. Reclaimable inactive pages are excluded.
    let pages = UInt64(statistics.active_count) + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)
    return pages * UInt64(pageSize)
}

private func powerState() -> (Double?, Bool?) {
    guard let unmanagedInfo = IOPSCopyPowerSourcesInfo() else { return (nil, nil) }
    let info = unmanagedInfo.takeRetainedValue()
    guard let unmanagedSources = IOPSCopyPowerSourcesList(info) else { return (nil, nil) }
    let sources = unmanagedSources.takeRetainedValue() as [CFTypeRef]
    for source in sources {
        guard let unmanaged = IOPSGetPowerSourceDescription(info, source) else { continue }
        let item = unmanaged.takeUnretainedValue() as NSDictionary
        guard let type = item[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType,
              let current = item[kIOPSCurrentCapacityKey] as? NSNumber,
              let maximum = item[kIOPSMaxCapacityKey] as? NSNumber, maximum.doubleValue > 0 else { continue }
        return (max(0, min(100, current.doubleValue / maximum.doubleValue * 100)), item[kIOPSIsChargingKey] as? Bool)
    }
    return (nil, nil)
}

func systemSnapshot() -> [String: Any] {
    let missing = NSNull()
    let memory = memoryUsed()
    let total = ProcessInfo.processInfo.physicalMemory
    let battery = powerState()
    let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
    let volume = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: keys)
    let diskTotal = volume?.volumeTotalCapacity.map { Int64($0) }
    let diskAvailable = volume?.volumeAvailableCapacityForImportantUsage
    let diskUsed: Int64? = {
        guard let diskTotal, let diskAvailable else { return nil }
        return max(0, diskTotal - diskAvailable)
    }()
    var result: [String: Any] = [
        "available": true,
        "sampledAt": isoDate(Date()),
        "cpuPercent": cpuPercentage().map { $0 as Any } ?? missing,
        "memoryUsedBytes": memory.map { $0 as Any } ?? missing,
        "memoryTotalBytes": total,
        "memoryPercent": missing,
        "batteryPercent": battery.0.map { $0 as Any } ?? missing,
        "batteryCharging": battery.1.map { $0 as Any } ?? missing,
        "diskUsedBytes": diskUsed.map { $0 as Any } ?? missing,
        "diskTotalBytes": diskTotal.map { $0 as Any } ?? missing,
        "diskPercent": missing
    ]
    if let memory, total > 0 { result["memoryPercent"] = min(100, Double(memory) / Double(total) * 100) }
    if let diskUsed, let diskTotal, diskTotal > 0 { result["diskPercent"] = Double(diskUsed) / Double(diskTotal) * 100 }
    return result
}
