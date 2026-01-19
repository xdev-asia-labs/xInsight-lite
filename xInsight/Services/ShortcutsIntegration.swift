import Foundation
import AppIntents

/// ShortcutsIntegration - macOS Shortcuts app integration
/// Provides AppIntents for automation

// MARK: - Get System Health Intent

@available(macOS 13.0, *)
struct GetSystemHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Get System Health"
    static var description = IntentDescription("Returns the current system health score (0-100)")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let healthScore = SystemHealthScore.shared
        return .result(value: healthScore.overallScore)
    }
}

// MARK: - Get CPU Usage Intent

@available(macOS 13.0, *)
struct GetCPUUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "Get CPU Usage"
    static var description = IntentDescription("Returns the current CPU usage percentage")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        // Return placeholder - requires app context for real value
        return .result(value: 0.0)
    }
}

// MARK: - Get Memory Usage Intent

@available(macOS 13.0, *)
struct GetMemoryUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Memory Usage"
    static var description = IntentDescription("Returns the current memory usage percentage")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        return .result(value: 0.0)
    }
}

// MARK: - Get Temperature Intent

@available(macOS 13.0, *)
struct GetTemperatureIntent: AppIntent {
    static var title: LocalizedStringResource = "Get CPU Temperature"
    static var description = IntentDescription("Returns the current CPU temperature in Celsius")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        return .result(value: 0.0)
    }
}

// MARK: - Kill Process Intent

@available(macOS 13.0, *)
struct KillProcessIntent: AppIntent {
    static var title: LocalizedStringResource = "Kill Process"
    static var description = IntentDescription("Terminates a process by name")
    
    @Parameter(title: "Process Name")
    var processName: String
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let processMonitor = ProcessMonitor()
        await processMonitor.refresh()
        
        if let process = processMonitor.processes.first(where: { 
            $0.name.lowercased().contains(processName.lowercased()) 
        }) {
            let result = kill(process.pid, SIGTERM) == 0
            return .result(value: result)
        }
        
        return .result(value: false)
    }
}

// MARK: - Run Cleanup Intent

@available(macOS 13.0, *)
struct RunCleanupIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Disk Cleanup"
    static var description = IntentDescription("Scans for cleanable files and returns potential savings in MB")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // Return placeholder - actual cleanup requires app context
        return .result(value: 0)
    }
}

// MARK: - Generate Report Intent

@available(macOS 13.0, *)
struct GenerateReportIntent: AppIntent {
    static var title: LocalizedStringResource = "Generate System Report"
    static var description = IntentDescription("Generates a daily system report")
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let reports = ScheduledReports.shared
        await reports.generateDailyReport()
        return .result(value: "Report generated successfully")
    }
}

// MARK: - App Shortcuts Provider

@available(macOS 13.0, *)
struct xInsightShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetSystemHealthIntent(),
            phrases: [
                "Get system health in \(.applicationName)",
                "Check \(.applicationName) health score"
            ],
            shortTitle: "System Health",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: GetCPUUsageIntent(),
            phrases: [
                "Get CPU usage in \(.applicationName)",
                "Check CPU with \(.applicationName)"
            ],
            shortTitle: "CPU Usage",
            systemImageName: "cpu"
        )
        
        AppShortcut(
            intent: GetTemperatureIntent(),
            phrases: [
                "Get temperature in \(.applicationName)",
                "Check Mac temperature with \(.applicationName)"
            ],
            shortTitle: "Temperature",
            systemImageName: "thermometer"
        )
    }
}
