import SwiftUI

@main
struct xInsightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var metricsCollector = MetricsCollector()
    @StateObject private var insightEngine = InsightEngine()
    @StateObject private var processMonitor = ProcessMonitor()
    
    init() {
        // StatusBarController will be set up in onAppear
    }
    
    var body: some Scene {
        // Dashboard Window - hiển thị mặc định khi chạy
        WindowGroup("xInsight Dashboard") {
            DashboardView()
                .environmentObject(metricsCollector)
                .environmentObject(insightEngine)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    // Load translations and saved language
                    L10n.loadTranslations()
                    L10n.loadSavedLanguage()
                    
                    // Setup status bar with coordinated popovers
                    StatusBarController.shared.setup(
                        metricsCollector: metricsCollector,
                        processMonitor: processMonitor,
                        insightEngine: insightEngine
                    )
                    
                    // Start port monitoring for notifications
                    PortMonitoringService.shared.startMonitoring()
                    
                    // Start background smart cleanup if enabled
                    _ = SmartCleanupService.shared
                    
                    // Đảm bảo app hiển thị trong Dock khi có window
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    
                    // Check for updates on launch
                    Task {
                        await VersionCheckService.shared.checkForUpdates()
                    }
                }
                .onReceive(metricsCollector.$currentMetrics) { metrics in
                    // Analyze metrics whenever they change
                    insightEngine.analyze(metrics: metrics, processes: processMonitor.processes)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenDashboard"))) { _ in
                    // Ensure window is visible when notification received
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
        }
        .defaultSize(width: 1000, height: 700)
        .handlesExternalEvents(matching: Set(arrayLiteral: "*")) // Accept all external events
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            // Quick Actions menu
            CommandMenu("Quick Actions") {
                Button("Cleanup Disk") {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "cleanup")
                }
                .keyboardShortcut("K", modifiers: [.command, .shift])
                
                Button("Scan Large Files") {
                    NotificationCenter.default.post(name: NSNotification.Name("ScanLargeFiles"), object: nil)
                }
                .keyboardShortcut("L", modifiers: [.command, .shift])
                
                Divider()
                
                Button("View Ports") {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "ports")
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
                
                Button("View Processes") {
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "processes")
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Refresh Metrics") {
                    Task {
                        await metricsCollector.refresh()
                    }
                }
                .keyboardShortcut("R", modifiers: [.command])
            }
        }
        
        // Settings
        Settings {
            SettingsView()
        }
    }
}
