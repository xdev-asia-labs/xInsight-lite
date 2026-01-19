import Foundation

/// Natural Language Query Parser - Lightweight pattern matching without AI/LLM
class QueryParser {
    
    // MARK: - Query Result
    
    struct QueryResult {
        enum Action {
            case navigate(DashboardTab)
            case showProcesses(SortBy)
            case killProcess(String)
            case showInsights(Severity?)
            case executeCommand(Command)
            case unknown(String)
        }
        
        enum SortBy {
            case cpu, memory, disk
        }
        
        enum Command {
            case cleanDisk
            case scanSecurity
            case checkBattery
            case uninstallApp
            case manageStartup
        }
        
        let action: Action
        let confidence: Double
        let originalQuery: String
        let suggestion: String?
    }
    
    // MARK: - Parsing
    
    func parse(_ query: String) -> QueryResult {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try each pattern type in order of specificity
        if let result = matchNavigationQuery(normalized) {
            return result
        }
        
        if let result = matchProcessQuery(normalized) {
            return result
        }
        
        if let result = matchActionQuery(normalized) {
            return result
        }
        
        if let result = matchStatusQuery(normalized) {
            return result
        }
        
        // No match found
        return QueryResult(
            action: .unknown(query),
            confidence: 0.0,
            originalQuery: query,
            suggestion: "Try: 'show cpu', 'what's using memory', 'clean disk'"
        )
    }
    
    // MARK: - Pattern Matching
    
    private func matchNavigationQuery(_ query: String) -> QueryResult? {
        let patterns: [(pattern: String, tab: DashboardTab)] = [
            ("(show|open|go to|display)\\s+(cpu|processor)", .cpuDetail),
            ("(show|open|go to|display)\\s+(memory|ram)", .memoryDetail),
            ("(show|open|go to|display)\\s+(gpu|graphics)", .gpuDetail),
            ("(show|open|go to|display)\\s+disk", .diskDetail),
            ("(show|open|go to|display)\\s+(battery|power)", .batteryHealth),
            ("(show|open|go to|display)\\s+network", .networkTraffic),
            ("(show|open|go to|display)\\s+process", .processes),
            ("(show|open|go to|display)\\s+(insight|issue|problem)", .insights),
            ("(show|open|go to|display)\\s+security", .security),
            ("(show|open|go to|display)\\s+startup", .startupManager),
            ("(show|open|go to|display)\\s+(uninstall|apps)", .uninstaller),
            ("(show|open|go to|display)\\s+overview", .overview),
        ]
        
        for (pattern, tab) in patterns {
            if query.range(of: pattern, options: .regularExpression) != nil {
                return QueryResult(
                    action: .navigate(tab),
                    confidence: 0.9,
                    originalQuery: query,
                    suggestion: nil
                )
            }
        }
        
        return nil
    }
    
    private func matchProcessQuery(_ query: String) -> QueryResult? {
        // "what's using cpu/memory/disk"
        if let match = query.range(of: "what'?s?\\s+using\\s+(cpu|memory|ram|disk)", options: .regularExpression) {
            let type = String(query[match]).components(separatedBy: " ").last ?? "cpu"
            let sortBy: QueryResult.SortBy = type.contains("mem") || type.contains("ram") ? .memory :
                                             type.contains("disk") ? .disk : .cpu
            
            return QueryResult(
                action: .showProcesses(sortBy),
                confidence: 0.85,
                originalQuery: query,
                suggestion: nil
            )
        }
        
        // "top cpu/memory processes"
        if let match = query.range(of: "top\\s+(cpu|memory|disk)\\s+process", options: .regularExpression) {
            let type = String(query[match]).components(separatedBy: " ")[1]
            let sortBy: QueryResult.SortBy = type.contains("mem") ? .memory :
                                             type.contains("disk") ? .disk : .cpu
            
            return QueryResult(
                action: .showProcesses(sortBy),
                confidence: 0.85,
                originalQuery: query,
                suggestion: nil
            )
        }
        
        // "kill [process]"
        if let match = query.range(of: "kill\\s+(.+)", options: .regularExpression) {
            let processName = String(query[match]).replacingOccurrences(of: "kill ", with: "")
            
            return QueryResult(
                action: .killProcess(processName),
                confidence: 0.7,
                originalQuery: query,
                suggestion: "Navigate to Processes tab to kill '\(processName)'"
            )
        }
        
        return nil
    }
    
    private func matchActionQuery(_ query: String) -> QueryResult? {
        let patterns: [(pattern: String, command: QueryResult.Command)] = [
            ("clean\\s+(disk|cache)", .cleanDisk),
            ("scan\\s+security", .scanSecurity),
            ("check\\s+battery", .checkBattery),
            ("uninstall\\s+app", .uninstallApp),
            ("manage\\s+startup", .manageStartup),
        ]
        
        for (pattern, command) in patterns {
            if query.range(of: pattern, options: .regularExpression) != nil {
                return QueryResult(
                    action: .executeCommand(command),
                    confidence: 0.8,
                    originalQuery: query,
                    suggestion: nil
                )
            }
        }
        
        return nil
    }
    
    private func matchStatusQuery(_ query: String) -> QueryResult? {
        // "why slow/hot/lagging"
        if query.range(of: "why\\s+(slow|hot|lag)", options: .regularExpression) != nil {
            return QueryResult(
                action: .showInsights(nil),
                confidence: 0.75,
                originalQuery: query,
                suggestion: nil
            )
        }
        
        // "system status"
        if query.range(of: "system\\s+status", options: .regularExpression) != nil {
            return QueryResult(
                action: .navigate(.overview),
                confidence: 0.8,
                originalQuery: query,
                suggestion: nil
            )
        }
        
        // "what's wrong"
        if query.range(of: "what'?s?\\s+(wrong|problem)", options: .regularExpression) != nil {
            return QueryResult(
                action: .showInsights(.critical),
                confidence: 0.7,
                originalQuery: query,
                suggestion: nil
            )
        }
        
        return nil
    }
}

// MARK: - DashboardTab Extension

extension DashboardTab {
    var displayName: String {
        switch self {
        case .overview: return "Overview"
        case .cpuDetail: return "CPU Details"
        case .hardwareInfo: return "Hardware Info"
        case .memoryDetail: return "Memory Details"
        case .gpuDetail: return "GPU Details"
        case .diskDetail: return "Disk Details"
        case .networkTraffic: return "Network Traffic"
        case .batteryHealth: return "Battery Health"
        case .processes: return "Processes"
        case .processTimeline: return "Process Timeline"
        case .ports: return "Ports"
        case .aiDashboard: return "AI Dashboard"
        case .trends: return "Trends"
        case .comparison: return "Comparison"
        case .benchmark: return "Benchmark"
        case .insights: return "Insights"
        case .cleanup: return "Cleanup"
        case .uninstaller: return "Uninstaller"
        case .startupManager: return "Startup Manager"
        case .security: return "Security"
        case .docker: return "Docker"
        case .homebrew: return "Homebrew"
        case .thermal: return "xThermal"
        case .settings: return "Settings"
        }
    }
}
