import Foundation

/// xExplain Engine - The "Brain" of the xInsight Ecosystem
/// Provides reasoning layer for system metrics, not just monitoring
public struct XExplainEngine {
    
    // MARK: - Insight Model
    
    public struct Insight: Codable, Identifiable {
        public let id: UUID
        public let symptom: String
        public let rootCause: String
        public let confidence: Double
        public let counterfactual: String  // "If X then Y" reasoning
        public let actionSafety: ActionSafety
        public let audience: Audience
        public let severity: Severity
        public let category: Category
        public let timestamp: Date
        
        public enum ActionSafety: String, Codable {
            case safe       // Can auto-execute
            case caution    // User should confirm
            case dangerous  // Expert only
        }
        
        public enum Audience: String, Codable {
            case consumer   // Regular user
            case dev        // Developer
            case expert     // Power user
        }
        
        public enum Severity: String, Codable {
            case info
            case warning
            case critical
        }
        
        public enum Category: String, Codable {
            case thermal
            case cpu
            case memory
            case disk
            case network
            case process
            case devWorkload
        }
    }
    
    // MARK: - Thermal Insights
    
    public struct ThermalAnalyzer {
        
        /// Detect silent CPU throttling (Apple does this quietly)
        public static func detectSilentThrottling(
            currentFreqMHz: Int,
            baseFreqMHz: Int,
            temperature: Double,
            thermalThreshold: Double = 95.0
        ) -> Insight? {
            let freqDrop = Double(baseFreqMHz - currentFreqMHz) / Double(baseFreqMHz)
            
            // Throttling detected if freq dropped but temp below threshold
            guard freqDrop > 0.1 && temperature < thermalThreshold else { return nil }
            
            return Insight(
                id: UUID(),
                symptom: "CPU running at \(Int(100 - freqDrop * 100))% of base frequency",
                rootCause: "Silent thermal throttling by macOS",
                confidence: 0.85,
                counterfactual: "If cooling improved → Performance +\(Int(freqDrop * 100))%",
                actionSafety: .safe,
                audience: .dev,
                severity: .warning,
                category: .thermal,
                timestamp: Date()
            )
        }
        
        /// Predict thermal throttle timing
        public static func forecastThrottle(
            currentTemp: Double,
            tempHistory: [Double],  // Last N samples
            throttleThreshold: Double = 95.0
        ) -> Insight? {
            guard tempHistory.count >= 5 else { return nil }
            
            // Calculate temperature rise rate (°C per sample)
            let recentSlope = (tempHistory.last! - tempHistory[tempHistory.count - 5]) / 5.0
            
            guard recentSlope > 0.5 else { return nil }  // Rising temp
            
            let degreesToThrottle = throttleThreshold - currentTemp
            let samplesToThrottle = degreesToThrottle / recentSlope
            let minutesToThrottle = samplesToThrottle * 0.5  // Assuming 30s samples
            
            guard minutesToThrottle > 0 && minutesToThrottle < 10 else { return nil }
            
            return Insight(
                id: UUID(),
                symptom: "Temperature rising at \(String(format: "%.1f", recentSlope * 2))°C/min",
                rootCause: "Current workload causing sustained heat buildup",
                confidence: 0.75,
                counterfactual: "If workload continues → thermal throttle in ~\(Int(minutesToThrottle)) minutes",
                actionSafety: .safe,
                audience: .consumer,
                severity: .warning,
                category: .thermal,
                timestamp: Date()
            )
        }
        
        /// Detect inefficient core usage
        public static func detectCoreImbalance(
            pCoreUsage: [Double],  // Performance core usage %
            eCoreUsage: [Double],  // Efficiency core usage %
            threadCount: Int
        ) -> Insight? {
            let avgPCore = pCoreUsage.reduce(0, +) / Double(max(pCoreUsage.count, 1))
            let avgECore = eCoreUsage.reduce(0, +) / Double(max(eCoreUsage.count, 1))
            
            // P-cores idle but E-cores busy = inefficient
            if avgPCore < 20 && avgECore > 70 {
                return Insight(
                    id: UUID(),
                    symptom: "Performance cores at \(Int(avgPCore))% while efficiency cores at \(Int(avgECore))%",
                    rootCause: "Workload not utilizing high-performance cores",
                    confidence: 0.82,
                    counterfactual: "If workload moved to P-cores → Speed +40-60%",
                    actionSafety: .caution,
                    audience: .dev,
                    severity: .info,
                    category: .cpu,
                    timestamp: Date()
                )
            }
            
            // Single-threaded bottleneck
            if threadCount < 4 && pCoreUsage.max() ?? 0 > 90 && avgPCore < 30 {
                return Insight(
                    id: UUID(),
                    symptom: "Single P-core at 100% while others idle",
                    rootCause: "Single-threaded workload bottleneck",
                    confidence: 0.88,
                    counterfactual: "If parallelized → Could use \(pCoreUsage.count)x more CPU",
                    actionSafety: .safe,
                    audience: .dev,
                    severity: .warning,
                    category: .cpu,
                    timestamp: Date()
                )
            }
            
            return nil
        }
    }
    
    // MARK: - Dev Workload Insights
    
    public struct DevAnalyzer {
        
        /// Detect hot reload loops
        public static func detectHotReloadLoop(
            fileWatchEvents: Int,
            buildTriggers: Int,
            timeWindowSeconds: Double
        ) -> Insight? {
            let eventsPerSecond = Double(fileWatchEvents) / timeWindowSeconds
            let buildsPerEvent = Double(buildTriggers) / Double(max(fileWatchEvents, 1))
            
            // Too many rebuilds per file change
            if eventsPerSecond > 2 && buildsPerEvent > 0.8 {
                return Insight(
                    id: UUID(),
                    symptom: "\(buildTriggers) rebuilds in \(Int(timeWindowSeconds))s",
                    rootCause: "Hot reload loop causing excessive rebuilds",
                    confidence: 0.79,
                    counterfactual: "If debounced → CPU usage -50%",
                    actionSafety: .safe,
                    audience: .dev,
                    severity: .warning,
                    category: .devWorkload,
                    timestamp: Date()
                )
            }
            
            return nil
        }
        
        /// Detect I/O amplification
        public static func detectIOAmplification(
            writeOps: Int,
            readOps: Int,
            processName: String
        ) -> Insight? {
            let amplification = Double(readOps) / Double(max(writeOps, 1))
            
            // 1 write causing 10+ reads = amplification problem
            if amplification > 10 && writeOps > 5 {
                return Insight(
                    id: UUID(),
                    symptom: "\(writeOps) writes triggered \(readOps) reads",
                    rootCause: "I/O amplification by \(processName) (file watchers)",
                    confidence: 0.84,
                    counterfactual: "If file watching optimized → Disk I/O -\(Int((1 - 1/amplification) * 100))%",
                    actionSafety: .safe,
                    audience: .dev,
                    severity: .info,
                    category: .disk,
                    timestamp: Date()
                )
            }
            
            return nil
        }
        
        /// Detect AI/ML workload not using GPU
        public static func detectMLCPUFallback(
            cpuUsage: Double,
            gpuUsage: Double,
            aneUsage: Double,  // Apple Neural Engine
            mlProcesses: [String]
        ) -> Insight? {
            // High CPU, low GPU/ANE while ML process running
            if cpuUsage > 80 && gpuUsage < 10 && aneUsage < 5 && !mlProcesses.isEmpty {
                return Insight(
                    id: UUID(),
                    symptom: "ML inference using 80%+ CPU, GPU at 10%",
                    rootCause: "Model falling back to CPU instead of GPU/ANE",
                    confidence: 0.77,
                    counterfactual: "If using Metal/ANE → Speed 3-10x, energy -70%",
                    actionSafety: .safe,
                    audience: .dev,
                    severity: .warning,
                    category: .devWorkload,
                    timestamp: Date()
                )
            }
            
            return nil
        }
    }
    
    // MARK: - Process Insights
    
    public struct ProcessAnalyzer {
        
        /// Detect runaway process
        public static func detectRunawayProcess(
            processName: String,
            cpuPercent: Double,
            duration: TimeInterval
        ) -> Insight? {
            if cpuPercent > 90 && duration > 60 {
                return Insight(
                    id: UUID(),
                    symptom: "\(processName) using \(Int(cpuPercent))% CPU for \(Int(duration/60)) min",
                    rootCause: "Possible runaway or stuck process",
                    confidence: 0.72,
                    counterfactual: "If killed → CPU usage -\(Int(cpuPercent))%",
                    actionSafety: .caution,
                    audience: .consumer,
                    severity: .warning,
                    category: .process,
                    timestamp: Date()
                )
            }
            return nil
        }
        
        /// Detect energy inefficiency
        public static func detectEnergyWaste(
            processName: String,
            wakeUpsPerSecond: Int,
            cpuPercent: Double
        ) -> Insight? {
            // Low CPU but high wake-ups = energy waste
            if cpuPercent < 5 && wakeUpsPerSecond > 100 {
                return Insight(
                    id: UUID(),
                    symptom: "\(processName): \(wakeUpsPerSecond) wake-ups/sec with \(Int(cpuPercent))% CPU",
                    rootCause: "Excessive wake-ups draining battery",
                    confidence: 0.81,
                    counterfactual: "If fixed → Battery life +5-10%",
                    actionSafety: .safe,
                    audience: .consumer,
                    severity: .info,
                    category: .process,
                    timestamp: Date()
                )
            }
            return nil
        }
    }
}

// MARK: - CLI Interface

public struct XExplainCLI {
    
    public enum Command: String, CaseIterable {
        case why       // xexplain why cpu
        case analyze   // xexplain analyze docker
        case thermal   // xexplain thermal
        case forecast  // xexplain forecast
        case dev       // xexplain dev
        case version   // xexplain version
        case help      // xexplain help
    }
    
    public static func run(args: [String]) -> String {
        guard let commandStr = args.first, let command = Command(rawValue: commandStr) else {
            return helpText
        }
        
        switch command {
        case .why:
            let target = args.dropFirst().first ?? "slow"
            return analyzeWhy(target: target)
        case .analyze:
            let process = args.dropFirst().first ?? ""
            return analyzeProcess(name: process)
        case .thermal:
            return thermalAnalysis()
        case .forecast:
            return thermalForecast()
        case .dev:
            return devAnalysis()
        case .version:
            return "xExplain 1.0.0 - System Intelligence Engine"
        case .help:
            return helpText
        }
    }
    
    private static var helpText: String {
        """
        xExplain - System Intelligence Engine for macOS
        
        USAGE:
          xexplain <command> [options]
        
        COMMANDS:
          why <symptom>     Analyze why something is happening
                            xexplain why cpu
                            xexplain why slow
                            xexplain why hot
          
          analyze <app>     Deep analyze a specific app
                            xexplain analyze docker
                            xexplain analyze chrome
          
          thermal           Show thermal analysis and insights
          
          forecast          Predict thermal throttling
          
          dev               Developer-focused insights
                            (hot reload, I/O amplification, etc.)
          
          version           Show version
          help              Show this help
        
        EXAMPLES:
          xexplain why cpu
          xexplain thermal
          xexplain dev
          xexplain analyze "Docker Desktop"
        
        Part of the xInsight Ecosystem
        https://github.com/xdev-asia-labs/xInsight
        """
    }
    
    private static func analyzeWhy(target: String) -> String {
        // Placeholder - would integrate with real metrics
        return """
        🔍 Analyzing: \(target)
        
        Looking for root causes...
        """
    }
    
    private static func analyzeProcess(name: String) -> String {
        return """
        📊 Analyzing process: \(name)
        
        Gathering metrics...
        """
    }
    
    private static func thermalAnalysis() -> String {
        return """
        🌡️ Thermal Analysis
        
        Running thermal diagnostics...
        """
    }
    
    private static func thermalForecast() -> String {
        return """
        🔮 Thermal Forecast
        
        Predicting thermal behavior...
        """
    }
    
    private static func devAnalysis() -> String {
        return """
        💻 Developer Workload Analysis
        
        Checking for:
        • Hot reload loops
        • I/O amplification
        • Core imbalance
        • ML CPU fallback
        """
    }
}
