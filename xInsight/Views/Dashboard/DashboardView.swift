import SwiftUI
import ServiceManagement

/// Main Dashboard View with tabs
struct DashboardView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var insightEngine: InsightEngine
    
    @State private var selectedTab: DashboardTab = .overview
    @State private var showCommandBar: Bool = false
    
    var body: some View {
        ZStack {
            NavigationSplitView {
                // Sidebar
                sidebarView
            } detail: {
                // Main content
                tabContent
                    .id(selectedTab)
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 900, minHeight: 700)
            
            // Command Bar Overlay
            CommandBar(
                isPresented: $showCommandBar,
                selectedTab: $selectedTab
            )
            
            // In-app Toast Notification Banner
            ToastBannerView()
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToTab"))) { notification in
            if let tabName = notification.object as? String {
                switch tabName {
                case "cleanup": selectedTab = .cleanup
                case "ports": selectedTab = .ports
                case "processes": selectedTab = .processes
                case "overview": selectedTab = .overview
                case "insights": selectedTab = .insights
                case "settings": selectedTab = .settings
                default: break
                }
            }
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ⌘K to open command bar
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "k" {
                showCommandBar.toggle()
                return nil // Consume event
            }
            
            // ESC to close command bar
            if event.keyCode == 53 && showCommandBar {
                showCommandBar = false
                return nil
            }
            
            return event
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            List(selection: $selectedTab) {
                Section(L10n.string(.monitor)) {
                    sidebarItem(.overview, icon: "square.grid.2x2", title: L10n.string(.overview))
                    sidebarItem(.processes, icon: "list.bullet.rectangle", title: L10n.string(.processes))
                    sidebarItem(.processTimeline, icon: "clock.arrow.circlepath", title: "Timeline")
                    sidebarItem(.ports, icon: "network", title: L10n.string(.ports))
                }
                
                Section(L10n.string(.hardware)) {
                    sidebarItem(.hardwareInfo, icon: "info.circle", title: "Hardware Info")
                    sidebarItem(.cpuDetail, icon: "cpu", title: L10n.string(.cpuDetail))
                    sidebarItem(.gpuDetail, icon: "rectangle.3.group", title: L10n.string(.gpuDetail))
                    sidebarItem(.memoryDetail, icon: "memorychip", title: L10n.string(.memoryDetail))
                    sidebarItem(.diskDetail, icon: "internaldrive", title: L10n.string(.diskDetail))
                    sidebarItem(.networkTraffic, icon: "network", title: L10n.string(.networkTraffic))
                    sidebarItem(.batteryHealth, icon: "battery.100", title: L10n.string(.batteryHealth))
                }
                
                Section(L10n.string(.analysis)) {
                    sidebarItem(.trends, icon: "chart.line.uptrend.xyaxis", title: L10n.string(.trends))
                    sidebarItem(.comparison, icon: "arrow.left.arrow.right", title: "Comparison")
                    sidebarItem(.benchmark, icon: "gauge.with.dots.needle.33percent", title: "Benchmark")
                    sidebarItem(.insights, icon: "lightbulb.max", title: L10n.string(.insights), badge: insightEngine.currentInsights.count)
                    sidebarItem(.security, icon: "shield.checkered", title: L10n.string(.security))
                }
                
                Section(L10n.string(.tools)) {
                    sidebarItem(.cleanup, icon: "trash.circle", title: L10n.string(.cleanup))
                    sidebarItem(.uninstaller, icon: "app.badge.checkmark", title: L10n.string(.uninstaller))
                    sidebarItem(.startupManager, icon: "arrow.right.circle", title: L10n.string(.startupManager))
                    sidebarItem(.settings, icon: "gear", title: L10n.string(.settings))
                }
                
                Section("Developer") {
                    sidebarItem(.docker, icon: "shippingbox.fill", title: "Docker")
                    sidebarItem(.homebrew, icon: "mug.fill", title: "Homebrew")
                    sidebarItem(.thermal, icon: "thermometer.variable.and.figure", title: "xThermal")
                }
            }
            .listStyle(.sidebar)
        }
        .frame(minWidth: 200)
    }
    
    private func sidebarItem(_ tab: DashboardTab, icon: String, title: String, badge: Int = 0) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if badge > 0 {
                Text(String(format: L10n.string(.numberOnly), badge))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .tag(tab)
        .contentShape(Rectangle())
    }
    
    // MARK: - Tab Content
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTab(navigateTo: $selectedTab)
        case .processes:
            ProcessesTab()
        case .ports:
            PortsTab()
        case .cpuDetail:
            CPUDetailTab()
        case .hardwareInfo:
            HardwareInfoTab()
        case .gpuDetail:
            GPUDetailTab()
        case .memoryDetail:
            MemoryDetailTab()
        case .diskDetail:
            DiskDetailTab()
        case .networkTraffic:
            NetworkTrafficTab()
        case .insights:
            InsightsTab()
        case .trends:
            TrendsTab()
        case .aiDashboard:
            InsightsTab()  // Lite build - AI features disabled
        case .cleanup:
            CleanupTab()
        case .uninstaller:
            UninstallerTab()
        case .batteryHealth:
            BatteryHealthTab()
        case .startupManager:
            StartupManagerTab()
        case .security:
            SecurityTab()
        case .comparison:
            ComparisonTab()
        case .benchmark:
            BenchmarkTab()
        case .processTimeline:
            ProcessTimelineTab()
        case .docker:
            DockerTab()
        case .homebrew:
            HomebrewTab()
        case .thermal:
            ThermalTab()
        case .settings:
            SettingsTabView()
        }
    }
}

// MARK: - Dashboard Tab Enum

enum DashboardTab: String, CaseIterable, Identifiable, Hashable {
    case overview
    case processes
    case processTimeline
    case ports
    case cpuDetail
    case hardwareInfo
    case gpuDetail
    case memoryDetail
    case diskDetail
    case networkTraffic
    case batteryHealth
    case aiDashboard
    case trends
    case comparison
    case benchmark
    case insights
    case security
    case cleanup
    case uninstaller
    case startupManager
    case docker
    case homebrew
    case thermal
    case settings
    
    var id: String { rawValue }
}

// MARK: - Settings Tab (Embedded in Dashboard)

struct SettingsTabView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("app_language") private var appLanguage: String = "system"
    @AppStorage("app_theme") private var appTheme: String = "system"
    @AppStorage("cpuThreshold") private var cpuThreshold: Double = 80
    @AppStorage("memoryThreshold") private var memoryThreshold: Double = 75
    @AppStorage("fanMode") private var fanMode: String = "auto"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Appearance Section (Theme)
                settingsCard(title: "Appearance / Giao diện", icon: "paintbrush") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose app theme")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Theme", selection: $appTheme) {
                            Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                            Label("Light", systemImage: "sun.max.fill").tag("light")
                            Label("Dark", systemImage: "moon.fill").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appTheme) { _, newValue in
                            applyTheme(newValue)
                        }
                    }
                }
                
                // Language Section
                settingsCard(title: "Language / Ngôn ngữ", icon: "globe") {
                    Picker("Language", selection: $appLanguage) {
                        ForEach(L10n.Language.allCases, id: \.rawValue) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: appLanguage) { _, newValue in
                        if let lang = L10n.Language(rawValue: newValue) {
                            L10n.currentLanguage = lang
                        }
                    }
                }
                
                // Menu Bar Widgets Section
                settingsCard(title: "Menu Bar Widgets", icon: "menubar.rectangle") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.string(.selectWidgets))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Horizontal grid of widget toggles
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            WidgetIconToggle(type: .xinsight, icon: "brain.head.profile", title: "xInsight", color: .purple)
                            WidgetIconToggle(type: .cpu, icon: "cpu", title: "CPU", color: .blue)
                            WidgetIconToggle(type: .gpu, icon: "rectangle.3.group", title: "GPU", color: .green)
                            WidgetIconToggle(type: .ram, icon: "memorychip", title: "RAM", color: .orange)
                            WidgetIconToggle(type: .disk, icon: "internaldrive", title: "Disk", color: .cyan)
                            WidgetIconToggle(type: .network, icon: "network", title: "Network", color: .indigo)
                            WidgetIconToggle(type: .battery, icon: "battery.100", title: "Battery", color: .green)
                            WidgetIconToggle(type: .port, icon: "cable.connector", title: "Ports", color: .pink)
                            WidgetIconToggle(type: .cleanup, icon: "trash.circle", title: "Cleanup", color: .red)
                        }
                    }
                }
                
                // Desktop Widgets Section - temporarily disabled
                // settingsCard(title: "Desktop Widgets", icon: "desktopcomputer") {
                //     VStack(alignment: .leading, spacing: 12) {
                //         Text("Show floating widgets on your desktop")
                //             .font(.caption)
                //             .foregroundColor(.secondary)
                //         
                //         Toggle("Enable Desktop Widgets", isOn: Binding(
                //             get: { DesktopWidgetController.shared.isEnabled },
                //             set: { _ in DesktopWidgetController.shared.toggleDesktopWidgets() }
                //         ))
                //         
                //         if DesktopWidgetController.shared.isEnabled {
                //             Text("Drag widgets to reposition them")
                //                 .font(.caption2)
                //                 .foregroundColor(.secondary)
                //         }
                //     }
                // }
                
                // Notifications Section - disabled for now
                // settingsCard(title: "Notifications", icon: "bell.badge") {
                //     VStack(alignment: .leading, spacing: 16) {
                //         Toggle(L10n.string(.enableNotifications), isOn: $showNotifications)
                //         ...
                //     }
                // }
                
                // General Section
                settingsCard(title: "General", icon: "gear") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Launch at Login
                        Toggle(L10n.string(.launchAtLogin), isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                setLaunchAtLogin(enabled: newValue)
                            }
                        
                        Divider()
                        
                        HStack {
                            Text(L10n.string(.refreshInterval))
                            Spacer()
                            Picker("", selection: $refreshInterval) {
                                Text(L10n.string(.seconds1)).tag(1.0)
                                Text(L10n.string(.seconds2)).tag(2.0)
                                Text(L10n.string(.seconds5)).tag(5.0)
                                Text(L10n.string(.seconds10)).tag(10.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                    }
                }
                
                // Thresholds Section
                settingsCard(title: "Warning Thresholds", icon: "slider.horizontal.3") {
                    VStack(spacing: 16) {
                        thresholdSlider(title: "CPU", value: $cpuThreshold, unit: "%")
                        thresholdSlider(title: "Memory", value: $memoryThreshold, unit: "%")
                    }
                }
                
                // About & Updates Section
                settingsCard(title: "About & Updates", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 16) {
                        // App Info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string(.appName))
                                    .font(.headline)
                                Text(L10n.string(.appDescription))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "cpu")
                                .font(.largeTitle)
                                .foregroundColor(.accentColor)
                        }
                        
                        Divider()
                        
                        // Version Info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.string(.currentVersion))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: L10n.string(.versionFormat), VersionCheckService.shared.currentVersion))
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                            }
                            
                            Spacer()
                            
                            if VersionCheckService.shared.hasUpdate {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(L10n.string(.latestVersion))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: L10n.string(.versionFormat), VersionCheckService.shared.latestVersion ?? "?"))
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // Update Status & Buttons
                        HStack {
                            if VersionCheckService.shared.isChecking {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text(L10n.string(.checkingUpdates))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if VersionCheckService.shared.hasUpdate {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .foregroundColor(.green)
                                    Text(L10n.string(.updateAvailable))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else if VersionCheckService.shared.latestVersion != nil {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(L10n.string(.upToDate))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if VersionCheckService.shared.hasUpdate {
                                Button(action: {
                                    VersionCheckService.shared.openDownloadPage()
                                }) {
                                    Label(L10n.string(.download), systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            
                            Button(action: {
                                Task {
                                    await VersionCheckService.shared.checkForUpdates()
                                }
                            }) {
                                Label(L10n.string(.checkForUpdates), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(VersionCheckService.shared.isChecking)
                        }
                        
                        Divider()
                        
                        // Copyright
                        Text(L10n.string(.copyright))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            L10n.loadSavedLanguage()
            appLanguage = L10n.currentLanguage.rawValue
            applyTheme(appTheme)
        }
    }
    
    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func thresholdSlider(title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: L10n.string(.valueWithUnit), Int(value.wrappedValue), unit))
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            Slider(value: value, in: 50...100, step: 5)
        }
    }
    
    private func setLaunchAtLogin(enabled: Bool) {
        // Use SMAppService for macOS 13+ Launch at Login
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        }
    }
    
    private func applyTheme(_ theme: String) {
        switch theme {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil  // Follow system
        }
    }
}

/// Toggle row for enabling/disabling menu bar widgets
struct WidgetToggleRow: View {
    let type: StatusBarController.WidgetType
    let icon: String
    let title: String
    
    @State private var isEnabled: Bool = true
    
    var body: some View {
        Toggle(isOn: $isEnabled) {
            Label(title, systemImage: icon)
        }
        .onAppear {
            isEnabled = StatusBarController.shared.isWidgetEnabled(type)
        }
        .onChange(of: isEnabled) { _, newValue in
            Task { @MainActor in
                StatusBarController.shared.toggleWidget(type, enabled: newValue)
            }
        }
    }
}

// Icon-based toggle for horizontal grid display
struct WidgetIconToggle: View {
    let type: StatusBarController.WidgetType
    let icon: String
    let title: String
    let color: Color
    
    @State private var isEnabled: Bool = true
    
    var body: some View {
        Button(action: {
            isEnabled.toggle()
            Task { @MainActor in
                StatusBarController.shared.toggleWidget(type, enabled: isEnabled)
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isEnabled ? color : .gray)
                }
                .overlay(
                    Circle()
                        .stroke(isEnabled ? color : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 44, height: 44)
                )
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            isEnabled = StatusBarController.shared.isWidgetEnabled(type)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(MetricsCollector())
        .environmentObject(InsightEngine())
}

