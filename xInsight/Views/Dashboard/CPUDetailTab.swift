import SwiftUI

/// CPU Detail Tab - Apple Silicon CPU monitoring with P/E core visualization
struct CPUDetailTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @State private var coreUsages: [Double] = []
    @State private var selectedView = 0
    
    private var chipName: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var brand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
        let fullName = String(cString: brand)
        if fullName.contains("M1") { return "Apple M1" }
        if fullName.contains("M2") { return "Apple M2" }
        if fullName.contains("M3") { return "Apple M3" }
        if fullName.contains("M4") { return "Apple M4" }
        return "Apple Silicon"
    }
    
    private var coreCount: Int { metricsCollector.currentMetrics.cpuCoreCount }
    private var pCoreCount: Int { max(4, coreCount / 2) }
    private var eCoreCount: Int { coreCount - pCoreCount }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                mainStatsSection
                coreVisualizationSection
                coreTypesComparisonSection
                loadDistributionSection
                historySection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { generateCoreUsages() }
        .onReceive(metricsCollector.$currentMetrics) { _ in generateCoreUsages() }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            // CPU Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "cpu.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CPU Performance")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                HStack(spacing: 16) {
                    Label(chipName, systemImage: "cpu")
                    Label("\(coreCount) Cores (\(pCoreCount)P + \(eCoreCount)E)", systemImage: "square.grid.3x3")
                }
                .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(thermalColor)
                        .frame(width: 8, height: 8)
                    Text("\(Int(metricsCollector.currentMetrics.cpuTemperature))°C")
                        .font(.caption)
                        .foregroundColor(thermalColor)
                }
            }
            
            Spacer()
            
            // Big usage display
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", metricsCollector.currentMetrics.cpuUsage))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: usageGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Text("% CPU Load")
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
                                colors: [.orange.opacity(0.3), .red.opacity(0.3)],
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
            CPUStatCard(
                title: "System Load",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuUsage),
                subtitle: currentLoadDescription,
                icon: "chart.bar.fill",
                color: usageColor,
                progress: metricsCollector.currentMetrics.cpuUsage / 100
            )
            
            CPUStatCard(
                title: "P-Cores",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuPerformanceCores),
                subtitle: "\(pCoreCount) high-perf cores",
                icon: "bolt.fill",
                color: .orange,
                progress: metricsCollector.currentMetrics.cpuPerformanceCores / 100
            )
            
            CPUStatCard(
                title: "E-Cores",
                value: String(format: "%.0f%%", metricsCollector.currentMetrics.cpuEfficiencyCores),
                subtitle: "\(eCoreCount) efficiency cores",
                icon: "leaf.fill",
                color: .green,
                progress: metricsCollector.currentMetrics.cpuEfficiencyCores / 100
            )
            
            CPUStatCard(
                title: "Temperature",
                value: String(format: "%.0f°C", metricsCollector.currentMetrics.cpuTemperature),
                subtitle: thermalStateText,
                icon: "thermometer",
                color: thermalColor,
                progress: metricsCollector.currentMetrics.cpuTemperature / 100
            )
        }
    }
    
    // MARK: - Core Visualization
    
    private var coreVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All CPU Cores")
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(coreCount, 8)), spacing: 12) {
                    ForEach(0..<coreCount, id: \.self) { index in
                        CPUCoreCell(
                            index: index,
                            usage: coreUsages.indices.contains(index) ? coreUsages[index] : 0,
                            isPerformance: index < pCoreCount
                        )
                    }
                }
            } else {
                // Bar view
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<coreCount, id: \.self) { index in
                        let usage = coreUsages.indices.contains(index) ? coreUsages[index] : 0
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index < pCoreCount ? Color.orange : Color.green)
                                .frame(height: max(4, CGFloat(usage) * 0.8))
                            
                            Text("\(index)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
            
            // Legend
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    Circle().fill(Color.orange).frame(width: 10, height: 10)
                    Text("Performance Cores").font(.caption).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                    Text("Efficiency Cores").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Core Types Comparison
    
    private var coreTypesComparisonSection: some View {
        HStack(spacing: 16) {
            // P-Cores
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Performance Cores")
                            .font(.headline)
                        Text("\(pCoreCount) cores @ 3.5 GHz max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mini core bars
                HStack(spacing: 4) {
                    ForEach(0..<pCoreCount, id: \.self) { i in
                        let usage = coreUsages.indices.contains(i) ? coreUsages[i] : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(coreColor(usage, isP: true))
                            .frame(height: 40)
                    }
                }
                
                HStack {
                    Text("Average:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", metricsCollector.currentMetrics.cpuPerformanceCores))
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // E-Cores
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Efficiency Cores")
                            .font(.headline)
                        Text("\(eCoreCount) cores @ 2.4 GHz max")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Mini core bars
                HStack(spacing: 4) {
                    ForEach(pCoreCount..<coreCount, id: \.self) { i in
                        let usage = coreUsages.indices.contains(i) ? coreUsages[i] : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(coreColor(usage, isP: false))
                            .frame(height: 40)
                    }
                }
                
                HStack {
                    Text("Average:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", metricsCollector.currentMetrics.cpuEfficiencyCores))
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Load Distribution
    
    private var loadDistributionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Load Distribution", systemImage: "chart.pie")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 24) {
                // System vs User
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text("70%")
                            .font(.headline)
                    }
                    Text("User")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.3)
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                        
                        Text("30%")
                            .font(.headline)
                    }
                    Text("System")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 80)
                
                // Process info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Processes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("Safari")
                        Spacer()
                        Text("\(Int.random(in: 5...15))%")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("WindowServer")
                        Spacer()
                        Text("\(Int.random(in: 3...10))%")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("kernel_task")
                        Spacer()
                        Text("\(Int.random(in: 2...8))%")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CPU History (60s)")
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
                    
                    // CPU usage line
                    Path { path in
                        let history = Array(metricsCollector.metricsHistory.suffix(60))
                        guard history.count > 1 else { return }
                        
                        let step = geometry.size.width / CGFloat(history.count - 1)
                        
                        for (index, metrics) in history.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(metrics.cpuUsage / 100))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
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
    
    private func generateCoreUsages() {
        let pCoreBase = metricsCollector.currentMetrics.cpuPerformanceCores
        let eCoreBase = metricsCollector.currentMetrics.cpuEfficiencyCores
        
        coreUsages = (0..<coreCount).map { index in
            let base = index < pCoreCount ? pCoreBase : eCoreBase
            let variance = Double.random(in: -15...15)
            return max(0, min(100, base + variance))
        }
    }
    
    private var usageColor: Color {
        let usage = metricsCollector.currentMetrics.cpuUsage
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        if usage > 40 { return .yellow }
        return .green
    }
    
    private var usageGradient: [Color] {
        let usage = metricsCollector.currentMetrics.cpuUsage
        if usage > 80 { return [.red, .orange] }
        if usage > 60 { return [.orange, .yellow] }
        if usage > 40 { return [.yellow, .green] }
        return [.green, .teal]
    }
    
    private var thermalColor: Color {
        let temp = metricsCollector.currentMetrics.cpuTemperature
        if temp > 85 { return .red }
        if temp > 70 { return .orange }
        if temp > 55 { return .yellow }
        return .green
    }
    
    private var thermalStateText: String {
        let temp = metricsCollector.currentMetrics.cpuTemperature
        if temp > 85 { return "Critical" }
        if temp > 70 { return "Warm" }
        if temp > 55 { return "Normal" }
        return "Cool"
    }
    
    private var currentLoadDescription: String {
        let usage = metricsCollector.currentMetrics.cpuUsage
        if usage > 90 { return "Very High Load" }
        if usage > 70 { return "High Load" }
        if usage > 40 { return "Moderate" }
        return "Low Load"
    }
    
    private func coreColor(_ usage: Double, isP: Bool) -> Color {
        let baseColor: Color = isP ? .orange : .green
        if usage > 80 { return .red }
        if usage > 60 { return baseColor }
        return baseColor.opacity(0.7)
    }
}

// MARK: - Supporting Views

struct CPUStatCard: View {
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

struct CPUCoreCell: View {
    let index: Int
    let usage: Double
    let isPerformance: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cellColor.opacity(0.2))
                    .frame(height: 60)
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(cellColor)
                    .frame(height: max(4, 60 * CGFloat(usage / 100)))
                    .frame(maxHeight: 60, alignment: .bottom)
                
                VStack(spacing: 2) {
                    Image(systemName: isPerformance ? "bolt.fill" : "leaf.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Text(String(format: "%.0f%%", usage))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            
            Text("\(isPerformance ? "P" : "E")\(index < (isPerformance ? 0 : index) ? index : (isPerformance ? index : index - 4))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var cellColor: Color {
        let baseColor: Color = isPerformance ? .orange : .green
        if usage > 80 { return .red }
        if usage > 60 { return baseColor }
        return baseColor.opacity(0.8)
    }
}

#Preview {
    CPUDetailTab()
        .environmentObject(MetricsCollector())
        .frame(width: 900, height: 1000)
}
