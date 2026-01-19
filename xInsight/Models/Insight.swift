import Foundation

// MARK: - Insight Model
struct Insight: Identifiable, Hashable {
    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    let id: UUID
    let timestamp: Date
    let type: InsightType
    let severity: Severity
    let title: String
    let description: String
    let cause: String
    let affectedProcesses: [ProcessInfo]
    let suggestedActions: [InsightAction]
    let metrics: InsightMetrics?
    
    init(
        type: InsightType,
        severity: Severity,
        title: String,
        description: String,
        cause: String,
        affectedProcesses: [ProcessInfo] = [],
        suggestedActions: [InsightAction] = [],
        metrics: InsightMetrics? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.cause = cause
        self.affectedProcesses = affectedProcesses
        self.suggestedActions = suggestedActions
        self.metrics = metrics
    }
}

// MARK: - Insight Type
enum InsightType: String, CaseIterable {
    case cpuSaturation = "CPU Saturation"
    case memoryPressure = "Memory Pressure"
    case ioBottleneck = "I/O Bottleneck"
    case thermalThrottling = "Thermal Throttling"
    case backgroundMisbehavior = "Background Misbehavior"
    case networkHog = "Network Hog"
    case batteryDrain = "Battery Drain"
    case diskFull = "Disk Full"
    
    var iconName: String {
        switch self {
        case .cpuSaturation: return "cpu"
        case .memoryPressure: return "memorychip"
        case .ioBottleneck: return "internaldrive"
        case .thermalThrottling: return "thermometer.sun"
        case .backgroundMisbehavior: return "moon.circle"
        case .networkHog: return "network"
        case .batteryDrain: return "battery.25"
        case .diskFull: return "externaldrive.badge.exclamationmark"
        }
    }
    
    var category: String {
        switch self {
        case .cpuSaturation, .memoryPressure, .thermalThrottling:
            return "Performance"
        case .ioBottleneck, .diskFull:
            return "Storage"
        case .networkHog:
            return "Network"
        case .backgroundMisbehavior, .batteryDrain:
            return "Efficiency"
        }
    }
}

// MARK: - Severity Level
enum Severity: String, CaseIterable, Comparable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    
    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
    
    var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "yellow"
        case .critical: return "red"
        }
    }
    
    var priority: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
    
    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.priority < rhs.priority
    }
}

// MARK: - Insight Action
struct InsightAction: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let actionType: ActionType
    let impact: String  // e.g., "Giải phóng 2GB RAM"
    
    init(title: String, description: String, actionType: ActionType, impact: String = "") {
        self.id = UUID()
        self.title = title
        self.description = description
        self.actionType = actionType
        self.impact = impact
    }
    
    enum ActionType {
        case quitApp(pid: Int32)
        case forceQuitApp(pid: Int32)
        case reduceLoad(suggestions: [String])
        case systemSetting(path: String)
        case openActivityMonitor
        case restartApp(bundleId: String)
        case clearCache(path: String)
        case custom(handler: () -> Void)
    }
}

// MARK: - Insight Metrics (for visualization)
struct InsightMetrics {
    var currentValue: Double
    var thresholdValue: Double
    var unit: String
    var trend: Trend
    
    enum Trend {
        case increasing
        case stable
        case decreasing
    }
    
    var percentOfThreshold: Double {
        guard thresholdValue > 0 else { return 0 }
        return min(currentValue / thresholdValue * 100, 100)
    }
}

// MARK: - Correlation Model
struct Correlation: Identifiable {
    let id: UUID
    let timestamp: Date
    let sourceMetric: String
    let targetProcess: ProcessInfo
    let correlationStrength: Double  // 0-1
    let description: String
    
    init(sourceMetric: String, targetProcess: ProcessInfo, strength: Double, description: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceMetric = sourceMetric
        self.targetProcess = targetProcess
        self.correlationStrength = strength
        self.description = description
    }
}

// MARK: - Anomaly Model
struct Anomaly: Identifiable {
    let id: UUID
    let timestamp: Date
    let metric: String
    let currentValue: Double
    let expectedValue: Double
    let deviation: Double  // Standard deviations from mean
    let description: String
    
    init(metric: String, currentValue: Double, expectedValue: Double, deviation: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.metric = metric
        self.currentValue = currentValue
        self.expectedValue = expectedValue
        self.deviation = deviation
        self.description = "\(metric) is \(String(format: "%.1f", deviation))σ from normal"
    }
}
