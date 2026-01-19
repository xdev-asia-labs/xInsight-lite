import Foundation
import Combine

/// Service that continuously monitors port changes and sends notifications
@MainActor
final class PortMonitoringService: ObservableObject {
    static let shared = PortMonitoringService()
    
    @Published var activePorts: [PortInfo] = []
    @Published var isMonitoring = false
    @Published var lastScanTime: Date?
    
    // Track previous ports for change detection
    private var previousPortSet: Set<UInt16> = []
    private var monitoringTask: Task<Void, Never>?
    
    // Settings
    @Published var monitoringInterval: TimeInterval = 30 // seconds
    @Published var notificationsEnabled = true
    
    private init() {
        // Load settings
        notificationsEnabled = UserDefaults.standard.bool(forKey: "portNotificationsEnabled")
        if notificationsEnabled == false {
            // First run - enable by default
            UserDefaults.standard.set(true, forKey: "portNotificationsEnabled")
            notificationsEnabled = true
        }
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        monitoringTask = Task {
            // Initial scan without notifications
            await performInitialScan()
            
            // Continuous monitoring loop
            while !Task.isCancelled && isMonitoring {
                try? await Task.sleep(for: .seconds(monitoringInterval))
                if !Task.isCancelled && isMonitoring {
                    await scanAndNotify()
                }
            }
        }
        
        print("🔌 Port monitoring started (interval: \(Int(monitoringInterval))s)")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        print("🔌 Port monitoring stopped")
    }
    
    // MARK: - Scanning
    
    private func performInitialScan() async {
        activePorts = await PortScanner.getListeningPorts()
        previousPortSet = Set(activePorts.map { $0.port })
        lastScanTime = Date()
        print("🔌 Initial port scan: \(activePorts.count) ports found")
    }
    
    func scanAndNotify() async {
        let currentPorts = await PortScanner.getListeningPorts()
        let currentPortSet = Set(currentPorts.map { $0.port })
        
        // Detect changes
        let newPorts = currentPortSet.subtracting(previousPortSet)
        let closedPorts = previousPortSet.subtracting(currentPortSet)
        
        // Send notifications for changes
        if notificationsEnabled {
            for port in newPorts {
                if let portInfo = currentPorts.first(where: { $0.port == port }) {
                    await sendPortStartedNotification(portInfo)
                }
            }
            
            for port in closedPorts {
                await sendPortStoppedNotification(port: port)
            }
        }
        
        // Update state
        activePorts = currentPorts
        previousPortSet = currentPortSet
        lastScanTime = Date()
        
        if !newPorts.isEmpty || !closedPorts.isEmpty {
            print("🔌 Port changes: +\(newPorts.count) -\(closedPorts.count)")
        }
    }
    
    /// Force immediate rescan
    func rescan() async {
        await scanAndNotify()
    }
    
    // MARK: - Notifications
    
    private func sendPortStartedNotification(_ portInfo: PortInfo) async {
        let desc = portInfo.commonDescription ?? "Unknown service"
        
        // System notification disabled for now
        // NotificationService.shared.sendPortNotification(
        //     title: "🟢 Port Started",
        //     body: "Port \(portInfo.port) (\(desc)) opened by \(portInfo.processName)",
        //     port: portInfo.port
        // )
        
        // In-app toast notification (always works)
        ToastManager.shared.showPortStarted(
            port: portInfo.port,
            process: portInfo.processName,
            description: desc
        )
    }
    
    private func sendPortStoppedNotification(port: UInt16) async {
        // System notification disabled for now
        // NotificationService.shared.sendPortNotification(
        //     title: "🔴 Port Stopped",
        //     body: "Port \(port) is no longer listening",
        //     port: port
        // )
        
        // In-app toast notification
        ToastManager.shared.showPortStopped(port: port)
    }
    
    // MARK: - Manual Kill
    
    func killPort(_ port: PortInfo, completion: @escaping (Bool) -> Void) {
        Task {
            let success = await killPortProcess(port)
            
            // All UI/notification updates must be on MainActor
            await MainActor.run {
                if success {
                    // System notification disabled for now
                    // NotificationService.shared.sendPortNotification(
                    //     title: "⚡ Port Killed",
                    //     body: "Killed \(port.processName) on port \(port.port)",
                    //     port: port.port
                    // )
                    
                    // In-app toast notification
                    ToastManager.shared.showPortKilled(port: port.port, process: port.processName)
                }
                completion(success)
            }
            
            // Rescan to update list (after completion callback)
            if success {
                await rescan()
            }
        }
    }
    
    private func killPortProcess(_ port: PortInfo) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/kill")
                task.arguments = ["-9", "\(port.pid)"]
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    continuation.resume(returning: task.terminationStatus == 0)
                } catch {
                    print("Error killing process: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
