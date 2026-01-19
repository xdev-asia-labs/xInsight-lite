import Foundation
import AppKit

/// Service to check system security status
final class SecurityScanner: ObservableObject {
    static let shared = SecurityScanner()
    
    @Published var securityStatus: SecurityStatus = SecurityStatus()
    @Published var isScanning: Bool = false
    @Published var suspiciousItems: [SuspiciousItem] = []
    
    private init() {
        Task {
            await scan()
        }
    }
    
    // MARK: - Scan
    
    @MainActor
    func scan() async {
        isScanning = true
        defer { isScanning = false }
        
        // Check SIP status
        let sipEnabled = await checkSIPStatus()
        
        // Check Gatekeeper
        let gatekeeperEnabled = await checkGatekeeperStatus()
        
        // Check FileVault
        let fileVaultEnabled = await checkFileVaultStatus()
        
        // Check Firewall
        let firewallEnabled = await checkFirewallStatus()
        
        // Scan for suspicious launch agents
        let suspicious = await scanSuspiciousItems()
        
        securityStatus = SecurityStatus(
            sipEnabled: sipEnabled,
            gatekeeperEnabled: gatekeeperEnabled,
            fileVaultEnabled: fileVaultEnabled,
            firewallEnabled: firewallEnabled
        )
        
        suspiciousItems = suspicious
    }
    
    // MARK: - Security Checks
    
    private func checkSIPStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
                task.arguments = ["status"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // "System Integrity Protection status: enabled."
                        continuation.resume(returning: output.contains("enabled"))
                    } else {
                        continuation.resume(returning: true) // Assume enabled if can't check
                    }
                } catch {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func checkGatekeeperStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
                task.arguments = ["--status"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // "assessments enabled"
                        continuation.resume(returning: output.contains("enabled"))
                    } else {
                        continuation.resume(returning: true)
                    }
                } catch {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    private func checkFileVaultStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
                task.arguments = ["status"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // "FileVault is On."
                        continuation.resume(returning: output.contains("On"))
                    } else {
                        continuation.resume(returning: false)
                    }
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func checkFirewallStatus() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
                task.arguments = ["--getglobalstate"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        // "Firewall is enabled."
                        continuation.resume(returning: output.contains("enabled"))
                    } else {
                        continuation.resume(returning: false)
                    }
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Suspicious Items
    
    private func scanSuspiciousItems() async -> [SuspiciousItem] {
        var items: [SuspiciousItem] = []
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let suspiciousPaths = [
            homeDir.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchDaemons"),
        ]
        
        // Known suspicious patterns
        let suspiciousPatterns = [
            "adware", "malware", "virus", "keylog", "spyware",
            "mackeeper", "cleanup", "optimizer", "booster"
        ]
        
        for searchPath in suspiciousPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: searchPath,
                includingPropertiesForKeys: nil
            ) else { continue }
            
            for fileURL in contents where fileURL.pathExtension == "plist" {
                let filename = fileURL.lastPathComponent.lowercased()
                
                for pattern in suspiciousPatterns {
                    if filename.contains(pattern) {
                        items.append(SuspiciousItem(
                            name: fileURL.lastPathComponent,
                            path: fileURL.path,
                            reason: "Contains suspicious pattern: \(pattern)",
                            severity: .warning
                        ))
                        break
                    }
                }
            }
        }
        
        return items
    }
    
    // MARK: - Actions
    
    func openSecurityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func revealInFinder(_ item: SuspiciousItem) {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Models

struct SecurityStatus {
    var sipEnabled: Bool = true
    var gatekeeperEnabled: Bool = true
    var fileVaultEnabled: Bool = false
    var firewallEnabled: Bool = false
    
    var overallScore: Int {
        var score = 0
        if sipEnabled { score += 25 }
        if gatekeeperEnabled { score += 25 }
        if fileVaultEnabled { score += 25 }
        if firewallEnabled { score += 25 }
        return score
    }
    
    var overallStatus: String {
        if overallScore >= 100 { return "Excellent" }
        if overallScore >= 75 { return "Good" }
        if overallScore >= 50 { return "Fair" }
        return "At Risk"
    }
    
    var overallColor: String {
        if overallScore >= 100 { return "green" }
        if overallScore >= 75 { return "blue" }
        if overallScore >= 50 { return "orange" }
        return "red"
    }
}

struct SuspiciousItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let reason: String
    let severity: Severity
    
    enum Severity: String {
        case info = "Info"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
}
