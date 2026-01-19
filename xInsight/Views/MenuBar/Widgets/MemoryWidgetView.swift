import SwiftUI

/// Memory Widget - Shows RAM usage, breakdown, and top processes
struct MemoryWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            contentSection
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "memorychip")
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("RAM")
                .font(.headline)
            Spacer()
            Button(action: {}) {
                Image(systemName: "gear")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var contentSection: some View {
        VStack(spacing: 16) {
            // Main gauge and breakdown
            HStack(spacing: 20) {
                gaugeView
                breakdownView
            }
            
            Divider()
            memoryBarView
            Divider()
            topProcessesView
        }
        .padding()
    }
    
    private var gaugeView: some View {
        VStack(spacing: 4) {
            MiniGaugeView(
                value: metricsCollector.currentMetrics.memoryUsagePercent,
                maxValue: 100,
                color: memoryColor
            )
            Text(L10n.string(.memoryUsage))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var breakdownView: some View {
        VStack(alignment: .leading, spacing: 6) {
            MemoryBreakdownRow(label: L10n.string(.memoryUsed), value: metricsCollector.currentMetrics.formattedMemoryUsed, color: .blue)
            MemoryBreakdownRow(label: L10n.string(.memoryWired), value: formatBytes(metricsCollector.currentMetrics.memoryWired), color: .orange)
            MemoryBreakdownRow(label: L10n.string(.memoryCompressed), value: formatBytes(metricsCollector.currentMetrics.memoryCompressed), color: .purple)
            MemoryBreakdownRow(label: L10n.string(.memoryFree), value: formattedFreeMemory, color: .green)
        }
    }
    
    private var memoryBarView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(L10n.string(.total)): \(metricsCollector.currentMetrics.formattedMemoryTotal)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            GeometryReader { geo in
                HStack(spacing: 1) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * usageRatio * 0.6)
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * 0.15)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * 0.1)
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                }
            }
            .frame(height: 12)
            .cornerRadius(3)
        }
    }
    
    private var topProcessesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string(.relatedProcesses))
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ForEach(topMemoryProcesses.prefix(5), id: \.name) { process in
                TopProcessRow(
                    name: process.name,
                    value: formatBytes(UInt64(process.memoryUsage)),
                    percentage: Double(process.memoryUsage) / Double(metricsCollector.currentMetrics.memoryTotal) * 100,
                    color: .purple
                )
            }
        }
    }
    
    private var usageRatio: Double {
        metricsCollector.currentMetrics.memoryUsagePercent / 100
    }
    
    private var memoryColor: Color {
        switch metricsCollector.currentMetrics.memoryPressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private var topMemoryProcesses: [ProcessInfo] {
        processMonitor.processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0f MB", mb)
    }
    
    private var formattedFreeMemory: String {
        let free = metricsCollector.currentMetrics.memoryTotal - metricsCollector.currentMetrics.memoryUsed
        return formatBytes(free)
    }
}

struct MemoryBreakdownRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced))
        }
    }
}
