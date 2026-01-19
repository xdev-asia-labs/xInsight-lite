import Foundation
import UserNotifications
import AppKit

/// Service to send macOS notifications for system events
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized: Bool = false
    
    // Track previous ports for change detection
    private var previousPorts: Set<UInt16> = []
    
    private init() {
        // Ensure showNotifications defaults to true on first run
        if !UserDefaults.standard.bool(forKey: "showNotifications") {
            // Check if key exists - if not, set default to true
            if UserDefaults.standard.object(forKey: "showNotifications") == nil {
                UserDefaults.standard.set(true, forKey: "showNotifications")
            }
        }
        
        // Delay authorization to avoid crash in CLI mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.requestAuthorization()
        }
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        // Check if running as proper app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            print("NotificationService: Not running as app bundle, skipping authorization")
            return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
            }
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    // MARK: - Port Notifications
    
    /// Check for port changes and send notifications
    func checkPortChanges(currentPorts: [PortInfo]) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        
        let currentPortSet = Set(currentPorts.map { $0.port })
        
        // Find new ports (opened)
        let newPorts = currentPortSet.subtracting(previousPorts)
        for port in newPorts {
            if let portInfo = currentPorts.first(where: { $0.port == port }) {
                sendPortOpenedNotification(portInfo)
            }
        }
        
        // Find closed ports
        let closedPorts = previousPorts.subtracting(currentPortSet)
        for port in closedPorts {
            sendPortClosedNotification(port: port)
        }
        
        // Update previous state
        previousPorts = currentPortSet
    }
    
    private func sendPortOpenedNotification(_ portInfo: PortInfo) {
        let content = UNMutableNotificationContent()
        content.title = "🟢 Port Opened"
        content.body = "Port \(portInfo.displayName) opened by \(portInfo.processName)"
        content.sound = .default
        content.categoryIdentifier = "PORT_CHANGE"
        
        let request = UNNotificationRequest(
            identifier: "port-open-\(portInfo.port)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    private func sendPortClosedNotification(port: UInt16) {
        let content = UNMutableNotificationContent()
        content.title = "🔴 Port Closed"
        content.body = "Port \(port) is no longer listening"
        content.sound = .default
        content.categoryIdentifier = "PORT_CHANGE"
        
        let request = UNNotificationRequest(
            identifier: "port-close-\(port)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    /// Generic port notification - used by PortMonitoringService
    func sendPortNotification(title: String, body: String, port: UInt16) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "PORT_CHANGE"
        
        let request = UNNotificationRequest(
            identifier: "port-\(port)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
    
    // MARK: - System Notifications
    
    /// Send CPU high usage notification
    func sendCPUWarning(usage: Double) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ High CPU Usage"
        content.body = String(format: "CPU is at %.0f%% usage", usage)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "cpu-warning-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send memory pressure notification
    func sendMemoryWarning(usage: Double, pressure: String) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory Pressure"
        content.body = String(format: "Memory at %.0f%% (%@)", usage, pressure)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "memory-warning-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send temperature warning notification
    func sendTemperatureWarning(temp: Double) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 High Temperature"
        content.body = String(format: "CPU temperature is %.0f°C", temp)
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "temp-warning-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send update available notification
    func sendUpdateAvailable(version: String) {
        let content = UNMutableNotificationContent()
        content.title = "🆕 Update Available"
        content.body = "xInsight v\(version) is now available"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "update-available",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    /// Send test notification to verify settings
    func sendTestNotification() {
        // Check if we can use notifications (requires proper app bundle)
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.bundleIdentifier?.isEmpty == false else {
            // Fallback: show alert instead
            showTestAlert()
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "✅ xInsight Test"
        content.body = "Notifications are working correctly!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Test notification failed: \(error)")
                    self.showTestAlert(message: "Notifications failed: \(error.localizedDescription)")
                } else {
                    print("Test notification sent successfully")
                }
            }
        }
    }
    
    /// Show fallback alert when notifications aren't available
    private func showTestAlert(message: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "✅ Notification Test"
            alert.informativeText = message ?? "Notifications require the app to be built as a proper .app bundle.\n\nTo enable notifications:\n1. Open in Xcode\n2. Create a proper macOS app target\n3. Build and run from Xcode"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
