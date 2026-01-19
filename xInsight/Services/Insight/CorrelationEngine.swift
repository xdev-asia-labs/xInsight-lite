import Foundation

/// Correlates system metrics with process activity to identify causes
class CorrelationEngine {
    
    /// Correlate metrics spikes with process resource usage
    func correlate(metrics: SystemMetrics, processes: [ProcessInfo]) -> [Correlation] {
        var correlations: [Correlation] = []
        
        // CPU Correlations
        if metrics.cpuUsage > 50 {
            let cpuCorrelations = correlateCPU(usage: metrics.cpuUsage, processes: processes)
            correlations.append(contentsOf: cpuCorrelations)
        }
        
        // Memory Correlations
        if metrics.memoryPressure != .normal {
            let memCorrelations = correlateMemory(pressure: metrics.memoryPressure, processes: processes)
            correlations.append(contentsOf: memCorrelations)
        }
        
        // Disk I/O Correlations
        if metrics.diskReadRate > 50 || metrics.diskWriteRate > 50 {
            let diskCorrelations = correlateDiskIO(
                readRate: metrics.diskReadRate,
                writeRate: metrics.diskWriteRate,
                processes: processes
            )
            correlations.append(contentsOf: diskCorrelations)
        }
        
        return correlations
    }
    
    // MARK: - CPU Correlation
    
    private func correlateCPU(usage: Double, processes: [ProcessInfo]) -> [Correlation] {
        var correlations: [Correlation] = []
        
        // Find processes that account for the CPU usage
        let topCPU = processes.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(5)
        
        for process in topCPU where process.cpuUsage > 10 {
            let strength = min(process.cpuUsage / usage, 1.0)
            let description = describeProcessCPUUsage(process)
            
            correlations.append(Correlation(
                sourceMetric: "CPU Usage",
                targetProcess: process,
                strength: strength,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeProcessCPUUsage(_ process: ProcessInfo) -> String {
        let name = process.displayName
        let usage = Int(process.cpuUsage)
        
        // Browser-specific descriptions
        if process.category == .browser {
            return "\(name) đang sử dụng \(usage)% CPU - có thể do nhiều tabs hoặc extensions"
        }
        
        // Developer tools
        if process.category == .developer {
            if name.lowercased().contains("xcode") {
                return "\(name) đang sử dụng \(usage)% CPU - có thể đang build hoặc indexing"
            }
            if name.lowercased().contains("docker") {
                return "Docker đang sử dụng \(usage)% CPU - containers đang hoạt động"
            }
        }
        
        // System processes
        if process.category == .system {
            if name == "kernel_task" {
                return "kernel_task sử dụng \(usage)% CPU - hệ thống có thể đang thermal throttle"
            }
            if name.contains("mds") || name.contains("Spotlight") {
                return "Spotlight đang index - sử dụng \(usage)% CPU"
            }
        }
        
        return "\(name) đang sử dụng \(usage)% CPU"
    }
    
    // MARK: - Memory Correlation
    
    private func correlateMemory(pressure: MemoryPressure, processes: [ProcessInfo]) -> [Correlation] {
        var correlations: [Correlation] = []
        
        // Find top memory consumers
        let topMemory = processes.sorted { $0.memoryUsage > $1.memoryUsage }.prefix(5)
        let totalMemory = UInt64(Foundation.ProcessInfo.processInfo.physicalMemory)
        
        for process in topMemory {
            let memoryRatio = Double(process.memoryUsage) / Double(totalMemory)
            guard memoryRatio > 0.05 else { continue }  // Skip if less than 5%
            
            let strength = min(memoryRatio * 2, 1.0)
            let description = describeProcessMemoryUsage(process, ratio: memoryRatio)
            
            correlations.append(Correlation(
                sourceMetric: "Memory Pressure",
                targetProcess: process,
                strength: strength,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeProcessMemoryUsage(_ process: ProcessInfo, ratio: Double) -> String {
        let name = process.displayName
        let memoryGB = Double(process.memoryUsage) / 1_073_741_824  // Convert to GB
        let percentOfTotal = Int(ratio * 100)
        
        if memoryGB >= 1 {
            return "\(name) đang chiếm \(String(format: "%.1f", memoryGB))GB RAM (\(percentOfTotal)% tổng bộ nhớ)"
        } else {
            let memoryMB = Int(Double(process.memoryUsage) / 1_048_576)
            return "\(name) đang sử dụng \(memoryMB)MB RAM"
        }
    }
    
    // MARK: - Disk I/O Correlation
    
    private func correlateDiskIO(readRate: Double, writeRate: Double, processes: [ProcessInfo]) -> [Correlation] {
        var correlations: [Correlation] = []
        
        // Find processes with high disk activity
        let topDisk = processes.sorted { 
            ($0.diskReadBytes + $0.diskWriteBytes) > ($1.diskReadBytes + $1.diskWriteBytes) 
        }.prefix(3)
        
        for process in topDisk {
            let totalBytes = process.diskReadBytes + process.diskWriteBytes
            guard totalBytes > 10_000_000 else { continue }  // Skip if less than 10MB total
            
            let description = describeProcessDiskUsage(process)
            
            correlations.append(Correlation(
                sourceMetric: "Disk I/O",
                targetProcess: process,
                strength: 0.8,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeProcessDiskUsage(_ process: ProcessInfo) -> String {
        let name = process.displayName
        
        // Spotlight indexing
        if name.contains("mds") || name.contains("Spotlight") {
            return "Spotlight đang index files - gây ra disk I/O cao"
        }
        
        // Time Machine
        if name.contains("backupd") || name.contains("Time Machine") {
            return "Time Machine đang backup - disk I/O sẽ cao trong thời gian ngắn"
        }
        
        // iCloud sync
        if name.contains("bird") || name.contains("cloudd") {
            return "iCloud đang sync files - có thể gây disk I/O"
        }
        
        return "\(name) đang đọc/ghi disk nhiều"
    }
}
