import Foundation
import CloudKit

/// iCloudSync - Sync settings and history across devices
@MainActor
final class iCloudSync: ObservableObject {
    static let shared = iCloudSync()
    
    // MARK: - Published Properties
    @Published var isEnabled = false
    @Published var isSyncing = false
    @Published var lastSync: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    private let container: NSUbiquitousKeyValueStore
    private let keys = SyncKeys()
    
    private init() {
        container = NSUbiquitousKeyValueStore.default
        loadSyncState()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: container
        )
    }
    
    @objc private func ubiquitousStoreDidChange(_ notification: Notification) {
        Task { @MainActor in
            pullFromCloud()
        }
    }
    
    // MARK: - Enable/Disable
    
    func enable() {
        isEnabled = true
        container.synchronize()
        UserDefaults.standard.set(true, forKey: "icloud_sync_enabled")
        pushToCloud()
    }
    
    func disable() {
        isEnabled = false
        UserDefaults.standard.set(false, forKey: "icloud_sync_enabled")
    }
    
    // MARK: - Sync Operations
    
    func sync() async {
        guard isEnabled else { return }
        
        isSyncing = true
        syncStatus = .syncing
        
        // Push local changes
        pushToCloud()
        
        // Force sync
        container.synchronize()
        
        // Wait a bit then pull
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        pullFromCloud()
        
        lastSync = Date()
        isSyncing = false
        syncStatus = .synced
        
        UserDefaults.standard.set(lastSync?.timeIntervalSince1970, forKey: "last_icloud_sync")
    }
    
    // MARK: - Push to Cloud
    
    private func pushToCloud() {
        // Sync alert settings
        if let alertsData = UserDefaults.standard.data(forKey: "custom_alerts") {
            container.set(alertsData, forKey: keys.customAlerts)
        }
        
        // Sync thresholds
        let thresholds: [String: Any] = [
            "cpu_threshold": UserDefaults.standard.double(forKey: "cpuThreshold"),
            "memory_threshold": UserDefaults.standard.double(forKey: "memoryThreshold"),
            "temp_threshold": UserDefaults.standard.double(forKey: "tempThreshold")
        ]
        if let data = try? JSONSerialization.data(withJSONObject: thresholds) {
            container.set(data, forKey: keys.thresholds)
        }
        
        // Sync appearance settings
        container.set(UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en", forKey: keys.language)
        container.set(UserDefaults.standard.bool(forKey: "showNotifications"), forKey: keys.showNotifications)
        container.set(UserDefaults.standard.bool(forKey: "launchAtLogin"), forKey: keys.launchAtLogin)
        
        // Sync benchmark history
        if let benchmarkData = UserDefaults.standard.data(forKey: "benchmark_history") {
            container.set(benchmarkData, forKey: keys.benchmarkHistory)
        }
        
        container.synchronize()
    }
    
    // MARK: - Pull from Cloud
    
    private func pullFromCloud() {
        // Pull alerts
        if let alertsData = container.data(forKey: keys.customAlerts) {
            UserDefaults.standard.set(alertsData, forKey: "custom_alerts")
        }
        
        // Pull thresholds
        if let thresholdsData = container.data(forKey: keys.thresholds),
           let thresholds = try? JSONSerialization.jsonObject(with: thresholdsData) as? [String: Any] {
            if let cpu = thresholds["cpu_threshold"] as? Double {
                UserDefaults.standard.set(cpu, forKey: "cpuThreshold")
            }
            if let mem = thresholds["memory_threshold"] as? Double {
                UserDefaults.standard.set(mem, forKey: "memoryThreshold")
            }
            if let temp = thresholds["temp_threshold"] as? Double {
                UserDefaults.standard.set(temp, forKey: "tempThreshold")
            }
        }
        
        // Pull appearance
        if let lang = container.string(forKey: keys.language) {
            UserDefaults.standard.set(lang, forKey: "selectedLanguage")
        }
        UserDefaults.standard.set(container.bool(forKey: keys.showNotifications), forKey: "showNotifications")
        UserDefaults.standard.set(container.bool(forKey: keys.launchAtLogin), forKey: "launchAtLogin")
        
        // Pull benchmark history
        if let benchmarkData = container.data(forKey: keys.benchmarkHistory) {
            UserDefaults.standard.set(benchmarkData, forKey: "benchmark_history")
        }
    }
    
    // MARK: - Helpers
    
    private func loadSyncState() {
        isEnabled = UserDefaults.standard.bool(forKey: "icloud_sync_enabled")
        if let lastSyncTime = UserDefaults.standard.object(forKey: "last_icloud_sync") as? TimeInterval {
            lastSync = Date(timeIntervalSince1970: lastSyncTime)
        }
    }
}

// MARK: - Models

struct SyncKeys {
    let customAlerts = "xinsight_custom_alerts"
    let thresholds = "xinsight_thresholds"
    let language = "xinsight_language"
    let showNotifications = "xinsight_show_notifications"
    let launchAtLogin = "xinsight_launch_at_login"
    let benchmarkHistory = "xinsight_benchmark_history"
}

enum SyncStatus {
    case idle
    case syncing
    case synced
    case error(String)
    
    var description: String {
        switch self {
        case .idle: return "Not synced"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
