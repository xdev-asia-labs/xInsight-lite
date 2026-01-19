import Foundation
import ServiceManagement
import AppKit

/// Service to manage startup/login items
final class StartupManager: ObservableObject {
    static let shared = StartupManager()
    
    @Published var loginItems: [LoginItem] = []
    @Published var launchAgents: [LaunchAgent] = []
    @Published var isScanning: Bool = false
    
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
        
        // Scan launch agents
        await scanLaunchAgents()
    }
    
    // MARK: - Launch Agents
    
    private func scanLaunchAgents() async {
        var agents: [LaunchAgent] = []
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let launchAgentPaths = [
            homeDir.appendingPathComponent("Library/LaunchAgents"),
            URL(fileURLWithPath: "/Library/LaunchAgents"),
        ]
        
        for launchPath in launchAgentPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: launchPath,
                includingPropertiesForKeys: nil
            ) else { continue }
            
            for fileURL in contents where fileURL.pathExtension == "plist" {
                if let agent = parseLaunchAgent(at: fileURL, userLevel: launchPath.path.contains("~") || launchPath.path.contains(homeDir.path)) {
                    agents.append(agent)
                }
            }
        }
        
        // Sort by name
        agents.sort { $0.label.lowercased() < $1.label.lowercased() }
        
        // Make a local copy for MainActor
        let sortedAgents = agents
        
        await MainActor.run {
            launchAgents = sortedAgents
        }
    }
    
    private func parseLaunchAgent(at url: URL, userLevel: Bool) -> LaunchAgent? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        let program = plist["Program"] as? String ?? (plist["ProgramArguments"] as? [String])?.first ?? ""
        let runAtLoad = plist["RunAtLoad"] as? Bool ?? false
        let keepAlive = plist["KeepAlive"] as? Bool ?? false
        let disabled = plist["Disabled"] as? Bool ?? false
        
        return LaunchAgent(
            label: label,
            path: url.path,
            program: program,
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            isDisabled: disabled,
            isUserLevel: userLevel
        )
    }
    
    // MARK: - Actions
    
    /// Reveal launch agent in Finder
    func revealInFinder(_ agent: LaunchAgent) {
        NSWorkspace.shared.selectFile(agent.path, inFileViewerRootedAtPath: "")
    }
    
    /// Open launch agent plist in editor
    func openInEditor(_ agent: LaunchAgent) {
        NSWorkspace.shared.open(URL(fileURLWithPath: agent.path))
    }
    
    /// Remove launch agent (move to trash)
    @MainActor
    func removeLaunchAgent(_ agent: LaunchAgent) async -> Bool {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: agent.path), resultingItemURL: nil)
            launchAgents.removeAll { $0.id == agent.id }
            return true
        } catch {
            print("Failed to remove launch agent: \(error)")
            return false
        }
    }
    
    /// Get app login items (macOS 13+)
    func getAppLoginItems() -> [String] {
        // Note: SMAppService requires specific entitlements
        // This is a simplified version
        return []
    }
}

// MARK: - Models

struct LoginItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let isHidden: Bool
    var isEnabled: Bool
}

struct LaunchAgent: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let path: String
    let program: String
    let runAtLoad: Bool
    let keepAlive: Bool
    var isDisabled: Bool
    let isUserLevel: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LaunchAgent, rhs: LaunchAgent) -> Bool {
        lhs.id == rhs.id
    }
    
    var displayName: String {
        // Try to get a friendly name from the label
        let parts = label.split(separator: ".")
        if parts.count > 2 {
            return String(parts.suffix(2).joined(separator: "."))
        }
        return label
    }
    
    var category: Category {
        let labelLower = label.lowercased()
        if labelLower.contains("apple") { return .system }
        if labelLower.contains("com.microsoft") { return .microsoft }
        if labelLower.contains("com.adobe") { return .adobe }
        if labelLower.contains("com.google") { return .google }
        return .thirdParty
    }
    
    enum Category: String {
        case system = "System"
        case microsoft = "Microsoft"
        case adobe = "Adobe"
        case google = "Google"
        case thirdParty = "Third Party"
        
        var color: String {
            switch self {
            case .system: return "gray"
            case .microsoft: return "blue"
            case .adobe: return "red"
            case .google: return "green"
            case .thirdParty: return "purple"
            }
        }
    }
}
