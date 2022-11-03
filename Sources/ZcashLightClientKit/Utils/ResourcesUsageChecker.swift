//
//  ResourcesUsageChecker.swift
//
//
//  Created by Michal Fousek on 24.10.2022.
//
import Foundation

/*
 When you create instance of `ResourcesUsageChecker` it will mark how much resources is used. And this mark will be used as "virtual" 0. Thanks to
 that you can measure how much resources does your specific feature use.
 */
final class ResourcesUsageChecker {

    private let memoryZero: Float?
    private let diskZero: Int64?
    private let startTime = Date()

    init() {
        memoryZero = ResourcesUsageChecker.usedMemory()
        diskZero = ResourcesUsageChecker.freeDiskSpace()
    }

    func printUsage() {
        LoggerProxy.debug("Memory usage: \(usedMemoryAmount ?? -1)")
        LoggerProxy.debug("Disk usage  : \(usedDiskSpace ?? -1)")
        LoggerProxy.debug("Time taken  : \(Date().timeIntervalSince(startTime))")
    }

    var usedMemoryAmount: Float? {
        guard let memoryZero, let usedMemory = ResourcesUsageChecker.usedMemory() else { return nil }
        return usedMemory - memoryZero
    }

    private static func usedMemory() -> Float? {
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let usedMb = Float(taskInfo.phys_footprint) / 1048576.0
        return result == KERN_SUCCESS ? usedMb : nil
    }

    var usedDiskSpace: Int64? {
        guard let diskZero, let freeDiskSpace = ResourcesUsageChecker.freeDiskSpace() else { return nil }
        return diskZero - freeDiskSpace
    }

    private static func freeDiskSpace() -> Int64? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let value = values.volumeAvailableCapacityForImportantUsage {
                return value  / 1048576
            } else {
                return nil
            }
        } catch {
            return nil
        }
    }
}
