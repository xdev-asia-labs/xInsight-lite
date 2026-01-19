import SwiftUI

/// xInsight Main Widget - Quick overview and actions
struct XInsightWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var processMonitor: ProcessMonitor
    @StateObject private var portMonitor = PortMonitoringService.shared
    @State private var isCleaningDisk = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "lightbulb.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("xInsight")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    // Quick Status
                    HStack(spacing: 16) {
                        QuickStatusItem(
                            icon: "cpu",
                            value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuUsage),
                            label: "CPU",
                            color: cpuColor
                        )
                        QuickStatusItem(
                            icon: "memorychip",
                            value: String(format: "%.0f%%", metricsCollector.currentMetrics.memoryUsagePercent),
                            label: "RAM",
                            color: memoryColor
                        )
                        QuickStatusItem(
                            icon: "thermometer.medium",
                            value: String(format: "%.0f°", metricsCollector.currentMetrics.cpuTemperature),
                            label: "Temp",
                            color: tempColor
                        )
                    }
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // System Health
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.string(.systemHealth))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(healthStatus)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(healthColor)
                        }
                        
                        HealthBar(value: healthScore, color: healthColor)
                    }
                    
                    Divider()
                    
                    // Quick Actions
                    VStack(spacing: 8) {
                        Text(L10n.string(.quickActions))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Row 1: Optimize & Clean Disk
                        HStack(spacing: 12) {
                            QuickActionButton(
                                icon: "bolt.circle.fill",
                                label: L10n.string(.optimizeNow),
                                color: .blue
                            ) {
                                StatusBarController.shared.openDashboard()
                            }
                            
                            QuickActionButton(
                                icon: "trash.circle.fill",
                                label: L10n.rawString("cleanup"),
                                color: isCleaningDisk ? .gray : .orange
                            ) {
                                openCleanupTab()
                            }
                        }
                        
                        // Row 2: Ports & Settings
                        HStack(spacing: 12) {
                            QuickActionButton(
                                icon: "network",
                                label: L10n.rawString("ports"),
                                color: .purple
                            ) {
                                openPortsTab()
                            }
                            
                            QuickActionButton(
                                icon: "gear",
                                label: L10n.string(.settings),
                                color: .gray
                            ) {
                                StatusBarController.shared.openSettings()
                            }
                        }
                    }
                    
                    // Active Ports Section
                    if !portMonitor.activePorts.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Active Ports (\(portMonitor.activePorts.count))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                if portMonitor.activePorts.count > 0 {
                                    Button("Kill All") {
                                        killAllPorts()
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            // Show top 5 ports
                            ForEach(portMonitor.activePorts.prefix(5)) { port in
                                PortQuickRow(port: port) {
                                    killPort(port)
                                }
                            }
                            
                            if portMonitor.activePorts.count > 5 {
                                Text("+ \(portMonitor.activePorts.count - 5) more...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Open Dashboard Button
                    Button(action: {
                        StatusBarController.shared.openDashboard()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.3.group.fill")
                            Text(L10n.string(.openDashboard))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .frame(width: 300, height: min(CGFloat(400 + portMonitor.activePorts.prefix(5).count * 30), 500))
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func openCleanupTab() {
        StatusBarController.shared.openDashboard()
        // Navigate to cleanup tab after opening dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "cleanup")
        }
    }
    
    private func openPortsTab() {
        StatusBarController.shared.openDashboard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "ports")
        }
    }
    
    private func killPort(_ port: PortInfo) {
        portMonitor.killPort(port) { _ in }
    }
    
    private func killAllPorts() {
        for port in portMonitor.activePorts {
            portMonitor.killPort(port) { _ in }
        }
    }
    
    private var cpuColor: Color {
        let usage = metricsCollector.currentMetrics.cpuUsage
        if usage > 80 { return .red }
        if usage > 50 { return .orange }
        return .green
    }
    
    private var memoryColor: Color {
        let usage = metricsCollector.currentMetrics.memoryUsagePercent
        if usage > 85 { return .red }
        if usage > 60 { return .orange }
        return .green
    }
    
    private var tempColor: Color {
        let temp = metricsCollector.currentMetrics.cpuTemperature
        if temp > 85 { return .red }
        if temp > 70 { return .orange }
        return .green
    }
    
    private var healthScore: Double {
        let cpuScore = max(0, 100 - metricsCollector.currentMetrics.cpuUsage)
        let memScore = max(0, 100 - metricsCollector.currentMetrics.memoryUsagePercent)
        let tempScore = max(0, 100 - (metricsCollector.currentMetrics.cpuTemperature - 40) * 1.5)
        return (cpuScore + memScore + tempScore) / 3
    }
    
    private var healthStatus: String {
        if healthScore > 80 { return L10n.string(.excellent) }
        if healthScore > 60 { return L10n.string(.good) }
        if healthScore > 40 { return L10n.string(.fair) }
        return L10n.string(.poor)
    }
    
    private var healthColor: Color {
        if healthScore > 80 { return .green }
        if healthScore > 60 { return .blue }
        if healthScore > 40 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct QuickStatusItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HealthBar: View {
    let value: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * CGFloat(value / 100))
            }
        }
        .frame(height: 8)
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("[QuickActionButton] ✅ Button '\(label)' clicked!")
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

// MARK: - Port Quick Row

struct PortQuickRow: View {
    let port: PortInfo
    let onKill: () -> Void
    
    var body: some View {
        HStack {
            // Port number
            Text(":\(port.port)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.purple)
            
            // Process name
            Text(port.processName)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
            
            // PID
            Text("PID: \(port.pid)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Kill button
            Button(action: {
                print("[PortQuickRow] Killing port \(port.port)...")
                onKill()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Circle())
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
