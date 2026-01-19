import Foundation
import Combine

/// Main AI Insight Engine that analyzes system metrics and generates human-readable insights
@MainActor
class InsightEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentInsights: [Insight] = []
    @Published var currentStatus: SystemStatus = .normal
    @Published var insightHistory: [Insight] = []
    
    // MARK: - Dependencies
    private let correlationEngine = CorrelationEngine()
    private let anomalyDetector = AnomalyDetector()
    
    // MARK: - Rules
    private let rules: [InsightRule] = [
        CPUSaturationRule(),
        MemoryPressureRule(),
        IOBottleneckRule(),
        ThermalThrottlingRule()
    ]
    
    // MARK: - Configuration
    private let insightHistoryLimit = 100
    
    // MARK: - Summary Properties (Lite version)
    @Published var aiSummary: String = ""
    @Published var aiRecommendation: String?
    
    // MARK: - Public Methods
    
    /// Analyze current metrics and processes to generate insights
    func analyze(metrics: SystemMetrics, processes: [ProcessInfo]) {
        // 1. Find correlations between metrics and processes
        let correlations = correlationEngine.correlate(metrics: metrics, processes: processes)
        
        // 2. Detect anomalies in metrics
        let anomalies = anomalyDetector.detect(metrics: metrics)
        
        // 3. Run all insight rules
        var insights: [Insight] = []
        
        for rule in rules {
            if let insight = rule.evaluate(
                metrics: metrics,
                processes: processes,
                correlations: correlations,
                anomalies: anomalies
            ) {
                insights.append(insight)
            }
        }
        
        // 4. Deduplicate insights by type (keep most recent)
        var seenTypes: Set<InsightType> = []
        var uniqueInsights: [Insight] = []
        
        for insight in insights {
            if !seenTypes.contains(insight.type) {
                uniqueInsights.append(insight)
                seenTypes.insert(insight.type)
            }
        }
        
        // 5. Sort by severity (critical first)
        uniqueInsights.sort { $0.severity > $1.severity }
        
        // 6. Update published state
        self.currentInsights = uniqueInsights
        self.currentStatus = calculateOverallStatus(from: uniqueInsights)
        
        // 7. Add to history (avoid duplicates)
        addToHistory(uniqueInsights)
        
        // 8. Generate simple summary (Lite version - no AI)
        self.aiSummary = generateSimpleSummary(metrics: metrics, insights: uniqueInsights)
    }
    
    // MARK: - Private Methods
    
    private func generateSimpleSummary(metrics: SystemMetrics, insights: [Insight]) -> String {
        if insights.isEmpty {
            return L10n.string(.systemNormal)
        }
        return insights.first?.description ?? L10n.string(.systemNormal)
    }
    
    // MARK: - Private Methods
    
    private func calculateOverallStatus(from insights: [Insight]) -> SystemStatus {
        if insights.contains(where: { $0.severity == .critical }) {
            return .critical
        }
        if insights.contains(where: { $0.severity == .warning }) {
            return .warning
        }
        return .normal
    }
    
    private func addToHistory(_ insights: [Insight]) {
        for insight in insights {
            // Check if similar insight already exists recently
            let recentSimilar = insightHistory.suffix(10).contains { existing in
                existing.type == insight.type &&
                Date().timeIntervalSince(existing.timestamp) < 60
            }
            
            if !recentSimilar {
                insightHistory.append(insight)
            }
        }
        
        // Trim history
        if insightHistory.count > insightHistoryLimit {
            insightHistory.removeFirst(insightHistory.count - insightHistoryLimit)
        }
    }
}

// MARK: - Convenience Methods
extension InsightEngine {
    /// Get insights filtered by type
    func insights(ofType type: InsightType) -> [Insight] {
        currentInsights.filter { $0.type == type }
    }
    
    /// Get insights filtered by severity
    func insights(withSeverity severity: Severity) -> [Insight] {
        currentInsights.filter { $0.severity == severity }
    }
    
    /// Get the most critical insight
    var mostCriticalInsight: Insight? {
        currentInsights.first
    }
    
    /// Get a summary string for quick display
    var statusSummary: String {
        if currentInsights.isEmpty {
            return L10n.string(.systemNormal)
        }
        
        let criticalCount = currentInsights.filter { $0.severity == .critical }.count
        let warningCount = currentInsights.filter { $0.severity == .warning }.count
        
        if criticalCount > 0 {
            return "\(criticalCount) \(L10n.string(.systemCritical))"
        }
        if warningCount > 0 {
            return "\(warningCount) \(L10n.string(.systemWarning))"
        }
        
        return "\(currentInsights.count) thông tin"
    }
}
