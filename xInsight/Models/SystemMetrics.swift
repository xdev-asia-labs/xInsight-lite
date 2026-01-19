import Foundation

// MARK: - System Metrics Model
struct SystemMetrics: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    
    // CPU Metrics
    var cpuUsage: Double              // 0-100%
    var cpuPerformanceCores: Double   // P-cores usage
    var cpuEfficiencyCores: Double    // E-cores usage
    var cpuCoreCount: Int             // Total cores
    
    // Memory Metrics
    var memoryUsed: UInt64            // Bytes
    var memoryTotal: UInt64           // Bytes
    var memoryPressure: MemoryPressure
    var swapUsed: UInt64              // Bytes
    var memoryWired: UInt64           // Bytes
    var memoryCompressed: UInt64      // Bytes
    
    // GPU Metrics
    var gpuUsage: Double              // 0-100%
    var gpuMemoryUsed: UInt64         // Bytes
    
    // Disk I/O Metrics
    var diskReadRate: Double          // MB/s
    var diskWriteRate: Double         // MB/s
    var diskReadOps: UInt64           // Operations
    var diskWriteOps: UInt64          // Operations
    
    // Thermal Metrics
    var cpuTemperature: Double        // Celsius
    var gpuTemperature: Double        // Celsius
    var fanSpeed: Int                 // RPM (0 if no fan - M1/M2 Air)
    var thermalState: ThermalState
    
    // Network Metrics
    var networkBytesIn: UInt64        // Bytes/sec
    var networkBytesOut: UInt64       // Bytes/sec
    
    init() {
        self.id = UUID()
        self.timestamp = Date()
        self.cpuUsage = 0
        self.cpuPerformanceCores = 0
        self.cpuEfficiencyCores = 0
        self.cpuCoreCount = Foundation.ProcessInfo.processInfo.processorCount
        self.memoryUsed = 0
        self.memoryTotal = Foundation.ProcessInfo.processInfo.physicalMemory
        self.memoryPressure = .normal
        self.swapUsed = 0
        self.memoryWired = 0
        self.memoryCompressed = 0
        self.gpuUsage = 0
        self.gpuMemoryUsed = 0
        self.diskReadRate = 0
        self.diskWriteRate = 0
        self.diskReadOps = 0
        self.diskWriteOps = 0
        self.cpuTemperature = 0
        self.gpuTemperature = 0
        self.fanSpeed = 0
        self.thermalState = .nominal
        self.networkBytesIn = 0
        self.networkBytesOut = 0
    }
}

// MARK: - Memory Pressure Level
enum MemoryPressure: String, Codable, CaseIterable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "Bộ nhớ hoạt động bình thường"
        case .warning: return "Bộ nhớ đang chịu áp lực"
        case .critical: return "Bộ nhớ nghiêm trọng - hệ thống có thể chậm"
        }
    }
}

// MARK: - Thermal State
enum ThermalState: String, Codable, CaseIterable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .nominal: return "green"
        case .fair: return "yellow"
        case .serious: return "orange"
        case .critical: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .nominal: return "Nhiệt độ bình thường"
        case .fair: return "Hệ thống đang nóng lên"
        case .serious: return "Hệ thống nóng - có thể throttle"
        case .critical: return "Quá nóng - đang throttle CPU"
        }
    }
}

// MARK: - System Status (Overall)
enum SystemStatus: String, CaseIterable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
    
    var iconName: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
    
    var menuBarIcon: String {
        switch self {
        case .normal: return "speedometer"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "exclamationmark.octagon"
        }
    }
    
    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
}

// MARK: - Formatted Helpers
extension SystemMetrics {
    var formattedMemoryUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsed), countStyle: .memory)
    }
    
    var formattedMemoryTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryTotal), countStyle: .memory)
    }
    
    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100
    }
    
    var formattedDiskRead: String {
        String(format: "%.1f MB/s", diskReadRate)
    }
    
    var formattedDiskWrite: String {
        String(format: "%.1f MB/s", diskWriteRate)
    }
    
    var formattedCPUTemp: String {
        String(format: "%.0f°C", cpuTemperature)
    }
    
    // Network speeds in MB/s
    var networkDownloadSpeed: Double {
        Double(networkBytesIn) / 1_000_000
    }
    
    var networkUploadSpeed: Double {
        Double(networkBytesOut) / 1_000_000
    }
    
    // Disk speeds (alias for consistency)
    var diskReadSpeed: Double {
        diskReadRate
    }
    
    var diskWriteSpeed: Double {
        diskWriteRate
    }
    
    // Active connections (placeholder - would need real implementation)
    var activeConnections: Int {
        // This would need actual network monitoring
        Int.random(in: 5...25)
    }
}
