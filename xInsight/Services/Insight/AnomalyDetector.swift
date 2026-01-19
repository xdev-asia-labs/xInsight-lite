import Foundation

/// Detects anomalies in system metrics using statistical methods
class AnomalyDetector {
    
    // Rolling statistics for each metric
    private var cpuHistory: RollingStats = RollingStats()
    private var memoryHistory: RollingStats = RollingStats()
    private var diskReadHistory: RollingStats = RollingStats()
    private var diskWriteHistory: RollingStats = RollingStats()
    
    private let deviationThreshold: Double = 2.0  // Standard deviations
    
    /// Detect anomalies in current metrics
    func detect(metrics: SystemMetrics) -> [Anomaly] {
        var anomalies: [Anomaly] = []
        
        // Update history and check for anomalies
        if let anomaly = checkAnomaly(
            metric: "CPU Usage",
            value: metrics.cpuUsage,
            stats: &cpuHistory
        ) {
            anomalies.append(anomaly)
        }
        
        if let anomaly = checkAnomaly(
            metric: "Memory Usage",
            value: metrics.memoryUsagePercent,
            stats: &memoryHistory
        ) {
            anomalies.append(anomaly)
        }
        
        if let anomaly = checkAnomaly(
            metric: "Disk Read",
            value: metrics.diskReadRate,
            stats: &diskReadHistory
        ) {
            anomalies.append(anomaly)
        }
        
        if let anomaly = checkAnomaly(
            metric: "Disk Write",
            value: metrics.diskWriteRate,
            stats: &diskWriteHistory
        ) {
            anomalies.append(anomaly)
        }
        
        return anomalies
    }
    
    private func checkAnomaly(
        metric: String,
        value: Double,
        stats: inout RollingStats
    ) -> Anomaly? {
        // Add value to history
        stats.add(value)
        
        // Need enough data points for meaningful statistics
        guard stats.count >= 10 else { return nil }
        
        let mean = stats.mean
        let stdDev = stats.standardDeviation
        
        // Avoid division by zero
        guard stdDev > 0.1 else { return nil }
        
        let deviation = (value - mean) / stdDev
        
        // Check if value is significantly above normal
        if deviation > deviationThreshold {
            return Anomaly(
                metric: metric,
                currentValue: value,
                expectedValue: mean,
                deviation: deviation
            )
        }
        
        return nil
    }
    
    /// Reset all statistics
    func reset() {
        cpuHistory = RollingStats()
        memoryHistory = RollingStats()
        diskReadHistory = RollingStats()
        diskWriteHistory = RollingStats()
    }
}

// MARK: - Rolling Statistics Helper

/// Maintains rolling statistics for a metric
struct RollingStats {
    private var values: [Double] = []
    private let maxSize: Int = 60  // Keep last 60 samples (2 minutes at 2s interval)
    
    var count: Int { values.count }
    
    var mean: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    var variance: Double {
        guard values.count > 1 else { return 0 }
        let m = mean
        return values.map { pow($0 - m, 2) }.reduce(0, +) / Double(values.count - 1)
    }
    
    var standardDeviation: Double {
        sqrt(variance)
    }
    
    var min: Double {
        values.min() ?? 0
    }
    
    var max: Double {
        values.max() ?? 0
    }
    
    mutating func add(_ value: Double) {
        values.append(value)
        if values.count > maxSize {
            values.removeFirst()
        }
    }
    
    mutating func reset() {
        values.removeAll()
    }
}
