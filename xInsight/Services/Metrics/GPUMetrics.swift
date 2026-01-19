import Foundation
import IOKit

/// GPU Metrics collector for Apple Silicon
class GPUMetrics {
    
    struct GPUData {
        var usage: Double = 0           // GPU utilization %
        var memoryUsed: UInt64 = 0      // GPU memory used (shared on Apple Silicon)
        var memoryTotal: UInt64 = 0     // Total GPU memory available
        var frequency: Double = 0       // Current GPU frequency MHz
        var temperature: Double = 0     // GPU temperature
        var power: Double = 0           // GPU power consumption
    }
    
    private var previousStats: [String: UInt64] = [:]
    private var previousTimestamp: Date = Date()
    
    /// Collect GPU metrics using IOKit
    func collect() -> GPUData {
        var data = GPUData()
        
        // Get GPU utilization via IOKit
        if let gpuEntry = getGPUEntry() {
            data.usage = getGPUUtilization(from: gpuEntry)
            data.temperature = getGPUTemperature()
            data.power = getGPUPower(from: gpuEntry)
            IOObjectRelease(gpuEntry)
        }
        
        // Get GPU memory (shared with system on Apple Silicon)
        let gpuMemory = getGPUMemory()
        data.memoryUsed = gpuMemory.used
        data.memoryTotal = gpuMemory.total
        
        // Get GPU frequency
        data.frequency = getGPUFrequency()
        
        return data
    }
    
    // MARK: - IOKit GPU Access
    
    private func getGPUEntry() -> io_object_t? {
        var iterator: io_iterator_t = 0
        
        // Try Apple Silicon GPU first
        let matchingDict = IOServiceMatching("IOGPU")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        
        let entry = IOIteratorNext(iterator)
        if entry != 0 {
            return entry
        }
        
        return nil
    }
    
    private func getGPUUtilization(from entry: io_object_t) -> Double {
        // Try to get GPU utilization from IOKit properties
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)
        
        guard result == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] else {
            return estimateGPUUsage()
        }
        
        // Apple Silicon GPUs expose performance stats
        if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
            // Device Utilization %
            if let deviceUtilization = perfStats["Device Utilization %"] as? Double {
                return deviceUtilization
            }
            
            // Alternative: calculate from GPU active/idle time
            if let gpuActive = perfStats["GPU Activity(%)"] as? Double {
                return gpuActive
            }
        }
        
        return estimateGPUUsage()
    }
    
    private func estimateGPUUsage() -> Double {
        // Fallback: estimate GPU usage based on Metal activity
        // This is a simplified estimation
        // In reality, would need to use Metal System Trace
        
        // Check if any GPU-intensive apps are running
        let heavyGPUApps = ["WindowServer", "Safari", "Chrome", "Xcode", "Final Cut"]
        
        // For now, return a low default
        // Real implementation would use GPU performance counters
        return 5.0
    }
    
    private func getGPUTemperature() -> Double {
        // GPU temperature on Apple Silicon
        // Note: Requires SMC access which may need elevated privileges
        
        // Estimate based on system thermal state
        let thermalState = Foundation.ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal: return 45.0
        case .fair: return 60.0
        case .serious: return 80.0
        case .critical: return 95.0
        @unknown default: return 50.0
        }
    }
    
    private func getGPUPower(from entry: io_object_t) -> Double {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)
        
        guard result == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] else {
            return 0
        }
        
        // Try to get GPU power consumption
        if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
            if let power = perfStats["GPU Power"] as? Double {
                return power / 1000.0  // Convert to Watts
            }
        }
        
        return 0
    }
    
    private func getGPUMemory() -> (used: UInt64, total: UInt64) {
        // On Apple Silicon, GPU memory is shared with system memory
        // Report a portion of system memory as "GPU available"
        
        let totalMemory = Foundation.ProcessInfo.processInfo.physicalMemory
        
        // Apple Silicon typically reserves up to 1.5x of RAM for GPU
        // But practical GPU memory is usually ~75% of system RAM
        let gpuTotal = UInt64(Double(totalMemory) * 0.75)
        
        // Estimate GPU memory usage based on running apps
        // This is simplified - real implementation would use Metal APIs
        let gpuUsed = estimateGPUMemoryUsage(available: gpuTotal)
        
        return (gpuUsed, gpuTotal)
    }
    
    private func estimateGPUMemoryUsage(available: UInt64) -> UInt64 {
        // Estimate based on window server and running GPU apps
        // Real implementation would aggregate from Metal resource tracking
        
        // Default: ~20% of available GPU memory
        return UInt64(Double(available) * 0.2)
    }
    
    private func getGPUFrequency() -> Double {
        // Apple Silicon GPU frequency varies dynamically
        // Default M1/M2 GPU frequencies range from ~400MHz to ~1300MHz
        
        // Estimate based on thermal state
        let thermalState = Foundation.ProcessInfo.processInfo.thermalState
        switch thermalState {
        case .nominal: return 1296.0  // Max boost
        case .fair: return 1000.0
        case .serious: return 800.0
        case .critical: return 400.0  // Throttled
        @unknown default: return 1000.0
        }
    }
}

// MARK: - GPU Process Tracking

extension GPUMetrics {
    /// Get processes using GPU
    func getGPUProcesses() -> [GPUProcessInfo] {
        var processes: [GPUProcessInfo] = []
        
        // Use IOKit to find processes with GPU clients
        var iterator: io_iterator_t = 0
        let matchingDict = IOServiceMatching("IOGPUDevice")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
        guard result == KERN_SUCCESS else { return processes }
        defer { IOObjectRelease(iterator) }
        
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            if let clients = getGPUClients(from: entry) {
                processes.append(contentsOf: clients)
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        
        return processes
    }
    
    private func getGPUClients(from entry: io_object_t) -> [GPUProcessInfo]? {
        // Get registered clients of GPU device
        var iterator: io_iterator_t = 0
        let result = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &iterator)
        
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        
        var clients: [GPUProcessInfo] = []
        var child = IOIteratorNext(iterator)
        
        while child != 0 {
            if let info = getClientInfo(from: child) {
                clients.append(info)
            }
            IOObjectRelease(child)
            child = IOIteratorNext(iterator)
        }
        
        return clients.isEmpty ? nil : clients
    }
    
    private func getClientInfo(from entry: io_object_t) -> GPUProcessInfo? {
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0)
        
        guard result == KERN_SUCCESS, let props = properties?.takeRetainedValue() as? [String: Any] else {
            return nil
        }
        
        // Extract process info from GPU client
        let pid = props["IOUserClientCreatorPID"] as? Int32 ?? 0
        let name = props["IOUserClientCreator"] as? String ?? "Unknown"
        
        return GPUProcessInfo(pid: pid, name: name, gpuUsage: 0)
    }
}

struct GPUProcessInfo: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    var gpuUsage: Double
}
