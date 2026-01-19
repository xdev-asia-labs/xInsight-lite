import Foundation

/// SystemHealthScore - Calculates overall system health as a 0-100 score
@MainActor
final class SystemHealthScore: ObservableObject {
    static let shared = SystemHealthScore()
    
    // MARK: - Published Properties
    @Published var overallScore: Int = 100
    @Published var cpuScore: Int = 100
    @Published var memoryScore: Int = 100
    @Published var thermalScore: Int = 100
    @Published var diskScore: Int = 100
    @Published var batteryScore: Int = 100
    
    @Published var healthStatus: HealthStatus = .excellent
    @Published var recommendations: [HealthRecommendation] = []
    
    private init() {}
    
    // MARK: - Calculate Health Score
    
    func calculate(from metrics: SystemMetrics, processes: [ProcessInfo] = []) {
        // CPU Score (100 = idle, 0 = 100% usage)
        cpuScore = max(0, min(100, Int(100 - metrics.cpuUsage)))
        
        // Memory Score
        let memPercent = metrics.memoryUsagePercent
        if memPercent < 50 {
            memoryScore = 100
        } else if memPercent < 70 {
            memoryScore = Int(100 - (memPercent - 50) * 2)
        } else if memPercent < 85 {
            memoryScore = Int(60 - (memPercent - 70) * 3)
        } else {
            memoryScore = max(0, Int(15 - (memPercent - 85) * 1.5))
        }
        
        // Thermal Score
        let temp = metrics.cpuTemperature
        if temp < 50 {
            thermalScore = 100
        } else if temp < 70 {
            thermalScore = Int(100 - (temp - 50) * 2)
        } else if temp < 85 {
            thermalScore = Int(60 - (temp - 70) * 3)
        } else {
            thermalScore = max(0, Int(15 - (temp - 85) * 1.5))
        }
        
        // Disk Score (based on I/O rate and available space)
        let ioRate = metrics.diskReadSpeed + metrics.diskWriteSpeed
        if ioRate < 50 {
            diskScore = 100
        } else if ioRate < 200 {
            diskScore = Int(100 - (ioRate - 50) / 3)
        } else {
            diskScore = max(20, Int(50 - (ioRate - 200) / 10))
        }
        
        // Battery Score - not available in SystemMetrics, use default
        batteryScore = 100
        
        // Calculate weighted overall score
        let weights: [Double] = [0.30, 0.25, 0.20, 0.15, 0.10] // CPU, Memory, Thermal, Disk, Battery
        let scores = [cpuScore, memoryScore, thermalScore, diskScore, batteryScore]
        overallScore = Int(zip(weights, scores.map { Double($0) }).reduce(0) { $0 + $1.0 * $1.1 })
        
        // Determine status
        switch overallScore {
        case 90...100: healthStatus = .excellent
        case 70..<90: healthStatus = .good
        case 50..<70: healthStatus = .fair
        case 30..<50: healthStatus = .poor
        default: healthStatus = .critical
        }
        
        // Generate recommendations
        generateRecommendations(metrics: metrics, processes: processes)
    }
    
    // MARK: - Generate Recommendations
    
    private func generateRecommendations(metrics: SystemMetrics, processes: [ProcessInfo]) {
        var newRecs: [HealthRecommendation] = []
        
        if cpuScore < 50 {
            let topCPU = processes.max { $0.cpuUsage < $1.cpuUsage }
            newRecs.append(HealthRecommendation(
                category: .cpu,
                title: "High CPU Usage",
                description: topCPU != nil ? "Consider closing \(topCPU!.name)" : "Close unused applications",
                impact: .high,
                action: topCPU != nil ? .killProcess(pid: topCPU!.pid) : nil
            ))
        }
        
        if memoryScore < 50 {
            let topMem = processes.max { $0.memoryUsage < $1.memoryUsage }
            newRecs.append(HealthRecommendation(
                category: .memory,
                title: "High Memory Pressure",
                description: topMem != nil ? "\(topMem!.name) using \(ByteCountFormatter.string(fromByteCount: Int64(topMem!.memoryUsage), countStyle: .memory))" : "Close memory-heavy apps",
                impact: .high,
                action: topMem != nil ? .killProcess(pid: topMem!.pid) : nil
            ))
        }
        
        if thermalScore < 50 {
            newRecs.append(HealthRecommendation(
                category: .thermal,
                title: "High Temperature",
                description: "System is running hot (\(String(format: "%.0f", metrics.cpuTemperature))°C)",
                impact: .medium,
                action: .reduceLoad
            ))
        }
        
        if diskScore < 50 {
            newRecs.append(HealthRecommendation(
                category: .disk,
                title: "High Disk Activity",
                description: "Disk I/O is intensive",
                impact: .low,
                action: nil
            ))
        }
        
        if batteryScore < 30 {
            newRecs.append(HealthRecommendation(
                category: .battery,
                title: "Battery Check",
                description: "Check battery status",
                impact: .high,
                action: nil
            ))
        }
        
        recommendations = newRecs
    }
}

// MARK: - Models

enum HealthStatus: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .critical: return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🔵"
        case .fair: return "🟡"
        case .poor: return "🟠"
        case .critical: return "🔴"
        }
    }
}

struct HealthRecommendation: Identifiable {
    let id = UUID()
    let category: RecommendationCategory
    let title: String
    let description: String
    let impact: Impact
    let action: RecommendationAction?
    
    enum RecommendationCategory {
        case cpu, memory, thermal, disk, battery
        
        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .thermal: return "thermometer"
            case .disk: return "internaldrive"
            case .battery: return "battery.50"
            }
        }
    }
    
    enum Impact { case low, medium, high }
    
    enum RecommendationAction {
        case killProcess(pid: Int32)
        case reduceLoad
        case openSettings
        case cleanup
    }
}
