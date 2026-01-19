import Foundation
import AppKit

/// Service to check for app updates from GitHub releases
final class VersionCheckService: ObservableObject {
    static let shared = VersionCheckService()
    
    @Published var currentVersion: String = "1.0.0"
    @Published var latestVersion: String?
    @Published var downloadURL: URL?
    @Published var hasUpdate: Bool = false
    @Published var isChecking: Bool = false
    
    private let githubRepo = "xdev-asia-labs/xInsight"
    private let releasesAPIURL: URL
    
    private init() {
        self.releasesAPIURL = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest")!
        loadCurrentVersion()
    }
    
    /// Load current version from Bundle
    private func loadCurrentVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            currentVersion = version
        }
    }
    
    /// Check for updates from GitHub releases
    @MainActor
    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }
        
        do {
            var request = URLRequest(url: releasesAPIURL)
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("Failed to fetch releases: Invalid response")
                return
            }
            
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            // Extract version from tag (remove 'v' prefix if present)
            let version = release.tagName.hasPrefix("v") 
                ? String(release.tagName.dropFirst()) 
                : release.tagName
            
            latestVersion = version
            
            // Find DMG asset
            if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                downloadURL = URL(string: dmgAsset.browserDownloadURL)
            } else {
                // Fallback to release page
                downloadURL = URL(string: release.htmlURL)
            }
            
            // Compare versions
            hasUpdate = isNewerVersion(version, than: currentVersion)
            
            if hasUpdate {
                print("🆕 Update available: v\(version)")
            } else {
                print("✅ App is up to date (v\(currentVersion))")
            }
            
        } catch {
            print("Error checking for updates: \(error)")
        }
    }
    
    /// Compare semantic versions
    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(newComponents.count, currentComponents.count) {
            let newPart = i < newComponents.count ? newComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            
            if newPart > currentPart { return true }
            if newPart < currentPart { return false }
        }
        
        return false
    }
    
    /// Open download URL in browser
    func openDownloadPage() {
        guard let url = downloadURL else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let htmlURL: String
    let assets: [GitHubAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
