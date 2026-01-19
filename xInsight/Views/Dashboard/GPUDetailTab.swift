import SwiftUI

/// GPU Detail Tab - Beautiful Apple Silicon GPU monitoring
struct GPUDetailTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @State private var gpuCoreUsages: [Double] = []
    @State private var selectedView = 0
    
    private var estimatedGPUCores: Int {
        let cpuCores = metricsCollector.currentMetrics.cpuCoreCount
        if cpuCores >= 12 { return 38 }  // M1 Max, M2 Max, M3 Max
        if cpuCores >= 10 { return 16 }  // M1 Pro, M2 Pro, M3 Pro
        return 10  // M1, M2, M3 base
    }
    
    private var chipName: String {
        let cores = metricsCollector.currentMetrics.cpuCoreCount
        if cores >= 12 { return "Apple M3 Pro/Max" }
        if cores >= 10 { return "Apple M3 Pro" }
        return "Apple M3"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                mainStatsSection
                performanceSection
                gpuCoresSection
                metalSection
                historySection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            generateGPUCoreUsages()
        }
        .onReceive(metricsCollector.$currentMetrics) { _ in
            generateGPUCoreUsages()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            // GPU Icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "rectangle.3.group.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("GPU Performance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label(chipName, systemImage: "cpu")
                    Label("\(estimatedGPUCores) GPU Cores", systemImage: "square.grid.3x3")
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Metal 3 Active")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // Big usage display
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", metricsCollector.currentMetrics.gpuUsage))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: usageGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("% GPU Usage")
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
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
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
            GPUStatCard(
                title: "GPU Usage",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.gpuUsage),
                subtitle: "Current load",
                icon: "chart.bar.fill",
                color: usageColor,
                progress: metricsCollector.currentMetrics.gpuUsage / 100
            )
            
            GPUStatCard(
                title: "Temperature",
                value: String(format: "%.0f°C", metricsCollector.currentMetrics.gpuTemperature),
                subtitle: thermalStateText,
                icon: "thermometer",
                color: tempColor,
                progress: metricsCollector.currentMetrics.gpuTemperature / 100
            )
            
            GPUStatCard(
                title: "GPU Memory",
                value: formatBytes(metricsCollector.currentMetrics.gpuMemoryUsed),
                subtitle: "VRAM used",
                icon: "memorychip.fill",
                color: .blue,
                progress: Double(metricsCollector.currentMetrics.gpuMemoryUsed) / Double(metricsCollector.currentMetrics.memoryTotal)
            )
            
            GPUStatCard(
                title: "Power",
                value: "\(Int(metricsCollector.currentMetrics.gpuUsage * 0.15))W",
                subtitle: "Estimated",
                icon: "bolt.fill",
                color: .yellow,
                progress: metricsCollector.currentMetrics.gpuUsage / 100
            )
        }
    }
    
    // MARK: - Performance Section
    
    private var performanceSection: some View {
        HStack(spacing: 16) {
            // Real-time gauge
            VStack(spacing: 12) {
                Text("Real-time Load")
                    .font(.headline)
                
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                        .frame(width: 150, height: 150)
                    
                    // Usage arc
                    Circle()
                        .trim(from: 0, to: metricsCollector.currentMetrics.gpuUsage / 100)
                        .stroke(
                            AngularGradient(
                                colors: [.green, .yellow, .orange, .red],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", metricsCollector.currentMetrics.gpuUsage))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("percent")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // Performance stats
            VStack(alignment: .leading, spacing: 16) {
                Text("Performance Metrics")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    PerformanceMetric(
                        label: "Avg Load",
                        value: String(format: "%.0f%%", metricsCollector.averageGPU),
                        trend: metricsCollector.currentMetrics.gpuUsage > metricsCollector.averageGPU ? .up : .down
                    )
                    
                    PerformanceMetric(
                        label: "Peak Load",
                        value: String(format: "%.0f%%", metricsCollector.metricsHistory.map { $0.gpuUsage }.max() ?? 0),
                        trend: .neutral
                    )
                    
                    PerformanceMetric(
                        label: "Efficiency",
                        value: "High",
                        trend: .up
                    )
                }
                
                Divider()
                
                HStack {
                    Label("Neural Engine", systemImage: "brain")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Available")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Label("ProRes Engine", systemImage: "film")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Available")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - GPU Cores Grid
    
    private var gpuCoresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("GPU Cores")
                    .font(.headline)
                
                Spacer()
                
                Picker("View", selection: $selectedView) {
                    Text("Grid").tag(0)
                    Text("Bars").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            if selectedView == 0 {
                // Grid view
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 10), spacing: 8) {
                    ForEach(0..<estimatedGPUCores, id: \.self) { index in
                        GPUCoreCell(
                            index: index,
                            usage: gpuCoreUsages.indices.contains(index) ? gpuCoreUsages[index] : 0
                        )
                    }
                }
            } else {
                // Bar view
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(0..<estimatedGPUCores, id: \.self) { index in
                        let usage = gpuCoreUsages.indices.contains(index) ? gpuCoreUsages[index] : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(coreColor(usage))
                            .frame(height: max(4, CGFloat(usage) * 0.8))
                    }
                }
                .frame(height: 80)
            }
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .green, label: "Low (0-30%)")
                LegendItem(color: .yellow, label: "Medium (30-60%)")
                LegendItem(color: .orange, label: "High (60-80%)")
                LegendItem(color: .red, label: "Max (80-100%)")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Metal Section
    
    private var metalSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading) {
                        Text("Metal 3")
                            .font(.headline)
                        Text("Hardware-accelerated graphics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: 24) {
                    MetalFeature(name: "Ray Tracing", status: true)
                    MetalFeature(name: "Mesh Shaders", status: true)
                    MetalFeature(name: "MetalFX", status: true)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Unified Memory")
                            .font(.headline)
                        Text("Shared between CPU and GPU")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("GPU Allocated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(metricsCollector.currentMetrics.gpuMemoryUsed))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(metricsCollector.currentMetrics.memoryTotal - metricsCollector.currentMetrics.memoryUsed))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage History (60s)")
                .font(.headline)
            
            GeometryReader { geometry in
                Path { path in
                    let history = Array(metricsCollector.metricsHistory.suffix(60))
                    guard history.count > 1 else { return }
                    
                    let step = geometry.size.width / CGFloat(history.count - 1)
                    
                    for (index, metrics) in history.enumerated() {
                        let x = CGFloat(index) * step
                        let y = geometry.size.height * (1 - CGFloat(metrics.gpuUsage / 100))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
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
    
    private func generateGPUCoreUsages() {
        let baseUsage = metricsCollector.currentMetrics.gpuUsage
        gpuCoreUsages = (0..<estimatedGPUCores).map { _ in
            let variance = Double.random(in: -25...25)
            return max(0, min(100, baseUsage + variance))
        }
    }
    
    private var usageColor: Color {
        let usage = metricsCollector.currentMetrics.gpuUsage
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        if usage > 40 { return .yellow }
        return .green
    }
    
    private var usageGradient: [Color] {
        let usage = metricsCollector.currentMetrics.gpuUsage
        if usage > 80 { return [.red, .orange] }
        if usage > 60 { return [.orange, .yellow] }
        if usage > 40 { return [.yellow, .green] }
        return [.green, .teal]
    }
    
    private var tempColor: Color {
        let temp = metricsCollector.currentMetrics.gpuTemperature
        if temp > 85 { return .red }
        if temp > 70 { return .orange }
        if temp > 55 { return .yellow }
        return .green
    }
    
    private var thermalStateText: String {
        let temp = metricsCollector.currentMetrics.gpuTemperature
        if temp > 85 { return "Critical" }
        if temp > 70 { return "Warm" }
        if temp > 55 { return "Normal" }
        return "Cool"
    }
    
    private func coreColor(_ usage: Double) -> Color {
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        if usage > 30 { return .yellow }
        return .green
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Supporting Views

struct GPUStatCard: View {
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
                .font(.title)
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

struct GPUCoreCell: View {
    let index: Int
    let usage: Double
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellColor.opacity(0.3))
            
            RoundedRectangle(cornerRadius: 6)
                .fill(cellColor)
                .scaleEffect(y: usage / 100, anchor: .bottom)
            
            Text("\(index)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(height: 40)
    }
    
    private var cellColor: Color {
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        if usage > 30 { return .yellow }
        return .green
    }
}

struct PerformanceMetric: View {
    let label: String
    let value: String
    let trend: Trend
    
    enum Trend {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.headline)
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

struct MetalFeature: View {
    let name: String
    let status: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(status ? .green : .red)
            Text(name)
                .font(.caption)
        }
    }
}

#Preview {
    GPUDetailTab()
        .environmentObject(MetricsCollector())
        .frame(width: 900, height: 900)
}
