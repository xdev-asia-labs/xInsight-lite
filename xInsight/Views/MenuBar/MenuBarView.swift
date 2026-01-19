import SwiftUI

/// Main Menu Bar popup view
struct MenuBarView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var insightEngine: InsightEngine
    
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Quick Stats
            quickStatsView
            
            Divider()
            
            // Current Insights (if any)
            if !insightEngine.currentInsights.isEmpty {
                insightsPreview
                Divider()
            }
            
            // Actions
            actionsView
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.string(.appName))
                    .font(.headline)
                
                Text(insightEngine.statusSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch insightEngine.currentStatus {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsView: some View {
        VStack(spacing: 10) {
            // CPU
            QuickStatRow(
                icon: "cpu",
                title: "CPU",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuUsage),
                trend: metricsCollector.cpuTrend,
                color: colorForPercent(metricsCollector.currentMetrics.cpuUsage)
            )
            
            // Memory
            QuickStatRow(
                icon: "memorychip",
                title: "Memory",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.memoryUsagePercent),
                trend: metricsCollector.memoryTrend,
                color: colorForPercent(metricsCollector.currentMetrics.memoryUsagePercent)
            )
            
            // GPU
            QuickStatRow(
                icon: "rectangle.3.group",
                title: "GPU",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.gpuUsage),
                trend: .stable,
                color: colorForPercent(metricsCollector.currentMetrics.gpuUsage)
            )
            
            // Disk I/O
            let diskIO = metricsCollector.currentMetrics.diskReadRate + metricsCollector.currentMetrics.diskWriteRate
            QuickStatRow(
                icon: "internaldrive",
                title: "Disk I/O",
                value: String(format: "%.0f MB/s", diskIO),
                trend: .stable,
                color: diskIO > 100 ? .orange : .green
            )
            
            // Network
            let networkTotal = Double(metricsCollector.currentMetrics.networkBytesIn + metricsCollector.currentMetrics.networkBytesOut) / 1_000_000
            QuickStatRow(
                icon: "network",
                title: "Network",
                value: String(format: "%.1f MB/s", networkTotal),
                trend: .stable,
                color: networkTotal > 50 ? .orange : .green
            )
            
            // Temperature
            QuickStatRow(
                icon: "thermometer",
                title: "Thermal",
                value: metricsCollector.currentMetrics.thermalState.rawValue,
                trend: .stable,
                color: thermalColor
            )
        }
        .padding()
    }
    
    private func colorForPercent(_ percent: Double) -> Color {
        if percent > 90 { return .red }
        if percent > 70 { return .orange }
        if percent > 50 { return .yellow }
        return .green
    }
    
    private var thermalColor: Color {
        switch metricsCollector.currentMetrics.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }
    
    // MARK: - Insights Preview
    
    private var insightsPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(.insights))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ForEach(insightEngine.currentInsights.prefix(2)) { insight in
                InsightPreviewRow(insight: insight)
            }
            
            if insightEngine.currentInsights.count > 2 {
                Text(String(format: L10n.string(.andMoreItems), insightEngine.currentInsights.count - 2))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Actions
    
    private var actionsView: some View {
        VStack(spacing: 4) {
            Button(action: openDashboard) {
                HStack {
                    Image(systemName: "square.grid.2x2")
                    Text(L10n.string(.menuBarOpen))
                    Spacer()
                    Text("⌘D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            
            Button(action: refreshMetrics) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text(L10n.string(.menuBarRefresh))
                    Spacer()
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            
            Divider()
            
            Button(action: openSettings) {
                HStack {
                    Image(systemName: "gear")
                    Text(L10n.string(.settings))
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            
            Button(action: quitApp) {
                HStack {
                    Image(systemName: "power")
                    Text(L10n.string(.menuBarQuit))
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func openDashboard() {
        // Activate the app and bring dashboard window to front
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Open dashboard window
        if let window = NSApp.windows.first(where: { $0.title.contains("Dashboard") }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no dashboard window, open a new one
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }
    }
    
    private func refreshMetrics() {
        isRefreshing = true
        Task {
            await metricsCollector.refresh()
            try? await Task.sleep(nanoseconds: 500_000_000)
            isRefreshing = false
        }
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Quick Stat Row

struct QuickStatRow: View {
    let icon: String
    let title: String
    let value: String
    let trend: TrendDirection
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.secondary)
            
            Text(title)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: trend.iconName)
                    .font(.caption2)
                    .foregroundColor(Color(trend.color))
                
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(color)
            }
        }
    }
}

// MARK: - Insight Preview Row

struct InsightPreviewRow: View {
    let insight: Insight
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: insight.severity.iconName)
                .foregroundColor(severityColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(insight.cause)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(MetricsCollector())
        .environmentObject(InsightEngine())
}
