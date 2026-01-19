import Foundation
import Combine

/// Homebrew Package Manager Service
/// Manages Homebrew packages, casks, and updates
@MainActor
final class HomebrewManager: ObservableObject {
    static let shared = HomebrewManager()
    
    // MARK: - Published Properties
    @Published var isBrewInstalled = false
    @Published var packages: [BrewPackage] = []
    @Published var casks: [BrewCask] = []
    @Published var outdatedPackages: [String] = []
    @Published var outdatedCasks: [String] = []
    @Published var isLoading = false
    @Published var isUpdating = false
    @Published var lastError: String?
    @Published var brewVersion: String = ""
    
    private init() {
        checkBrewStatus()
    }
    
    // MARK: - Brew Status
    
    func checkBrewStatus() {
        Task {
            isBrewInstalled = await checkBrewInstalled()
            if isBrewInstalled {
                brewVersion = await getBrewVersion()
                await refreshAll()
            }
        }
    }
    
    private func checkBrewInstalled() async -> Bool {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        return paths.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }
    
    private func getBrewVersion() async -> String {
        let output = await runBrewCommand(["--version"])
        return output?.components(separatedBy: "\n").first ?? ""
    }
    
    // MARK: - Refresh
    
    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshPackages() }
            group.addTask { await self.refreshCasks() }
            group.addTask { await self.refreshOutdated() }
        }
    }
    
    func refreshPackages() async {
        guard let output = await runBrewCommand(["list", "--formula", "--versions"]) else { return }
        
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        packages = lines.map { line -> BrewPackage in
            let parts = line.components(separatedBy: " ")
            let name = parts.first ?? line
            let version = parts.count > 1 ? parts[1] : ""
            return BrewPackage(name: name, version: version, isOutdated: outdatedPackages.contains(name))
        }
    }
    
    func refreshCasks() async {
        guard let output = await runBrewCommand(["list", "--cask", "--versions"]) else { return }
        
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        casks = lines.map { line -> BrewCask in
            let parts = line.components(separatedBy: " ")
            let name = parts.first ?? line
            let version = parts.count > 1 ? parts[1] : ""
            return BrewCask(name: name, version: version, isOutdated: outdatedCasks.contains(name))
        }
    }
    
    func refreshOutdated() async {
        // Outdated formulas
        if let output = await runBrewCommand(["outdated", "--formula", "-q"]) {
            outdatedPackages = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        
        // Outdated casks
        if let output = await runBrewCommand(["outdated", "--cask", "-q"]) {
            outdatedCasks = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        
        // Update package/cask outdated status
        packages = packages.map { pkg in
            var p = pkg
            p.isOutdated = outdatedPackages.contains(pkg.name)
            return p
        }
        casks = casks.map { cask in
            var c = cask
            c.isOutdated = outdatedCasks.contains(cask.name)
            return c
        }
    }
    
    // MARK: - Package Actions
    
    func installPackage(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["install", name])
        await refreshPackages()
        
        return (output != nil, output ?? "Installation failed")
    }
    
    func uninstallPackage(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["uninstall", name])
        await refreshPackages()
        
        return (output != nil, output ?? "Uninstallation failed")
    }
    
    func upgradePackage(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["upgrade", name])
        await refreshAll()
        
        return (output != nil, output ?? "Upgrade failed")
    }
    
    func upgradeAllPackages() async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["upgrade"])
        await refreshAll()
        
        return (output != nil, output ?? "Upgrade failed")
    }
    
    // MARK: - Cask Actions
    
    func installCask(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["install", "--cask", name])
        await refreshCasks()
        
        return (output != nil, output ?? "Installation failed")
    }
    
    func uninstallCask(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["uninstall", "--cask", name])
        await refreshCasks()
        
        return (output != nil, output ?? "Uninstallation failed")
    }
    
    func upgradeCask(_ name: String) async -> (success: Bool, message: String) {
        isUpdating = true
        defer { isUpdating = false }
        
        let output = await runBrewCommand(["upgrade", "--cask", name])
        await refreshAll()
        
        return (output != nil, output ?? "Upgrade failed")
    }
    
    // MARK: - Maintenance
    
    func updateBrew() async -> String {
        isUpdating = true
        defer { isUpdating = false }
        
        return await runBrewCommand(["update"]) ?? "Update failed"
    }
    
    func cleanup() async -> String {
        isUpdating = true
        defer { isUpdating = false }
        
        return await runBrewCommand(["cleanup", "-s"]) ?? "Cleanup failed"
    }
    
    func doctor() async -> String {
        return await runBrewCommand(["doctor"]) ?? "Doctor check failed"
    }
    
    func getInfo(_ name: String) async -> String {
        return await runBrewCommand(["info", name]) ?? "Info not available"
    }
    
    func search(_ query: String) async -> [String] {
        guard let output = await runBrewCommand(["search", query]) else { return [] }
        return output.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.starts(with: "==>") }
    }
    
    // MARK: - Stats
    
    var totalPackages: Int { packages.count + casks.count }
    var totalOutdated: Int { outdatedPackages.count + outdatedCasks.count }
    
    // MARK: - Helper
    
    private func runBrewCommand(_ args: [String]) async -> String? {
        let brewPath = findBrewPath()
        guard let path = brewPath else {
            lastError = "Homebrew not found"
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            
            // Set environment for brew
            var env = Foundation.ProcessInfo.processInfo.environment
            env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
            env["HOMEBREW_NO_ANALYTICS"] = "1"
            process.environment = env
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    Task { @MainActor in
                        self.lastError = error
                    }
                }
                
                continuation.resume(returning: output)
            } catch {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func findBrewPath() -> String? {
        let paths = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}

// MARK: - Models

struct BrewPackage: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let version: String
    var isOutdated: Bool
}

struct BrewCask: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let version: String
    var isOutdated: Bool
}
