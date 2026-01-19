import Foundation

/// TrendAnalyzer - Analyzes historical metrics to identify trends and patterns
@MainActor
final class TrendAnalyzer: ObservableObject {
    static let shared = TrendAnalyzer()
    
    // MARK: - Published Properties
    @Published var dailyPatterns: [DailyPattern] = []
    @Published var weeklyPatterns: [WeeklyPattern] = []
    @Published var peakUsageHours: [Int] = []
    @Published var anomalies: [TrendAnomaly] = []
    @Published var memoryLeakSuspects: [MemoryLeakSuspect] = []
    @Published var isAnalyzing: Bool = false
    
    // MARK: - Dependencies
    private let historyStore = MetricsHistoryStore.shared
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Pattern Analysis
    
    /// Analyze patterns from the last 7 days
    func analyzeWeeklyPatterns() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        
        let hourlyData = await historyStore.getHourlyAverages(from: startDate, to: endDate)
        
        // Analyze daily patterns (by hour of day)
        await analyzeDailyPatterns(from: hourlyData)
        
        // Analyze weekly patterns (by day of week)
        await analyzeWeekdayPatterns(from: hourlyData)
        
        // Find peak usage hours
        findPeakUsageHours(from: hourlyData)
        
        isAnalyzing = false
    }
    
    /// Analyze patterns from the last 30 days
    func analyzeMonthlyPatterns() async {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        
        let dailyData = await historyStore.getDailyAverages(from: startDate, to: endDate)
        
        // Detect long-term trends
        await detectLongTermTrends(from: dailyData)
        
        // Detect anomalies
        await detectAnomalies(from: dailyData)
        
        isAnalyzing = false
    }
    
    // MARK: - Daily Pattern Analysis
    
    private func analyzeDailyPatterns(from hourlyData: [HourlyMetrics]) async {
        var hourlyAggregates: [Int: (cpuSum: Double, memSum: Double, gpuSum: Double, count: Int)] = [:]
        
        let calendar = Calendar.current
        
        for hourly in hourlyData {
            let hour = calendar.component(.hour, from: hourly.hour)
            if var existing = hourlyAggregates[hour] {
                existing.cpuSum += hourly.avgCPU
                existing.memSum += hourly.avgMemory
                existing.gpuSum += hourly.avgGPU
                existing.count += 1
                hourlyAggregates[hour] = existing
            } else {
                hourlyAggregates[hour] = (hourly.avgCPU, hourly.avgMemory, hourly.avgGPU, 1)
            }
        }
        
        var patterns: [DailyPattern] = []
        
        for (hour, data) in hourlyAggregates.sorted(by: { $0.key < $1.key }) {
            let count = Double(data.count)
            patterns.append(DailyPattern(
                hour: hour,
                avgCPU: data.cpuSum / count,
                avgMemory: data.memSum / count,
                avgGPU: data.gpuSum / count,
                sampleCount: data.count
            ))
        }
        
        dailyPatterns = patterns
    }
    
    private func analyzeWeekdayPatterns(from hourlyData: [HourlyMetrics]) async {
        var weekdayAggregates: [Int: (cpuSum: Double, memSum: Double, gpuSum: Double, count: Int)] = [:]
        
        let calendar = Calendar.current
        
        for hourly in hourlyData {
            let weekday = calendar.component(.weekday, from: hourly.hour)
            if var existing = weekdayAggregates[weekday] {
                existing.cpuSum += hourly.avgCPU
                existing.memSum += hourly.avgMemory
                existing.gpuSum += hourly.avgGPU
                existing.count += 1
                weekdayAggregates[weekday] = existing
            } else {
                weekdayAggregates[weekday] = (hourly.avgCPU, hourly.avgMemory, hourly.avgGPU, 1)
            }
        }
        
        var patterns: [WeeklyPattern] = []
        
        for (weekday, data) in weekdayAggregates.sorted(by: { $0.key < $1.key }) {
            let count = Double(data.count)
            patterns.append(WeeklyPattern(
                weekday: weekday,
                avgCPU: data.cpuSum / count,
                avgMemory: data.memSum / count,
                avgGPU: data.gpuSum / count,
                sampleCount: data.count
            ))
        }
        
        weeklyPatterns = patterns
    }
    
    private func findPeakUsageHours(from hourlyData: [HourlyMetrics]) {
        // Group by hour of day and find average CPU
        var hourlyAverages: [Int: Double] = [:]
        var hourlyCounts: [Int: Int] = [:]
        
        let calendar = Calendar.current
        
        for hourly in hourlyData {
            let hour = calendar.component(.hour, from: hourly.hour)
            hourlyAverages[hour, default: 0] += hourly.avgCPU
            hourlyCounts[hour, default: 0] += 1
        }
        
        // Calculate averages
        var avgByHour: [(hour: Int, avg: Double)] = []
        for (hour, sum) in hourlyAverages {
            if let count = hourlyCounts[hour], count > 0 {
                avgByHour.append((hour, sum / Double(count)))
            }
        }
        
        // Sort by CPU usage and take top 3
        let topHours = avgByHour.sorted { $0.avg > $1.avg }.prefix(3).map { $0.hour }
        peakUsageHours = topHours
    }
    
    // MARK: - Long-term Trend Detection
    
    private func detectLongTermTrends(from dailyData: [DailyMetrics]) async {
        guard dailyData.count >= 7 else { return }
        
        // Check for memory growth trend (potential memory leak indicator)
        let memoryValues = dailyData.map { $0.avgMemory }
        
        if isGrowingTrend(memoryValues) {
            let growthRate = calculateGrowthRate(memoryValues)
            if growthRate > 0.01 { // 1% daily growth
                memoryLeakSuspects.append(MemoryLeakSuspect(
                    type: .gradualGrowth,
                    description: "Memory usage has been steadily increasing",
                    growthRatePerDay: growthRate,
                    confidence: min(0.9, growthRate * 10),
                    detectedAt: Date()
                ))
            }
        }
    }
    
    private func detectAnomalies(from dailyData: [DailyMetrics]) async {
        guard dailyData.count >= 5 else { return }
        
        var detectedAnomalies: [TrendAnomaly] = []
        
        // Calculate baselines
        let cpuValues = dailyData.map { $0.avgCPU }
        let tempValues = dailyData.map { $0.avgTemperature }
        
        let cpuMean = cpuValues.reduce(0, +) / Double(cpuValues.count)
        let cpuStdDev = standardDeviation(cpuValues)
        
        let tempMean = tempValues.reduce(0, +) / Double(tempValues.count)
        let tempStdDev = standardDeviation(tempValues)
        
        // Detect anomalies (values > 2 standard deviations from mean)
        for (index, daily) in dailyData.enumerated() {
            // CPU anomaly
            if abs(daily.avgCPU - cpuMean) > 2 * cpuStdDev {
                detectedAnomalies.append(TrendAnomaly(
                    type: .cpuSpike,
                    date: daily.date,
                    value: daily.avgCPU,
                    expectedRange: (cpuMean - cpuStdDev, cpuMean + cpuStdDev),
                    severity: daily.avgCPU > cpuMean ? .high : .medium
                ))
            }
            
            // Temperature anomaly
            if abs(daily.avgTemperature - tempMean) > 2 * tempStdDev && daily.avgTemperature > 0 {
                detectedAnomalies.append(TrendAnomaly(
                    type: .temperatureSpike,
                    date: daily.date,
                    value: daily.avgTemperature,
                    expectedRange: (tempMean - tempStdDev, tempMean + tempStdDev),
                    severity: daily.avgTemperature > 75 ? .high : .medium
                ))
            }
            
            // Check for sudden changes (day-over-day)
            if index > 0 {
                let prevDay = dailyData[index - 1]
                let cpuChange = abs(daily.avgCPU - prevDay.avgCPU)
                
                if cpuChange > 20 { // 20% sudden change
                    detectedAnomalies.append(TrendAnomaly(
                        type: .suddenChange,
                        date: daily.date,
                        value: cpuChange,
                        expectedRange: (0, 10),
                        severity: cpuChange > 30 ? .high : .medium
                    ))
                }
            }
        }
        
        anomalies = detectedAnomalies
    }
    
    // MARK: - Trend Prediction
    
    /// Predict metrics for the next hour based on historical patterns
    func predictNextHour() -> PredictedMetrics? {
        guard !dailyPatterns.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let nextHour = (calendar.component(.hour, from: Date()) + 1) % 24
        
        if let pattern = dailyPatterns.first(where: { $0.hour == nextHour }) {
            return PredictedMetrics(
                timestamp: calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
                predictedCPU: pattern.avgCPU,
                predictedMemory: pattern.avgMemory,
                predictedGPU: pattern.avgGPU,
                confidence: calculateConfidence(sampleCount: pattern.sampleCount)
            )
        }
        
        return nil
    }
    
    /// Get usage summary for reporting
    func getUsageSummary(for period: AnalysisPeriod) async -> UsageSummary? {
        let endDate = Date()
        let startDate: Date
        
        switch period {
        case .day:
            startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate) ?? endDate
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        }
        
        let hourlyData = await historyStore.getHourlyAverages(from: startDate, to: endDate)
        
        guard !hourlyData.isEmpty else { return nil }
        
        let cpuValues = hourlyData.map { $0.avgCPU }
        let memValues = hourlyData.map { $0.avgMemory }
        let gpuValues = hourlyData.map { $0.avgGPU }
        let tempValues = hourlyData.map { $0.avgTemperature }
        
        return UsageSummary(
            period: period,
            startDate: startDate,
            endDate: endDate,
            avgCPU: cpuValues.reduce(0, +) / Double(cpuValues.count),
            maxCPU: cpuValues.max() ?? 0,
            minCPU: cpuValues.min() ?? 0,
            avgMemory: memValues.reduce(0, +) / Double(memValues.count),
            maxMemory: memValues.max() ?? 0,
            avgGPU: gpuValues.reduce(0, +) / Double(gpuValues.count),
            maxGPU: gpuValues.max() ?? 0,
            avgTemperature: tempValues.reduce(0, +) / Double(tempValues.count),
            maxTemperature: tempValues.max() ?? 0,
            sampleCount: hourlyData.reduce(0) { $0 + $1.sampleCount }
        )
    }
    
    // MARK: - Helpers
    
    private func isGrowingTrend(_ values: [Double]) -> Bool {
        guard values.count >= 5 else { return false }
        
        var increases = 0
        for i in 1..<values.count {
            if values[i] > values[i-1] { increases += 1 }
        }
        
        return Double(increases) / Double(values.count - 1) > 0.6
    }
    
    private func calculateGrowthRate(_ values: [Double]) -> Double {
        guard values.count >= 2, let first = values.first, first > 0 else { return 0 }
        
        let last = values.last ?? first
        let days = Double(values.count)
        
        return (last - first) / first / days
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    private func calculateConfidence(sampleCount: Int) -> Double {
        // More samples = higher confidence, capped at 0.95
        return min(0.95, Double(sampleCount) / 30.0)
    }
}

// MARK: - Data Models

/// Pattern for a specific hour of the day
struct DailyPattern: Identifiable {
    var id: Int { hour }
    let hour: Int
    let avgCPU: Double
    let avgMemory: Double
    let avgGPU: Double
    let sampleCount: Int
    
    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}

/// Pattern for a specific day of the week
struct WeeklyPattern: Identifiable {
    var id: Int { weekday }
    let weekday: Int  // 1 = Sunday, 7 = Saturday
    let avgCPU: Double
    let avgMemory: Double
    let avgGPU: Double
    let sampleCount: Int
    
    var weekdayName: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[weekday - 1]
    }
    
    var shortName: String {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols[weekday - 1]
    }
}

/// Detected anomaly in metrics
struct TrendAnomaly: Identifiable {
    let id = UUID()
    let type: AnomalyType
    let date: Date
    let value: Double
    let expectedRange: (min: Double, max: Double)
    let severity: Severity
    
    enum AnomalyType: String {
        case cpuSpike = "CPU Spike"
        case memorySpike = "Memory Spike"
        case temperatureSpike = "Temperature Spike"
        case suddenChange = "Sudden Change"
    }
    
    enum Severity: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
}

/// Suspected memory leak
struct MemoryLeakSuspect: Identifiable {
    let id = UUID()
    let type: LeakType
    let description: String
    let growthRatePerDay: Double
    let confidence: Double
    let detectedAt: Date
    
    enum LeakType {
        case gradualGrowth
        case suddenJump
        case processSpecific(String)
    }
}

/// Predicted metrics
struct PredictedMetrics {
    let timestamp: Date
    let predictedCPU: Double
    let predictedMemory: Double
    let predictedGPU: Double
    let confidence: Double
}

/// Analysis period
enum AnalysisPeriod: String, CaseIterable {
    case day = "24 Hours"
    case week = "7 Days"
    case month = "30 Days"
}

/// Usage summary for a period
struct UsageSummary {
    let period: AnalysisPeriod
    let startDate: Date
    let endDate: Date
    let avgCPU: Double
    let maxCPU: Double
    let minCPU: Double
    let avgMemory: Double
    let maxMemory: Double
    let avgGPU: Double
    let maxGPU: Double
    let avgTemperature: Double
    let maxTemperature: Double
    let sampleCount: Int
}
