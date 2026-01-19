import SwiftUI
import Charts

/// RealtimeChartView - A reusable real-time chart component with animated updates
struct RealtimeChartView: View {
    let title: String
    let data: [ChartDataPoint]
    let color: Color
    let unit: String
    let showArea: Bool
    let maxValue: Double?
    
    init(
        title: String,
        data: [ChartDataPoint],
        color: Color = .blue,
        unit: String = "%",
        showArea: Bool = true,
        maxValue: Double? = nil
    ) {
        self.title = title
        self.data = data
        self.color = color
        self.unit = unit
        self.showArea = showArea
        self.maxValue = maxValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if let last = data.last {
                    Text(String(format: "%.1f%@", last.value, unit))
                        .font(.system(.title3, design: .monospaced).bold())
                        .foregroundColor(color)
                }
            }
            
            // Chart
            if data.isEmpty {
                emptyView
            } else {
                chartView
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var emptyView: some View {
        HStack {
            Spacer()
            Text("No data")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(height: 100)
    }
    
    private var chartView: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Time", point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color.gradient)
            .interpolationMethod(.catmullRom)
            
            if showArea {
                AreaMark(
                    x: .value("Time", point.timestamp),
                    yStart: .value("Min", 0),
                    yEnd: .value("Value", point.value)
                )
                .foregroundStyle(color.opacity(0.15).gradient)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 10)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(.secondary.opacity(0.3))
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text(String(format: "%.0f%@", val, unit))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(maxValue ?? (data.map(\.value).max() ?? 100) * 1.2))
        .frame(height: 100)
        .animation(.easeInOut(duration: 0.3), value: data.count)
    }
}

/// Data point for real-time charts
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    
    init(timestamp: Date = Date(), value: Double) {
        self.timestamp = timestamp
        self.value = value
    }
}

// MARK: - Multi-metric Chart

/// MultiMetricChartView - Shows multiple metrics on the same chart
struct MultiMetricChartView: View {
    let title: String
    let datasets: [MetricDataset]
    let timeWindow: TimeInterval
    
    struct MetricDataset: Identifiable {
        let id = UUID()
        let name: String
        let data: [ChartDataPoint]
        let color: Color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with legend
            HStack {
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                ForEach(datasets) { dataset in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dataset.color)
                            .frame(width: 8, height: 8)
                        Text(dataset.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let last = dataset.data.last {
                            Text(String(format: "%.0f%%", last.value))
                                .font(.caption.bold())
                                .foregroundColor(dataset.color)
                        }
                    }
                }
            }
            
            // Chart
            Chart {
                ForEach(datasets) { dataset in
                    ForEach(dataset.data) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Value", point.value),
                            series: .value("Metric", dataset.name)
                        )
                        .foregroundStyle(dataset.color)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(.secondary.opacity(0.3))
                    AxisValueLabel {
                        if let val = value.as(Double.self) {
                            Text("\(Int(val))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 120)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Sparkline

/// SparklineView - Compact inline chart for metrics
struct SparklineView: View {
    let data: [Double]
    let color: Color
    let showGradient: Bool
    
    init(data: [Double], color: Color = .blue, showGradient: Bool = true) {
        self.data = data
        self.color = color
        self.showGradient = showGradient
    }
    
    var body: some View {
        if data.isEmpty {
            Rectangle()
                .fill(Color.clear)
                .frame(height: 30)
        } else {
            Chart(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Index", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)
                
                if showGradient {
                    AreaMark(
                        x: .value("Index", index),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...(data.max() ?? 100) * 1.1)
            .frame(height: 30)
        }
    }
}

// MARK: - Gauge with Sparkline

/// GaugeWithSparkline - Combines a gauge with a sparkline history
struct GaugeWithSparkline: View {
    let title: String
    let currentValue: Double
    let maxValue: Double
    let unit: String
    let history: [Double]
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%@", currentValue, unit))
                    .font(.system(.headline, design: .monospaced).bold())
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(gaugeColor)
                        .frame(width: geometry.size.width * CGFloat(min(currentValue / maxValue, 1.0)))
                        .animation(.easeInOut(duration: 0.5), value: currentValue)
                }
            }
            .frame(height: 8)
            
            // Sparkline
            SparklineView(data: history, color: color)
                .frame(height: 24)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var gaugeColor: Color {
        let ratio = currentValue / maxValue
        if ratio < 0.5 { return .green }
        if ratio < 0.75 { return .yellow }
        if ratio < 0.9 { return .orange }
        return .red
    }
}

// MARK: - Usage Helpers

extension MetricsCollector {
    /// Get CPU history as chart data points
    var cpuChartData: [ChartDataPoint] {
        metricsHistory.map { ChartDataPoint(timestamp: $0.timestamp, value: $0.cpuUsage) }
    }
    
    /// Get Memory history as chart data points (percentage)
    var memoryChartData: [ChartDataPoint] {
        metricsHistory.map { ChartDataPoint(timestamp: $0.timestamp, value: $0.memoryUsagePercent) }
    }
    
    /// Get GPU history as chart data points
    var gpuChartData: [ChartDataPoint] {
        metricsHistory.map { ChartDataPoint(timestamp: $0.timestamp, value: $0.gpuUsage) }
    }
    
    /// Get Temperature history as chart data points
    var tempChartData: [ChartDataPoint] {
        metricsHistory.map { ChartDataPoint(timestamp: $0.timestamp, value: $0.cpuTemperature) }
    }
    
    /// Get CPU usage as array (for sparklines)
    var cpuSparkline: [Double] {
        metricsHistory.suffix(30).map(\.cpuUsage)
    }
    
    /// Get Memory usage percentage as array
    var memorySparkline: [Double] {
        metricsHistory.suffix(30).map(\.memoryUsagePercent)
    }
    
    /// Get GPU usage as array
    var gpuSparkline: [Double] {
        metricsHistory.suffix(30).map(\.gpuUsage)
    }
}

#Preview {
    VStack(spacing: 20) {
        RealtimeChartView(
            title: "CPU Usage",
            data: (0..<30).map { i in
                ChartDataPoint(
                    timestamp: Date().addingTimeInterval(Double(-30 + i) * 2),
                    value: Double.random(in: 20...80)
                )
            },
            color: .blue,
            unit: "%"
        )
        
        SparklineView(
            data: (0..<20).map { _ in Double.random(in: 20...80) },
            color: .green
        )
        .frame(height: 40)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        
        GaugeWithSparkline(
            title: "Memory",
            currentValue: 65,
            maxValue: 100,
            unit: "%",
            history: (0..<20).map { _ in Double.random(in: 50...70) },
            color: .purple,
            icon: "memorychip"
        )
    }
    .padding()
    .frame(width: 400)
}
