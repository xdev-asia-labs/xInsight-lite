import Foundation
import UserNotifications

/// CustomAlerts - User-configurable alert thresholds and notifications
@MainActor
final class CustomAlerts: ObservableObject {
    static let shared = CustomAlerts()
    
    // MARK: - Published Properties
    @Published var alerts: [CustomAlert] = []
    @Published var triggeredAlerts: [TriggeredAlert] = []
    @Published var isEnabled = true
    
    private var cooldowns: [String: Date] = [:] // Prevent spam
    
    private init() {
        loadAlerts()
        if alerts.isEmpty {
            setupDefaultAlerts()
        }
    }
    
    // MARK: - Default Alerts
    
    private func setupDefaultAlerts() {
        alerts = [
            CustomAlert(
                id: "cpu_high",
                name: "High CPU Usage",
                metric: .cpu,
                condition: .above,
                threshold: 80,
                duration: 60,
                isEnabled: true
            ),
            CustomAlert(
                id: "memory_high",
                name: "High Memory Usage",
                metric: .memory,
                condition: .above,
                threshold: 85,
                duration: 30,
                isEnabled: true
            ),
            CustomAlert(
                id: "temp_warning",
                name: "Temperature Warning",
                metric: .temperature,
                condition: .above,
                threshold: 80,
                duration: 30,
                isEnabled: true
            ),
            CustomAlert(
                id: "temp_critical",
                name: "Critical Temperature",
                metric: .temperature,
                condition: .above,
                threshold: 95,
                duration: 10,
                isEnabled: true
            ),
            CustomAlert(
                id: "disk_full",
                name: "Low Disk Space",
                metric: .diskSpace,
                condition: .below,
                threshold: 10,
                duration: 0,
                isEnabled: true
            )
        ]
        saveAlerts()
    }
    
    // MARK: - Check Alerts
    
    func check(metrics: SystemMetrics) {
        guard isEnabled else { return }
        
        for alert in alerts where alert.isEnabled {
            let value = getValue(for: alert.metric, from: metrics)
            let triggered = checkCondition(value: value, condition: alert.condition, threshold: alert.threshold)
            
            if triggered {
                triggerAlert(alert, currentValue: value)
            }
        }
    }
    
    private func getValue(for metric: AlertMetric, from metrics: SystemMetrics) -> Double {
        switch metric {
        case .cpu: return metrics.cpuUsage
        case .memory: return metrics.memoryUsagePercent
        case .temperature: return metrics.cpuTemperature
        case .diskSpace: return 50 // Placeholder - disk space percentage available
        case .gpu: return metrics.gpuUsage
        case .networkIn: return Double(metrics.networkBytesIn) / 1_048_576
        case .networkOut: return Double(metrics.networkBytesOut) / 1_048_576
        }
    }
    
    private func checkCondition(value: Double, condition: AlertCondition, threshold: Double) -> Bool {
        switch condition {
        case .above: return value > threshold
        case .below: return value < threshold
        case .equals: return abs(value - threshold) < 1
        }
    }
    
    private func triggerAlert(_ alert: CustomAlert, currentValue: Double) {
        // Check cooldown (5 minutes between same alert)
        if let lastTrigger = cooldowns[alert.id], Date().timeIntervalSince(lastTrigger) < 300 {
            return
        }
        
        cooldowns[alert.id] = Date()
        
        let triggered = TriggeredAlert(
            alertId: alert.id,
            alertName: alert.name,
            metric: alert.metric,
            threshold: alert.threshold,
            actualValue: currentValue,
            timestamp: Date()
        )
        
        triggeredAlerts.insert(triggered, at: 0)
        
        // Keep only last 50
        if triggeredAlerts.count > 50 {
            triggeredAlerts = Array(triggeredAlerts.prefix(50))
        }
        
        // Send notification
        sendAlertNotification(alert, value: currentValue)
    }
    
    private func sendAlertNotification(_ alert: CustomAlert, value: Double) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(alert.name)"
        content.body = "\(alert.metric.displayName) is \(String(format: "%.1f", value))\(alert.metric.unit) (\(alert.condition.rawValue) \(String(format: "%.0f", alert.threshold)))"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "alert_\(alert.id)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - CRUD Operations
    
    func addAlert(_ alert: CustomAlert) {
        alerts.append(alert)
        saveAlerts()
    }
    
    func updateAlert(_ alert: CustomAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = alert
            saveAlerts()
        }
    }
    
    func deleteAlert(_ id: String) {
        alerts.removeAll { $0.id == id }
        saveAlerts()
    }
    
    func toggleAlert(_ id: String) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isEnabled.toggle()
            saveAlerts()
        }
    }
    
    // MARK: - Persistence
    
    private func saveAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: "custom_alerts")
        }
    }
    
    private func loadAlerts() {
        if let data = UserDefaults.standard.data(forKey: "custom_alerts"),
           let decoded = try? JSONDecoder().decode([CustomAlert].self, from: data) {
            alerts = decoded
        }
    }
}

// MARK: - Models

struct CustomAlert: Identifiable, Codable {
    let id: String
    var name: String
    var metric: AlertMetric
    var condition: AlertCondition
    var threshold: Double
    var duration: Int // seconds
    var isEnabled: Bool
}

enum AlertMetric: String, Codable, CaseIterable {
    case cpu, memory, temperature, diskSpace, gpu, networkIn, networkOut
    
    var displayName: String {
        switch self {
        case .cpu: return "CPU Usage"
        case .memory: return "Memory Usage"
        case .temperature: return "Temperature"
        case .diskSpace: return "Disk Space"
        case .gpu: return "GPU Usage"
        case .networkIn: return "Network In"
        case .networkOut: return "Network Out"
        }
    }
    
    var unit: String {
        switch self {
        case .cpu, .memory, .diskSpace, .gpu: return "%"
        case .temperature: return "°C"
        case .networkIn, .networkOut: return " MB/s"
        }
    }
    
    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .temperature: return "thermometer"
        case .diskSpace: return "internaldrive"
        case .gpu: return "gpu"
        case .networkIn: return "arrow.down.circle"
        case .networkOut: return "arrow.up.circle"
        }
    }
}

enum AlertCondition: String, Codable, CaseIterable {
    case above = "Above"
    case below = "Below"
    case equals = "Equals"
}

struct TriggeredAlert: Identifiable {
    let id = UUID()
    let alertId: String
    let alertName: String
    let metric: AlertMetric
    let threshold: Double
    let actualValue: Double
    let timestamp: Date
}
