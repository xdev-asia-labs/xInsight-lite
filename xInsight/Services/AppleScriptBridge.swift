import Foundation
import Carbon

/// AppleScriptBridge - Enables AppleScript automation for xInsight
/// Provides scriptable objects and commands

// MARK: - Scriptable Application Delegate Protocol

@objc protocol ScriptingSupport {
    @objc optional var cpuUsage: NSNumber { get }
    @objc optional var memoryUsage: NSNumber { get }
    @objc optional var temperature: NSNumber { get }
    @objc optional var healthScore: NSNumber { get }
    @objc optional func killProcess(_ name: String) -> Bool
    @objc optional func runCleanup() -> Bool
    @objc optional func generateReport() -> String?
}

// MARK: - Script Commands

/// Get CPU Usage Command
class GetCPUUsageCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        // Return placeholder - actual value requires app context
        return 0.0
    }
}

/// Get Memory Usage Command
class GetMemoryUsageCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        return 0.0
    }
}

/// Get Temperature Command
class GetTemperatureCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        return 0.0
    }
}

/// Get Health Score Command
class GetHealthScoreCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        return SystemHealthScore.shared.overallScore
    }
}

/// Kill Process Command
class KillProcessCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        guard let processName = directParameter as? String else {
            return false
        }
        
        let processMonitor = ProcessMonitor()
        
        // Find and kill process
        if let process = processMonitor.processes.first(where: { 
            $0.name.lowercased().contains(processName.lowercased()) 
        }) {
            return kill(process.pid, SIGTERM) == 0
        }
        
        return false
    }
}

/// Generate Report Command
class GenerateReportCommand: NSScriptCommand {
    @MainActor
    override func performDefaultImplementation() -> Any? {
        let tempDir = FileManager.default.temporaryDirectory
        let reportPath = tempDir.appendingPathComponent("xInsight_Report_\(Date().timeIntervalSince1970).html")
        return reportPath.path
    }
}

// MARK: - AppleScript Helper

@MainActor
final class AppleScriptBridge: ObservableObject {
    static let shared = AppleScriptBridge()
    
    private init() {}
    
    /// Example AppleScript to get CPU usage
    var exampleScripts: [ScriptExample] {
        [
            ScriptExample(
                name: "Get CPU Usage",
                script: """
                tell application "xInsight"
                    get cpu usage
                end tell
                """
            ),
            ScriptExample(
                name: "Get Health Score",
                script: """
                tell application "xInsight"
                    get health score
                end tell
                """
            ),
            ScriptExample(
                name: "Kill Process",
                script: """
                tell application "xInsight"
                    kill process "Safari"
                end tell
                """
            ),
            ScriptExample(
                name: "Check and Alert",
                script: """
                tell application "xInsight"
                    set cpuLevel to cpu usage
                    if cpuLevel > 80 then
                        display notification "High CPU: " & cpuLevel & "%" with title "xInsight Alert"
                    end if
                end tell
                """
            )
        ]
    }
    
    /// Execute AppleScript
    func executeScript(_ script: String) -> (success: Bool, result: String) {
        var error: NSDictionary?
        
        if let scriptObject = NSAppleScript(source: script) {
            if let output = scriptObject.executeAndReturnError(&error).stringValue {
                return (true, output)
            }
        }
        
        if let error = error {
            return (false, error.description)
        }
        
        return (false, "Unknown error")
    }
}

// MARK: - Models

struct ScriptExample: Identifiable {
    let id = UUID()
    let name: String
    let script: String
}
