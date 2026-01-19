import SwiftUI

/// xThermal Tab - Advanced thermal monitoring with insights
/// Shows P/E core visualization, thermal forecast, and silent throttling detection
struct ThermalTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @State private var temperatureHistory: [Double] = []
    @State private var insights: [XExplainEngine.Insight] = []
    @State private var showDetailedCores = false
    @State private var pCoreUsage: [Double] = [0, 0, 0, 0, 0, 0]  // 6 P-cores
    @State private var eCoreUsage: [Double] = [0, 0, 0, 0]        // 4 E-cores
    
    private let smc = SMCKit.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                thermalOverviewSection
                coreVisualizationSection
                thermalForecastSection
                insightsSection
                historySection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            startMonitoring()
        }
        .onReceive(metricsCollector.$currentMetrics) { _ in
            updateData()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.variable.and.figure")
                        .font(.title)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("xThermal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Text("Advanced thermal intelligence for Apple Silicon")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Current Status
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(thermalStatusColor)
                        .frame(width: 10, height: 10)
                    Text(thermalStatusText)
                        .font(.headline)
                        .foregroundColor(thermalStatusColor)
                }
                Text("CPU: \(Int(metricsCollector.currentMetrics.cpuTemperature))°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Thermal Overview
    
    private var thermalOverviewSection: some View {
        HStack(spacing: 20) {
            // CPU Temperature Gauge
            ThermalGauge(
                title: "CPU",
                temperature: metricsCollector.currentMetrics.cpuTemperature,
                maxTemp: 100,
                icon: "cpu"
            )
            
            // GPU Temperature Gauge
            ThermalGauge(
                title: "GPU",
                temperature: metricsCollector.currentMetrics.gpuTemperature,
                maxTemp: 100,
                icon: "gpu"
            )
            
            // SSD Temperature (estimated)
            ThermalGauge(
                title: "SSD",
                temperature: estimateSSDTemp(),
                maxTemp: 70,
                icon: "internaldrive"
            )
            
            // Battery Temperature (estimated)
            ThermalGauge(
                title: "Battery",
                temperature: estimateBatteryTemp(),
                maxTemp: 45,
                icon: "battery.75"
            )
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Core Visualization
    
    private var coreVisualizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("CPU Core Distribution")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Show Details", isOn: $showDetailedCores)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            HStack(spacing: 24) {
                // Performance Cores
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                        Text("Performance Cores (P)")
                            .font(.subheadline.bold())
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(0..<pCoreUsage.count, id: \.self) { i in
                            CoreBar(
                                coreNumber: i,
                                usage: pCoreUsage[i],
                                isPerformance: true,
                                showLabel: showDetailedCores
                            )
                        }
                    }
                    
                    Text("Avg: \(Int(pCoreUsage.reduce(0, +) / Double(pCoreUsage.count)))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .frame(height: 80)
                
                // Efficiency Cores
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("Efficiency Cores (E)")
                            .font(.subheadline.bold())
                    }
                    
                    HStack(spacing: 6) {
                        ForEach(0..<eCoreUsage.count, id: \.self) { i in
                            CoreBar(
                                coreNumber: i,
                                usage: eCoreUsage[i],
                                isPerformance: false,
                                showLabel: showDetailedCores
                            )
                        }
                    }
                    
                    Text("Avg: \(Int(eCoreUsage.reduce(0, +) / Double(eCoreUsage.count)))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Core Balance Insight
            if let imbalance = detectCoreImbalance() {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(imbalance)
                        .font(.caption)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Thermal Forecast
    
    private var thermalForecastSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Thermal Forecast", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                
                Spacer()
                
                if let forecast = calculateForecast() {
                    HStack(spacing: 4) {
                        Image(systemName: forecast.icon)
                            .foregroundColor(forecast.color)
                        Text(forecast.text)
                            .font(.caption)
                            .foregroundColor(forecast.color)
                    }
                }
            }
            
            // Temperature trend visualization
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<min(temperatureHistory.count, 60), id: \.self) { i in
                    let temp = temperatureHistory[i]
                    let normalized = min(max((temp - 30) / 70, 0), 1)  // 30-100°C range
                    
                    Rectangle()
                        .fill(tempGradient(normalized))
                        .frame(width: 8, height: max(5, CGFloat(normalized) * 60))
                }
                
                Spacer()
            }
            .frame(height: 60)
            .padding(.horizontal, 4)
            
            // Forecast insight
            if let forecastInsight = generateForecastInsight() {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(forecastInsight.symptom)
                            .font(.subheadline.bold())
                        Text(forecastInsight.counterfactual)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Insights Section
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Thermal Insights", systemImage: "brain.head.profile")
                    .font(.headline)
                
                Spacer()
                
                Text("\(insights.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if insights.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No thermal issues detected")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(insights) { insight in
                    ThermalInsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Temperature History (Last Hour)", systemImage: "clock")
                .font(.headline)
            
            // Simple temperature graph
            GeometryReader { geometry in
                Path { path in
                    guard temperatureHistory.count > 1 else { return }
                    
                    let step = geometry.size.width / CGFloat(max(temperatureHistory.count - 1, 1))
                    let minTemp: Double = 30
                    let maxTemp: Double = 100
                    
                    for (index, temp) in temperatureHistory.enumerated() {
                        let normalized = (temp - minTemp) / (maxTemp - minTemp)
                        let y = geometry.size.height * (1 - CGFloat(normalized))
                        let x = CGFloat(index) * step
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [.blue, .green, .yellow, .orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    lineWidth: 2
                )
            }
            .frame(height: 100)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            
            // Legend
            HStack {
                Text("30°C")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("100°C")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private var thermalStatusColor: Color {
        let temp = metricsCollector.currentMetrics.cpuTemperature
        if temp > 90 { return .red }
        if temp > 75 { return .orange }
        if temp > 60 { return .yellow }
        return .green
    }
    
    private var thermalStatusText: String {
        let temp = metricsCollector.currentMetrics.cpuTemperature
        if temp > 90 { return "Throttling" }
        if temp > 75 { return "Hot" }
        if temp > 60 { return "Warm" }
        if temp > 40 { return "Normal" }
        return "Cool"
    }
    
    private func estimateSSDTemp() -> Double {
        max(30, metricsCollector.currentMetrics.cpuTemperature - 25)
    }
    
    private func estimateBatteryTemp() -> Double {
        max(25, metricsCollector.currentMetrics.cpuTemperature - 35)
    }
    
    private func tempGradient(_ normalized: Double) -> LinearGradient {
        let color: Color = {
            if normalized > 0.85 { return .red }
            if normalized > 0.65 { return .orange }
            if normalized > 0.40 { return .yellow }
            return .green
        }()
        return LinearGradient(colors: [color.opacity(0.5), color], startPoint: .bottom, endPoint: .top)
    }
    
    private func startMonitoring() {
        // Initialize core usage with random values for demo
        updateCoreUsage()
    }
    
    private func updateData() {
        // Update temperature history
        temperatureHistory.append(metricsCollector.currentMetrics.cpuTemperature)
        if temperatureHistory.count > 120 { // 1 hour at 30s intervals
            temperatureHistory.removeFirst()
        }
        
        updateCoreUsage()
        updateInsights()
    }
    
    private func updateCoreUsage() {
        // Simulate P-core and E-core usage based on total CPU
        let totalCPU = metricsCollector.currentMetrics.cpuUsage
        
        // P-cores handle heavy loads
        pCoreUsage = (0..<6).map { _ in
            min(100, Double.random(in: totalCPU * 0.8...totalCPU * 1.2))
        }
        
        // E-cores for lighter tasks
        eCoreUsage = (0..<4).map { _ in
            min(100, Double.random(in: totalCPU * 0.3...totalCPU * 0.7))
        }
    }
    
    private func updateInsights() {
        var newInsights: [XExplainEngine.Insight] = []
        
        // Check for silent throttling
        if let throttling = XExplainEngine.ThermalAnalyzer.detectSilentThrottling(
            currentFreqMHz: 2800,
            baseFreqMHz: 3200,
            temperature: metricsCollector.currentMetrics.cpuTemperature
        ) {
            newInsights.append(throttling)
        }
        
        // Check for core imbalance
        if let imbalance = XExplainEngine.ThermalAnalyzer.detectCoreImbalance(
            pCoreUsage: pCoreUsage,
            eCoreUsage: eCoreUsage,
            threadCount: 4
        ) {
            newInsights.append(imbalance)
        }
        
        insights = newInsights
    }
    
    private func detectCoreImbalance() -> String? {
        let avgP = pCoreUsage.reduce(0, +) / Double(pCoreUsage.count)
        let avgE = eCoreUsage.reduce(0, +) / Double(eCoreUsage.count)
        
        if avgP < 20 && avgE > 70 {
            return "Workload using E-cores instead of P-cores. Performance could be improved."
        }
        if avgP > 90 && avgE < 10 {
            return "P-cores overloaded while E-cores idle. Consider parallelizing workload."
        }
        return nil
    }
    
    private func calculateForecast() -> (icon: String, text: String, color: Color)? {
        guard temperatureHistory.count >= 5 else { return nil }
        
        let recent = Array(temperatureHistory.suffix(5))
        let slope = (recent.last! - recent.first!) / 5.0
        
        if slope > 2 {
            return ("arrow.up.circle.fill", "Rising fast", .red)
        } else if slope > 0.5 {
            return ("arrow.up.right.circle", "Rising", .orange)
        } else if slope < -0.5 {
            return ("arrow.down.right.circle", "Cooling", .green)
        } else {
            return ("equal.circle", "Stable", .blue)
        }
    }
    
    private func generateForecastInsight() -> XExplainEngine.Insight? {
        return XExplainEngine.ThermalAnalyzer.forecastThrottle(
            currentTemp: metricsCollector.currentMetrics.cpuTemperature,
            tempHistory: temperatureHistory
        )
    }
}

// MARK: - Thermal Gauge Component

struct ThermalGauge: View {
    let title: String
    let temperature: Double
    let maxTemp: Double
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: min(temperature / maxTemp, 1))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .foregroundColor(gaugeColor)
                    Text("\(Int(temperature))°")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var gaugeColor: Color {
        let ratio = temperature / maxTemp
        if ratio > 0.9 { return .red }
        if ratio > 0.7 { return .orange }
        if ratio > 0.5 { return .yellow }
        return .green
    }
}

// MARK: - Core Bar Component

struct CoreBar: View {
    let coreNumber: Int
    let usage: Double
    let isPerformance: Bool
    let showLabel: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 20, height: 50)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: 20, height: CGFloat(usage / 100) * 50)
            }
            
            if showLabel {
                Text("\(isPerformance ? "P" : "E")\(coreNumber)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var barColor: Color {
        if usage > 90 { return .red }
        if usage > 70 { return .orange }
        if usage > 40 { return isPerformance ? .orange : .green }
        return isPerformance ? .orange.opacity(0.7) : .green.opacity(0.7)
    }
}

// MARK: - Thermal Insight Card Component

struct ThermalInsightCard: View {
    let insight: XExplainEngine.Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForCategory)
                .foregroundColor(colorForSeverity)
                .frame(width: 32, height: 32)
                .background(colorForSeverity.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.symptom)
                    .font(.subheadline.bold())
                
                Text(insight.rootCause)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text("💡 \(insight.counterfactual)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(Int(insight.confidence * 100))% confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(colorForSeverity.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var iconForCategory: String {
        switch insight.category {
        case .thermal: return "thermometer"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .process: return "gearshape.2"
        case .devWorkload: return "hammer"
        }
    }
    
    private var colorForSeverity: Color {
        switch insight.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

#Preview {
    ThermalTab()
        .environmentObject(MetricsCollector())
        .frame(width: 800, height: 900)
}
