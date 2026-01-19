import SwiftUI

/// Memory Detail Tab - Comprehensive memory monitoring with visual breakdown
struct MemoryDetailTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                mainStatsSection
                visualBreakdownSection
                memoryPressureSection
                swapSection
                historySection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            // Memory Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "memorychip.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Memory")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label("Unified LPDDR5", systemImage: "memorychip")
                    Label(metricsCollector.currentMetrics.formattedMemoryTotal, systemImage: "square.stack")
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(pressureColor)
                        .frame(width: 8, height: 8)
                    Text(metricsCollector.currentMetrics.memoryPressure.rawValue)
                        .font(.caption)
                        .foregroundColor(pressureColor)
                }
            }
            
            Spacer()
            
            // Big usage display
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", metricsCollector.currentMetrics.memoryUsagePercent))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: pressureGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("% Used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Main Stats
    
    private var mainStatsSection: some View {
        HStack(spacing: 16) {
            MemoryStatCard(
                title: "Used",
                value: metricsCollector.currentMetrics.formattedMemoryUsed,
                subtitle: String(format: "%.0f%% of total", metricsCollector.currentMetrics.memoryUsagePercent),
                icon: "arrow.up.circle.fill",
                color: .blue,
                progress: metricsCollector.currentMetrics.memoryUsagePercent / 100
            )
            
            MemoryStatCard(
                title: "Free",
                value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryTotal - metricsCollector.currentMetrics.memoryUsed), countStyle: .memory),
                subtitle: "Available for apps",
                icon: "arrow.down.circle.fill",
                color: .green,
                progress: 1 - (metricsCollector.currentMetrics.memoryUsagePercent / 100)
            )
            
            MemoryStatCard(
                title: "Wired",
                value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryWired), countStyle: .memory),
                subtitle: "System reserved",
                icon: "lock.fill",
                color: .red,
                progress: Double(metricsCollector.currentMetrics.memoryWired) / Double(metricsCollector.currentMetrics.memoryTotal)
            )
            
            MemoryStatCard(
                title: "Compressed",
                value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryCompressed), countStyle: .memory),
                subtitle: "Memory saved",
                icon: "arrow.down.right.and.arrow.up.left",
                color: .purple,
                progress: Double(metricsCollector.currentMetrics.memoryCompressed) / Double(metricsCollector.currentMetrics.memoryTotal)
            )
        }
    }
    
    // MARK: - Visual Breakdown
    
    private var visualBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Memory Breakdown", systemImage: "rectangle.split.3x1")
                    .font(.headline)
                Spacer()
            }
            
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Wired
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: max(0, geo.size.width * wiredPercent / 100))
                    
                    // App Memory
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: max(0, geo.size.width * appMemoryPercent / 100))
                    
                    // Compressed
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: max(0, geo.size.width * compressedPercent / 100))
                    
                    // Free
                    Rectangle()
                        .fill(Color.green.opacity(0.5))
                }
            }
            .frame(height: 32)
            .cornerRadius(8)
            
            // Legend with sizes
            HStack(spacing: 24) {
                MemoryLegendItem2(
                    color: .red,
                    title: "Wired",
                    value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryWired), countStyle: .memory),
                    percent: wiredPercent
                )
                
                MemoryLegendItem2(
                    color: .yellow,
                    title: "App Memory",
                    value: ByteCountFormatter.string(fromByteCount: Int64(appMemoryBytes), countStyle: .memory),
                    percent: appMemoryPercent
                )
                
                MemoryLegendItem2(
                    color: .blue,
                    title: "Compressed",
                    value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryCompressed), countStyle: .memory),
                    percent: compressedPercent
                )
                
                MemoryLegendItem2(
                    color: .green.opacity(0.5),
                    title: "Free",
                    value: ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.memoryTotal - metricsCollector.currentMetrics.memoryUsed), countStyle: .memory),
                    percent: freePercent
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Memory Pressure
    
    private var memoryPressureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Memory Pressure", systemImage: "gauge.with.dots.needle.50percent")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 32) {
                // Pressure gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: metricsCollector.currentMetrics.memoryUsagePercent / 100)
                        .stroke(
                            AngularGradient(
                                colors: [.green, .yellow, .orange, .red],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text(metricsCollector.currentMetrics.memoryPressure.rawValue)
                            .font(.headline)
                            .foregroundColor(pressureColor)
                        Text("Pressure")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Pressure indicators
                VStack(alignment: .leading, spacing: 12) {
                    PressureLevel(
                        title: "Normal",
                        description: "Enough memory available",
                        isActive: metricsCollector.currentMetrics.memoryPressure == .normal,
                        color: .green
                    )
                    
                    PressureLevel(
                        title: "Warning",
                        description: "Memory is getting tight",
                        isActive: metricsCollector.currentMetrics.memoryPressure == .warning,
                        color: .yellow
                    )
                    
                    PressureLevel(
                        title: "Critical",
                        description: "System may slow down",
                        isActive: metricsCollector.currentMetrics.memoryPressure == .critical,
                        color: .red
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Swap Section
    
    private var swapSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundColor(.orange)
                    Text("Swap Usage")
                        .font(.headline)
                }
                
                Text(ByteCountFormatter.string(fromByteCount: Int64(metricsCollector.currentMetrics.swapUsed), countStyle: .memory))
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Virtual memory on disk")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if metricsCollector.currentMetrics.swapUsed > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Consider closing unused apps")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.purple)
                    Text("Memory Efficiency")
                        .font(.headline)
                }
                
                let efficiency = (1 - Double(metricsCollector.currentMetrics.swapUsed) / Double(metricsCollector.currentMetrics.memoryTotal)) * 100
                
                Text(String(format: "%.0f%%", min(100, efficiency)))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(efficiency > 80 ? .green : .orange)
                
                Text("Lower swap = better performance")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory History (60s)")
                .font(.headline)
            
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    ForEach([25, 50, 75, 100], id: \.self) { level in
                        Path { path in
                            let y = geometry.size.height * (1 - CGFloat(level) / 100)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    
                    // Memory usage line
                    Path { path in
                        let history = Array(metricsCollector.metricsHistory.suffix(60))
                        guard history.count > 1 else { return }
                        
                        let step = geometry.size.width / CGFloat(history.count - 1)
                        
                        for (index, metrics) in history.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(metrics.memoryUsagePercent / 100))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(height: 100)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private var pressureColor: Color {
        switch metricsCollector.currentMetrics.memoryPressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
    
    private var pressureGradient: [Color] {
        switch metricsCollector.currentMetrics.memoryPressure {
        case .normal: return [.green, .teal]
        case .warning: return [.yellow, .orange]
        case .critical: return [.orange, .red]
        }
    }
    
    private var wiredPercent: Double {
        Double(metricsCollector.currentMetrics.memoryWired) / Double(metricsCollector.currentMetrics.memoryTotal) * 100
    }
    
    private var compressedPercent: Double {
        Double(metricsCollector.currentMetrics.memoryCompressed) / Double(metricsCollector.currentMetrics.memoryTotal) * 100
    }
    
    private var appMemoryBytes: UInt64 {
        let app = Int64(metricsCollector.currentMetrics.memoryUsed) - Int64(metricsCollector.currentMetrics.memoryWired) - Int64(metricsCollector.currentMetrics.memoryCompressed)
        return UInt64(max(0, app))
    }
    
    private var appMemoryPercent: Double {
        Double(appMemoryBytes) / Double(metricsCollector.currentMetrics.memoryTotal) * 100
    }
    
    private var freePercent: Double {
        100 - metricsCollector.currentMetrics.memoryUsagePercent
    }
}

// MARK: - Supporting Views

struct MemoryStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            ProgressView(value: min(progress, 1))
                .tint(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MemoryLegendItem2: View {
    let color: Color
    let title: String
    let value: String
    let percent: Double
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Text(value)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(String(format: "(%.0f%%)", percent))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct PressureLevel: View {
    let title: String
    let description: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? color : color.opacity(0.2))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: isActive ? 2 : 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? .primary : .secondary)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    MemoryDetailTab()
        .environmentObject(MetricsCollector())
        .frame(width: 900, height: 900)
}
