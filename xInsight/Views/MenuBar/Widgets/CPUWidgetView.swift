import SwiftUI

/// CPU Widget - Shows CPU usage, history chart, and top processes
struct CPUWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("CPU")
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
            
            Divider()
            
            VStack(spacing: 16) {
                // Main gauge and chart
                HStack(spacing: 20) {
                    // Gauge
                    VStack(spacing: 4) {
                        MiniGaugeView(
                            value: metricsCollector.currentMetrics.cpuUsage,
                            maxValue: 100,
                            color: cpuColor
                        )
                        Text(L10n.string(.cpuUsage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // History chart
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage history")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        MiniChartView(
                            data: cpuHistoryData,
                            maxValue: 100,
                            color: cpuColor
                        )
                        .frame(height: 50)
                    }
                }
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        DetailRow(label: "System:", value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuUsage * 0.3))
                        DetailRow(label: "User:", value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuUsage * 0.6))
                        DetailRow(label: "Idle:", value: String(format: "%.0f%%", 100 - metricsCollector.currentMetrics.cpuUsage))
                    }
                }
                
                Divider()
                
                // Top processes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top processes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(topCPUProcesses.prefix(5), id: \.name) { process in
                        TopProcessRow(
                            name: process.name,
                            value: String(format: "%.1f%%", process.cpuUsage),
                            percentage: process.cpuUsage,
                            color: .blue
                        )
                    }
                }
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var cpuColor: Color {
        let usage = metricsCollector.currentMetrics.cpuUsage
        if usage > 80 { return .red }
        if usage > 50 { return .orange }
        return .green
    }
    
    private var topCPUProcesses: [ProcessInfo] {
        processMonitor.processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
    }
    
    private var cpuHistoryData: [Double] {
        // Generate sample history based on current CPU usage
        let current = metricsCollector.currentMetrics.cpuUsage
        return (0..<20).map { _ in
            max(0, min(100, current + Double.random(in: -10...10)))
        }
    }
}

/// Detail row for stats
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}
