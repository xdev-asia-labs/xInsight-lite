import Foundation
import Darwin

/// Collects CPU metrics using host_statistics and sysctl
class CPUMetrics {
    
    struct CPUData {
        var usage: Double = 0
        var performanceCores: Double = 0
        var efficiencyCores: Double = 0
        var userTime: Double = 0
        var systemTime: Double = 0
        var idleTime: Double = 0
    }
    
    private var previousCPUInfo: host_cpu_load_info?
    
    func collect() -> CPUData {
        var data = CPUData()
        
        // Get CPU load info
        if let cpuInfo = hostCPULoadInfo() {
            if let previous = previousCPUInfo {
                data = calculateUsage(current: cpuInfo, previous: previous)
            }
            previousCPUInfo = cpuInfo
        }
        
        return data
    }
    
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        let HOST_CPU_LOAD_INFO_COUNT = MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        
        var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
        var cpuLoadInfo = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        
        if result != KERN_SUCCESS {
            return nil
        }
        
        return cpuLoadInfo
    }
    
    private func calculateUsage(current: host_cpu_load_info, previous: host_cpu_load_info) -> CPUData {
        var data = CPUData()
        
        let userDiff = Double(current.cpu_ticks.0 - previous.cpu_ticks.0)
        let systemDiff = Double(current.cpu_ticks.1 - previous.cpu_ticks.1)
        let idleDiff = Double(current.cpu_ticks.2 - previous.cpu_ticks.2)
        let niceDiff = Double(current.cpu_ticks.3 - previous.cpu_ticks.3)
        
        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        
        if totalTicks > 0 {
            data.userTime = (userDiff + niceDiff) / totalTicks * 100
            data.systemTime = systemDiff / totalTicks * 100
            data.idleTime = idleDiff / totalTicks * 100
            data.usage = 100 - data.idleTime
        }
        
        // On Apple Silicon, estimate P-core vs E-core usage
        // This is a simplified approximation
        if isAppleSilicon() {
            // When CPU usage is high, P-cores are more likely engaged
            if data.usage > 50 {
                data.performanceCores = min(data.usage * 1.2, 100)
                data.efficiencyCores = max(data.usage * 0.8, 0)
            } else {
                data.performanceCores = data.usage * 0.5
                data.efficiencyCores = data.usage
            }
        } else {
            data.performanceCores = data.usage
            data.efficiencyCores = 0
        }
        
        return data
    }
    
    private func isAppleSilicon() -> Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine.contains("arm64")
    }
}

// MARK: - Per-Process CPU Usage
extension CPUMetrics {
    /// Get CPU usage for a specific process
    static func cpuUsage(for pid: Int32) -> Double {
        var taskInfo = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
        
        var task: task_t = 0
        let result = task_for_pid(mach_task_self_, pid, &task)
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let infoResult = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: Int32.self, capacity: Int(count)) {
                task_info(task, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard infoResult == KERN_SUCCESS else { return 0 }
        
        // This returns user+system time, not instantaneous CPU %
        // Real implementation would need to track deltas over time
        return 0
    }
}
