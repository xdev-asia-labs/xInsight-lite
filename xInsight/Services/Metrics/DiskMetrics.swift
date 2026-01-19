import Foundation
import IOKit
import IOKit.storage

/// Collects Disk I/O metrics
class DiskMetrics {
    
    struct DiskData {
        var readRate: Double = 0      // MB/s
        var writeRate: Double = 0     // MB/s
        var readOps: UInt64 = 0
        var writeOps: UInt64 = 0
        var totalBytesRead: UInt64 = 0
        var totalBytesWritten: UInt64 = 0
    }
    
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousTimestamp: Date?
    
    func collect() -> DiskData {
        var data = DiskData()
        
        // Get disk stats from IOKit
        if let diskStats = getDiskStatistics() {
            data.totalBytesRead = diskStats.bytesRead
            data.totalBytesWritten = diskStats.bytesWritten
            data.readOps = diskStats.readOps
            data.writeOps = diskStats.writeOps
            
            // Calculate rate based on previous measurement
            if let prevTime = previousTimestamp {
                let timeDelta = Date().timeIntervalSince(prevTime)
                if timeDelta > 0 {
                    let readDelta = data.totalBytesRead - previousReadBytes
                    let writeDelta = data.totalBytesWritten - previousWriteBytes
                    
                    // Convert to MB/s
                    data.readRate = Double(readDelta) / timeDelta / 1_000_000
                    data.writeRate = Double(writeDelta) / timeDelta / 1_000_000
                }
            }
            
            previousReadBytes = data.totalBytesRead
            previousWriteBytes = data.totalBytesWritten
            previousTimestamp = Date()
        }
        
        return data
    }
    
    private func getDiskStatistics() -> (bytesRead: UInt64, bytesWritten: UInt64, readOps: UInt64, writeOps: UInt64)? {
        var bytesRead: UInt64 = 0
        var bytesWritten: UInt64 = 0
        var readOps: UInt64 = 0
        var writeOps: UInt64 = 0
        
        // Find block storage drivers
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { 
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            // Get statistics property
            guard let properties = IORegistryEntryCreateCFProperty(
                service,
                "Statistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] else {
                continue
            }
            
            if let read = properties["Bytes (Read)"] as? UInt64 {
                bytesRead += read
            }
            if let written = properties["Bytes (Write)"] as? UInt64 {
                bytesWritten += written
            }
            if let reads = properties["Operations (Read)"] as? UInt64 {
                readOps += reads
            }
            if let writes = properties["Operations (Write)"] as? UInt64 {
                writeOps += writes
            }
        }
        
        return (bytesRead, bytesWritten, readOps, writeOps)
    }
}

// MARK: - Disk Space Info
extension DiskMetrics {
    /// Get disk space information for the main volume
    static func diskSpaceInfo() -> (total: UInt64, free: UInt64, used: UInt64)? {
        let fileManager = FileManager.default
        
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            
            guard let total = attributes[.systemSize] as? UInt64,
                  let free = attributes[.systemFreeSize] as? UInt64 else {
                return nil
            }
            
            return (total, free, total - free)
        } catch {
            return nil
        }
    }
    
    /// Get disk usage percentage
    static var diskUsagePercent: Double {
        guard let info = diskSpaceInfo(), info.total > 0 else { return 0 }
        return Double(info.used) / Double(info.total) * 100
    }
}
