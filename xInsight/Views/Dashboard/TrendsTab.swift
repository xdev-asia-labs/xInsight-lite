import SwiftUI
import Charts

/// TrendsTab - Historical data analysis with charts
struct TrendsTab: View {
    @StateObject private var historyStore = MetricsHistoryStore.shared
    @StateObject private var trendAnalyzer = TrendAnalyzer.shared
    
    @State private var selectedPeriod: AnalysisPeriod = .day
    @State private var selectedMetric: MetricType = .cpu
    @State private var hourlyData: [HourlyMetrics] = []
    @State private var dailyData: [DailyMetrics] = []
    @State private var usageSummary: UsageSummary?
    @State private var isLoading: Bool = false
    
    enum MetricType: String, CaseIterable {
        case cpu = "CPU"
        case memory = "Memory"
        case gpu = "GPU"
        case temperature = "Temperature"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with period selector
                headerSection
                
                // Stats summary cards
                if let summary = usageSummary {
                    summaryCards(summary)
                }
                
                // Main chart
                chartSection
                
                // Daily patterns
                dailyPatternsSection
                
                // Weekly patterns
                weeklyPatternsSection
                
                // Anomalies (if any)
                if !trendAnalyzer.anomalies.isEmpty {
                    anomaliesSection
                }
                
                // Memory leak suspects (if any)
                if !trendAnalyzer.memoryLeakSuspects.isEmpty {
                    memoryLeakSection
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            loadData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("📈 " + L10n.string(.trendsAnalysis))
                    .font(.title2.bold())
                
                if historyStore.isReady {
                    Text(L10n.string(.totalSnapshots) + ": \(historyStore.totalSnapshots)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Metric selector
            Picker("Metric", selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
            
            // Period selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            // Refresh button
            Button {
                loadData()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Summary Cards
    
    private func summaryCards(_ summary: UsageSummary) -> some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Avg CPU",
                value: String(format: "%.1f%%", summary.avgCPU),
                subtitle: String(format: "Max: %.1f%%", summary.maxCPU),
                icon: "cpu",
                color: summary.avgCPU > 70 ? .orange : .blue
            )
            
            SummaryCard(
                title: "Avg Memory",
                value: formatBytes(UInt64(summary.avgMemory)),
                subtitle: String(format: "Max: %@", formatBytes(UInt64(summary.maxMemory))),
                icon: "memorychip",
                color: .purple
            )
            
            SummaryCard(
                title: "Avg GPU",
                value: String(format: "%.1f%%", summary.avgGPU),
                subtitle: String(format: "Max: %.1f%%", summary.maxGPU),
                icon: "gpu",
                color: .green
            )
            
            SummaryCard(
                title: "Avg Temp",
                value: String(format: "%.1f°C", summary.avgTemperature),
                subtitle: String(format: "Max: %.1f°C", summary.maxTemperature),
                icon: "thermometer",
                color: summary.avgTemperature > 70 ? .red : .teal
            )
            
            SummaryCard(
                title: "Samples",
                value: "\(summary.sampleCount)",
                subtitle: "Data points",
                icon: "chart.bar",
                color: .gray
            )
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📊 " + L10n.string(.usageOverTime))
                .font(.headline)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else if hourlyData.isEmpty && dailyData.isEmpty {
                emptyDataView
            } else {
                chartView
                    .frame(height: 250)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var emptyDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L10n.string(.noHistoricalData))
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(L10n.string(.dataWillAppear))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250)
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch selectedPeriod {
        case .day:
            hourlyChart
        case .week, .month:
            dailyChart
        }
    }
    
    private var hourlyChart: some View {
        Chart(hourlyData) { data in
            switch selectedMetric {
            case .cpu:
                LineMark(
                    x: .value("Time", data.hour),
                    y: .value("CPU", data.avgCPU)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", data.hour),
                    y: .value("CPU", data.avgCPU)
                )
                .foregroundStyle(.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)
                
            case .memory:
                LineMark(
                    x: .value("Time", data.hour),
                    y: .value("Memory", data.avgMemory / 1_073_741_824) // Convert to GB
                )
                .foregroundStyle(.purple)
                .interpolationMethod(.catmullRom)
                
            case .gpu:
                LineMark(
                    x: .value("Time", data.hour),
                    y: .value("GPU", data.avgGPU)
                )
                .foregroundStyle(.green)
                .interpolationMethod(.catmullRom)
                
            case .temperature:
                LineMark(
                    x: .value("Time", data.hour),
                    y: .value("Temp", data.avgTemperature)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        switch selectedMetric {
                        case .cpu, .gpu:
                            Text("\(Int(v))%")
                        case .memory:
                            Text(String(format: "%.1f GB", v))
                        case .temperature:
                            Text("\(Int(v))°C")
                        }
                    }
                }
            }
        }
    }
    
    private var dailyChart: some View {
        Chart(dailyData) { data in
            switch selectedMetric {
            case .cpu:
                BarMark(
                    x: .value("Date", data.date, unit: .day),
                    y: .value("CPU", data.avgCPU)
                )
                .foregroundStyle(.blue)
                
            case .memory:
                BarMark(
                    x: .value("Date", data.date, unit: .day),
                    y: .value("Memory", data.avgMemory / 1_073_741_824)
                )
                .foregroundStyle(.purple)
                
            case .gpu:
                BarMark(
                    x: .value("Date", data.date, unit: .day),
                    y: .value("GPU", data.avgGPU)
                )
                .foregroundStyle(.green)
                
            case .temperature:
                BarMark(
                    x: .value("Date", data.date, unit: .day),
                    y: .value("Temp", data.avgTemperature)
                )
                .foregroundStyle(.orange)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month())
            }
        }
    }
    
    // MARK: - Daily Patterns Section
    
    private var dailyPatternsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🕐 " + L10n.string(.dailyPatterns))
                    .font(.headline)
                
                Spacer()
                
                if !trendAnalyzer.peakUsageHours.isEmpty {
                    Text(L10n.string(.peakHours) + ": " + trendAnalyzer.peakUsageHours.map { "\($0):00" }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if trendAnalyzer.dailyPatterns.isEmpty {
                Text(L10n.string(.notEnoughData))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart(trendAnalyzer.dailyPatterns) { pattern in
                    BarMark(
                        x: .value("Hour", pattern.hourLabel),
                        y: .value("CPU", pattern.avgCPU)
                    )
                    .foregroundStyle(
                        trendAnalyzer.peakUsageHours.contains(pattern.hour) ? .red : .blue
                    )
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 12))
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Weekly Patterns Section
    
    private var weeklyPatternsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("📅 " + L10n.string(.weeklyPatterns))
                .font(.headline)
            
            if trendAnalyzer.weeklyPatterns.isEmpty {
                Text(L10n.string(.notEnoughData))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                HStack(spacing: 16) {
                    ForEach(trendAnalyzer.weeklyPatterns) { pattern in
                        WeekdayCard(pattern: pattern)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Anomalies Section
    
    private var anomaliesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("⚠️ " + L10n.string(.detectedAnomalies))
                .font(.headline)
            
            ForEach(trendAnalyzer.anomalies.prefix(5)) { anomaly in
                AnomalyRow(anomaly: anomaly)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Memory Leak Section
    
    private var memoryLeakSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔍 " + L10n.string(.memoryLeakSuspects))
                .font(.headline)
            
            ForEach(trendAnalyzer.memoryLeakSuspects) { suspect in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading) {
                        Text(suspect.description)
                            .font(.subheadline)
                        
                        Text(String(format: "Growth rate: %.2f%% per day", suspect.growthRatePerDay * 100))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.0f%% confidence", suspect.confidence * 100))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        isLoading = true
        
        Task {
            let endDate = Date()
            let startDate: Date
            
            switch selectedPeriod {
            case .day:
                startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
                hourlyData = await historyStore.getHourlyAverages(from: startDate, to: endDate)
            case .week:
                startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
                dailyData = await historyStore.getDailyAverages(from: startDate, to: endDate)
            case .month:
                startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
                dailyData = await historyStore.getDailyAverages(from: startDate, to: endDate)
            }
            
            // Get usage summary
            usageSummary = await trendAnalyzer.getUsageSummary(for: selectedPeriod)
            
            // Analyze patterns
            await trendAnalyzer.analyzeWeeklyPatterns()
            
            if selectedPeriod == .month {
                await trendAnalyzer.analyzeMonthlyPatterns()
            }
            
            isLoading = false
        }
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct WeekdayCard: View {
    let pattern: WeeklyPattern
    
    var body: some View {
        VStack(spacing: 8) {
            Text(pattern.shortName)
                .font(.caption.bold())
            
            // CPU bar
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: 8, height: CGFloat(pattern.avgCPU))
                    .frame(maxHeight: 60, alignment: .bottom)
                
                Text(String(format: "%.0f%%", pattern.avgCPU))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct AnomalyRow: View {
    let anomaly: TrendAnomaly
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(anomaly.severity.color))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                Text(anomaly.type.rawValue)
                    .font(.subheadline.bold())
                
                Text(dateFormatter.string(from: anomaly.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", anomaly.value))
                .font(.headline)
            
            Text("Expected: \(String(format: "%.1f - %.1f", anomaly.expectedRange.min, anomaly.expectedRange.max))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    TrendsTab()
        .frame(width: 900, height: 700)
}
