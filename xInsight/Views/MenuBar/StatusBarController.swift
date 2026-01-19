import SwiftUI
import AppKit

/// Controller that manages multiple status bar items with coordinated popovers
@MainActor
class StatusBarController: NSObject, ObservableObject {
    static let shared = StatusBarController()
    
    private var statusItems: [WidgetType: NSStatusItem] = [:]
    private var popovers: [WidgetType: NSPopover] = [:]
    private var currentOpenWidget: WidgetType?
    
    // Widget visibility settings
    @AppStorage("widget_cpu_enabled") var cpuEnabled = true
    @AppStorage("widget_gpu_enabled") var gpuEnabled = true
    @AppStorage("widget_ram_enabled") var ramEnabled = true
    @AppStorage("widget_disk_enabled") var diskEnabled = true
    @AppStorage("widget_network_enabled") var networkEnabled = true
    @AppStorage("widget_battery_enabled") var batteryEnabled = true
    @AppStorage("widget_port_enabled") var portEnabled = true
    @AppStorage("widget_cleanup_enabled") var cleanupEnabled = true
    @AppStorage("widget_xinsight_enabled") var xinsightEnabled = true
    
    // Reference to insight engine for status coloring
    var insightEngine: InsightEngine?
    
    // Environment objects to pass to views
    var metricsCollector: MetricsCollector?
    var processMonitor: ProcessMonitor?
    
    enum WidgetType: String, CaseIterable {
        case xinsight, cpu, gpu, ram, disk, network, battery, port, cleanup
        
        var icon: String {
            switch self {
            case .xinsight: return "brain.head.profile" // Nice AI brain icon
            case .cpu: return "cpu"
            case .gpu: return "rectangle.3.group"
            case .ram: return "memorychip"
            case .disk: return "internaldrive"
            case .network: return "network"
            case .battery: return "battery.100"
            case .port: return "cable.connector"
            case .cleanup: return "trash.circle.fill"
            }
        }
    }
    
    private var isSetup = false
    
    private override init() {
        super.init()
    }
    
    func setup(metricsCollector: MetricsCollector, processMonitor: ProcessMonitor, insightEngine: InsightEngine? = nil) {
        // Guard against duplicate setup
        guard !isSetup else {
            print("[StatusBarController] ⚠️ setup() called but already initialized")
            return
        }
        isSetup = true
        
        print("[StatusBarController] 🚀 Starting setup...")
        print("[StatusBarController] MetricsCollector: \(metricsCollector)")
        print("[StatusBarController] ProcessMonitor: \(processMonitor)")
        
        self.metricsCollector = metricsCollector
        self.processMonitor = processMonitor
        self.insightEngine = insightEngine
        
        // Create status items for enabled widgets only
        var enabledCount = 0
        for widgetType in WidgetType.allCases {
            let enabled = isWidgetEnabled(widgetType)
            print("[StatusBarController] Widget \(widgetType.rawValue): enabled=\(enabled)")
            if enabled {
                createStatusItem(for: widgetType)
                enabledCount += 1
            }
        }
        print("[StatusBarController] ✅ Created \(enabledCount) status items")
        
        // Start updating labels
        startLabelUpdates()
        print("[StatusBarController] ✅ Setup complete!")
    }
    
    func isWidgetEnabled(_ type: WidgetType) -> Bool {
        switch type {
        case .xinsight: return xinsightEnabled
        case .cpu: return cpuEnabled
        case .gpu: return gpuEnabled
        case .ram: return ramEnabled
        case .disk: return diskEnabled
        case .network: return networkEnabled
        case .battery: return batteryEnabled
        case .port: return portEnabled
        case .cleanup: return cleanupEnabled
        }
    }
    
    func toggleWidget(_ type: WidgetType, enabled: Bool) {
        switch type {
        case .xinsight: xinsightEnabled = enabled
        case .cpu: cpuEnabled = enabled
        case .gpu: gpuEnabled = enabled
        case .ram: ramEnabled = enabled
        case .disk: diskEnabled = enabled
        case .network: networkEnabled = enabled
        case .battery: batteryEnabled = enabled
        case .port: portEnabled = enabled
        case .cleanup: cleanupEnabled = enabled
        }
        
        if enabled {
            if statusItems[type] == nil {
                createStatusItem(for: type)
            }
        } else {
            if let item = statusItems[type] {
                NSStatusBar.system.removeStatusItem(item)
                statusItems.removeValue(forKey: type)
                popovers.removeValue(forKey: type)
            }
        }
    }
    
    func openSettings() {
        print("[StatusBarController] 🔧 Opening Settings...")
        closeAllPopovers()
        
        // For SPM executable, SwiftUI Settings scene doesn't work reliably
        // Instead, open Dashboard and navigate to Settings tab
        openDashboard()
        
        // Wait for dashboard to appear, then navigate to settings tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "settings")
            print("[StatusBarController] ✅ Navigated to Settings tab")
        }
    }
    
    func openDashboard() {
        print("[StatusBarController] 📊 Opening Dashboard...")
        closeAllPopovers()
        
        // Activate the app
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // First, check all windows including hidden/miniaturized ones
        for window in NSApp.windows {
            let title = window.title
            if title.contains("Dashboard") || title.contains("xInsight") {
                // Found a dashboard window - show it
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
                print("[StatusBarController] ✅ Found and activated window: \(title)")
                return
            }
        }
        
        // No dashboard window found - post notification to AppDelegate to create new one
        print("[StatusBarController] ⚠️ No dashboard window found, requesting new via notification...")
        NotificationCenter.default.post(name: NSNotification.Name("OpenDashboard"), object: nil)
    }
    
    private func createStatusItem(for type: WidgetType) {
        print("[StatusBarController] Creating status item for: \(type.rawValue)")
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItems[type] = statusItem
        
        // Create popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: widgetView(for: type))
        popovers[type] = popover
        
        // Configure button
        if let button = statusItem.button {
            // Don't set button.image - we use attributedTitle with icon instead
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.identifier = NSUserInterfaceItemIdentifier(type.rawValue)
            updateLabel(for: type, button: button)
            print("[StatusBarController] ✅ Button configured for: \(type.rawValue)")
        } else {
            print("[StatusBarController] ❌ Failed to get button for: \(type.rawValue)")
        }
    }
    
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let identifier = sender.identifier?.rawValue,
              let widgetType = WidgetType(rawValue: identifier) else { return }
        
        // Close any currently open popover
        if let currentOpen = currentOpenWidget, currentOpen != widgetType {
            popovers[currentOpen]?.performClose(nil)
        }
        
        // Toggle the clicked popover
        guard let popover = popovers[widgetType] else { return }
        
        if popover.isShown {
            popover.performClose(nil)
            currentOpenWidget = nil
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            currentOpenWidget = widgetType
        }
    }
    
    private func widgetView(for type: WidgetType) -> AnyView {
        guard let metrics = metricsCollector, let processes = processMonitor else {
            return AnyView(Text("Loading..."))
        }
        
        switch type {
        case .xinsight:
            return AnyView(XInsightWidgetView()
                .environmentObject(metrics)
                .environmentObject(processes))
        case .cpu:
            return AnyView(CPUWidgetView()
                .environmentObject(metrics)
                .environmentObject(processes))
        case .gpu:
            return AnyView(GPUWidgetView()
                .environmentObject(metrics))
        case .ram:
            return AnyView(MemoryWidgetView()
                .environmentObject(metrics)
                .environmentObject(processes))
        case .disk:
            return AnyView(DiskWidgetView()
                .environmentObject(metrics))
        case .network:
            return AnyView(NetworkWidgetView()
                .environmentObject(metrics)
                .environmentObject(processes))
        case .battery:
            return AnyView(BatteryWidgetView()
                .environmentObject(processes))
        case .port:
            return AnyView(PortWidgetView())
        case .cleanup:
            return AnyView(CleanupWidgetView())
        }
    }
    
    private func startLabelUpdates() {
        // Update labels every 2 seconds - dispatch to MainActor to avoid concurrency issues
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                strongSelf.updateAllLabels()
            }
        }
    }
    
    private func updateAllLabels() {
        guard let metrics = metricsCollector?.currentMetrics else { return }
        
        for (type, statusItem) in statusItems {
            guard let button = statusItem.button else { continue }
            updateLabel(for: type, button: button, metrics: metrics)
        }
    }
    
    private func updateLabel(for type: WidgetType, button: NSStatusBarButton, metrics: SystemMetrics? = nil) {
        let m = metrics ?? metricsCollector?.currentMetrics
        
        let labelText: String
        switch type {
        case .xinsight:
            labelText = "" // Just icon for xInsight
        case .cpu:
            labelText = String(format: "%.0f%%", m?.cpuUsage ?? 0)
        case .gpu:
            labelText = String(format: "%.0f%%", m?.gpuUsage ?? 0)
        case .ram:
            labelText = String(format: "%.0f%%", m?.memoryUsagePercent ?? 0)
        case .disk:
            labelText = "" // Just icon for disk
        case .network:
            let kb = Double((m?.networkBytesIn ?? 0) + (m?.networkBytesOut ?? 0)) / 1000
            if kb > 1000 {
                labelText = String(format: "%.1fM", kb / 1000)
            } else {
                labelText = String(format: "%.0fK", kb)
            }
        case .battery:
            labelText = String(format: "%.0f%%", BatteryService.shared.batteryInfo.chargePercent)
        case .port:
            labelText = "" // Just icon for port
        case .cleanup:
            labelText = "" // Just icon for cleanup
        }
        
        // Create attributed string with icon and label
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: type.icon, accessibilityDescription: type.rawValue)
        
        let attrString = NSMutableAttributedString()
        attrString.append(NSAttributedString(attachment: attachment))
        
        if !labelText.isEmpty {
            attrString.append(NSAttributedString(string: " " + labelText))
        }
        
        button.attributedTitle = attrString
    }
    
    func closeAllPopovers() {
        for popover in popovers.values {
            popover.performClose(nil)
        }
        currentOpenWidget = nil
    }
}
