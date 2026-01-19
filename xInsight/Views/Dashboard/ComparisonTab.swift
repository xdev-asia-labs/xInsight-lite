import SwiftUI
import Charts

/// ComparisonMode - Compare system metrics between two time periods
struct ComparisonTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    @State private var period1Start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var period1End = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    @State private var period2Start = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
    @State private var period2End = Date()
    
    @State private var period1Data: [HourlyMetrics] = []
    @State private var period2Data: [HourlyMetrics] = []
    @State private var isLoading = false
    @State private var comparisonResult: ComparisonResult?
    
    private let historyStore = MetricsHistoryStore.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Period Selection
                periodSelectionSection
                
                // Compare Button
                compareButton
                
                if isLoading {
                    ProgressView("Analyzing periods...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let result = comparisonResult {
                    // Results
                    comparisonCardsSection(result)
                    
                    // Charts
                    comparisonChartsSection(result)
                    
                    // Details
                    detailsSection(result)
                } else {
                    emptyState
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Comparison Mode")
                    .font(.title.bold())
                Text("Compare system performance between two time periods")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Period Selection
    
    private var periodSelectionSection: some View {
        HStack(spacing: 24) {
            periodCard(
                title: "Period 1 (Baseline)",
                color: .blue,
                start: $period1Start,
                end: $period1End
            )
            
            Image(systemName: "arrow.left.arrow.right")
                .font(.title2)
                .foregroundColor(.secondary)
            
            periodCard(
                title: "Period 2 (Compare)",
                color: .orange,
                start: $period2Start,
                end: $period2End
            )
        }
    }
    
    private func periodCard(title: String, color: Color, start: Binding<Date>, end: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.headline)
            }
            
            HStack {
                DatePicker("Start", selection: start, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            
            HStack {
                DatePicker("End", selection: end, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Compare Button
    
    private var compareButton: some View {
        Button {
            Task {
                await performComparison()
            }
        } label: {
            Label("Compare Periods", systemImage: "chart.bar.xaxis")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading)
    }
    
    // MARK: - Comparison Cards
    
    private func comparisonCardsSection(_ result: ComparisonResult) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            comparisonCard(
                title: "CPU",
                icon: "cpu",
                period1: result.avgCPU1,
                period2: result.avgCPU2,
                unit: "%"
            )
            
            comparisonCard(
                title: "Memory",
                icon: "memorychip",
                period1: result.avgMemory1,
                period2: result.avgMemory2,
                unit: "%"
            )
            
            comparisonCard(
                title: "Temperature",
                icon: "thermometer",
                period1: result.avgTemp1,
                period2: result.avgTemp2,
                unit: "°C"
            )
            
            comparisonCard(
                title: "Disk I/O",
                icon: "internaldrive",
                period1: result.avgDiskIO1,
                period2: result.avgDiskIO2,
                unit: " MB/s"
            )
        }
    }
    
    private func comparisonCard(title: String, icon: String, period1: Double, period2: Double, unit: String) -> some View {
        let change = period2 - period1
        let changePercent = period1 > 0 ? (change / period1) * 100 : 0
        let isIncrease = change > 0
        
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.caption.bold())
            }
            
            HStack(spacing: 4) {
                VStack {
                    Text(String(format: "%.1f", period1))
                        .font(.title3.bold())
                    Text("Period 1")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Text("→")
                    .foregroundColor(.secondary)
                
                VStack {
                    Text(String(format: "%.1f", period2))
                        .font(.title3.bold())
                    Text("Period 2")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Image(systemName: isIncrease ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%+.1f%%", changePercent))
            }
            .font(.caption)
            .foregroundColor(isIncrease ? .red : .green)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Charts
    
    private func comparisonChartsSection(_ result: ComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CPU Usage Comparison")
                .font(.headline)
            
            Chart {
                ForEach(Array(period1Data.enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("CPU", data.avgCPU)
                    )
                    .foregroundStyle(.blue)
                }
                
                ForEach(Array(period2Data.enumerated()), id: \.offset) { index, data in
                    LineMark(
                        x: .value("Index", index),
                        y: .value("CPU", data.avgCPU)
                    )
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
            
            HStack {
                Label("Period 1", systemImage: "circle.fill")
                    .foregroundColor(.blue)
                Label("Period 2", systemImage: "circle.fill")
                    .foregroundColor(.orange)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Details
    
    private func detailsSection(_ result: ComparisonResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Summary")
                .font(.headline)
            
            ForEach(result.insights, id: \.self) { insight in
                HStack {
                    Image(systemName: insight.contains("increase") || insight.contains("higher") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(insight.contains("increase") || insight.contains("higher") ? .yellow : .green)
                    Text(insight)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select two time periods and click Compare")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    // MARK: - Comparison Logic
    
    private func performComparison() async {
        isLoading = true
        defer { isLoading = false }
        
        period1Data = await historyStore.getHourlyAverages(from: period1Start, to: period1End)
        period2Data = await historyStore.getHourlyAverages(from: period2Start, to: period2End)
        
        guard !period1Data.isEmpty && !period2Data.isEmpty else {
            comparisonResult = nil
            return
        }
        
        let avgCPU1 = period1Data.map(\.avgCPU).reduce(0, +) / Double(period1Data.count)
        let avgCPU2 = period2Data.map(\.avgCPU).reduce(0, +) / Double(period2Data.count)
        
        // Use avgMemory in GB for comparison
        let avgMem1 = period1Data.map { $0.avgMemory / 1_073_741_824 }.reduce(0, +) / Double(period1Data.count)
        let avgMem2 = period2Data.map { $0.avgMemory / 1_073_741_824 }.reduce(0, +) / Double(period2Data.count)
        
        let avgTemp1 = period1Data.map(\.avgTemperature).reduce(0, +) / Double(period1Data.count)
        let avgTemp2 = period2Data.map(\.avgTemperature).reduce(0, +) / Double(period2Data.count)
        
        // GPU as proxy for overall I/O activity
        let avgGPU1 = period1Data.map(\.avgGPU).reduce(0, +) / Double(period1Data.count)
        let avgGPU2 = period2Data.map(\.avgGPU).reduce(0, +) / Double(period2Data.count)
        
        var insights: [String] = []
        
        if avgCPU2 > avgCPU1 * 1.2 {
            insights.append("CPU usage increased by \(String(format: "%.0f", (avgCPU2/avgCPU1 - 1) * 100))% in Period 2")
        } else if avgCPU2 < avgCPU1 * 0.8 {
            insights.append("CPU usage decreased by \(String(format: "%.0f", (1 - avgCPU2/avgCPU1) * 100))% in Period 2")
        }
        
        if avgMem2 > avgMem1 * 1.1 {
            insights.append("Memory usage is higher in Period 2")
        }
        
        if avgTemp2 > avgTemp1 + 5 {
            insights.append("Temperature increased by \(String(format: "%.0f", avgTemp2 - avgTemp1))°C")
        }
        
        if insights.isEmpty {
            insights.append("System performance is similar between both periods")
        }
        
        comparisonResult = ComparisonResult(
            avgCPU1: avgCPU1, avgCPU2: avgCPU2,
            avgMemory1: avgMem1, avgMemory2: avgMem2,
            avgTemp1: avgTemp1, avgTemp2: avgTemp2,
            avgDiskIO1: avgGPU1, avgDiskIO2: avgGPU2,
            insights: insights
        )
    }
}

// MARK: - Models

struct ComparisonResult {
    let avgCPU1: Double
    let avgCPU2: Double
    let avgMemory1: Double
    let avgMemory2: Double
    let avgTemp1: Double
    let avgTemp2: Double
    let avgDiskIO1: Double
    let avgDiskIO2: Double
    let insights: [String]
}
