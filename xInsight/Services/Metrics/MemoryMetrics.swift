import Foundation
import Darwin

/// Collects Memory metrics using Mach VM statistics
class MemoryMetrics {
    
    struct MemoryData {
        var used: UInt64 = 0
        var total: UInt64 = 0
        var free: UInt64 = 0
        var active: UInt64 = 0
        var inactive: UInt64 = 0
        var wired: UInt64 = 0
        var compressed: UInt64 = 0
        var swapUsed: UInt64 = 0
        var pressure: MemoryPressure = .normal
    }
    
    private let pageSize: UInt64
    
    init() {
        var size = vm_size_t()
        host_page_size(mach_host_self(), &size)
        self.pageSize = UInt64(size)
    }
    
    func collect() -> MemoryData {
        var data = MemoryData()
        
        // Get VM statistics
        if let vmStats = vmStatistics64() {
            data.free = UInt64(vmStats.free_count) * pageSize
            data.active = UInt64(vmStats.active_count) * pageSize
            data.inactive = UInt64(vmStats.inactive_count) * pageSize
            data.wired = UInt64(vmStats.wire_count) * pageSize
            data.compressed = UInt64(vmStats.compressor_page_count) * pageSize
            
            data.total = UInt64(Foundation.ProcessInfo.processInfo.physicalMemory)
            data.used = data.active + data.wired + data.compressed
            
            // Calculate memory pressure
            data.pressure = calculatePressure(data: data)
        }
        
        // Get swap usage
        data.swapUsed = getSwapUsage()
        
        return data
    }
    
    private func vmStatistics64() -> vm_statistics64? {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64()
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        return vmStats
    }
    
    private func getSwapUsage() -> UInt64 {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        guard result == 0 else { return 0 }
        
        return swapUsage.xsu_used
    }
    
    private func calculatePressure(data: MemoryData) -> MemoryPressure {
        guard data.total > 0 else { return .normal }
        
        let usedPercent = Double(data.used) / Double(data.total) * 100
        let compressedRatio = Double(data.compressed) / Double(data.total) * 100
        
        // Critical: >90% used or significant swap usage or high compression
        if usedPercent > 90 || data.swapUsed > 1024 * 1024 * 1024 || compressedRatio > 30 {
            return .critical
        }
        
        // Warning: >75% used or moderate compression
        if usedPercent > 75 || compressedRatio > 15 {
            return .warning
        }
        
        return .normal
    }
}

// MARK: - Per-Process Memory Usage
extension MemoryMetrics {
    /// Get memory usage for a specific process using proc_pidinfo (no root needed)
    static func memoryUsage(for pid: Int32) -> UInt64 {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(size))
        
        guard result == Int32(size) else { return 0 }
        
        // resident_size is the memory actually in RAM
        return taskInfo.pti_resident_size
    }
}
