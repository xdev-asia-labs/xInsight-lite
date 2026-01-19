import Foundation
import AppKit

/// Service to scan and uninstall applications with their associated files
final class AppUninstaller: ObservableObject {
    static let shared = AppUninstaller()
    
    @Published var installedApps: [InstalledApp] = []
    @Published var isScanning: Bool = false
    @Published var selectedApp: InstalledApp?
    @Published var relatedFiles: [RelatedFile] = []
    @Published var isFindingFiles: Bool = false
    
    private init() {}
    
    /// Scan /Applications for installed apps
    @MainActor
    func scanInstalledApps() async {
        isScanning = true
        defer { isScanning = false }
        
        var apps: [InstalledApp] = []
        let appDirs = [
            "/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for dir in appDirs {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                if let app = InstalledApp(path: path) {
                    apps.append(app)
                }
            }
        }
        
        // Sort by name
        apps.sort { $0.name.lowercased() < $1.name.lowercased() }
        installedApps = apps
    }
    
    /// Find related files for an app
    @MainActor
    func findRelatedFiles(for app: InstalledApp) async {
        selectedApp = app
        isFindingFiles = true
        defer { isFindingFiles = false }
        
        var files: [RelatedFile] = []
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        // Locations to search
        let searchPaths: [(name: String, path: String, type: RelatedFile.FileType)] = [
            // Application Support
            ("Application Support", homeDir.appendingPathComponent("Library/Application Support").path, .support),
            // Caches
            ("Caches", homeDir.appendingPathComponent("Library/Caches").path, .cache),
            // Preferences
            ("Preferences", homeDir.appendingPathComponent("Library/Preferences").path, .preferences),
            // Containers
            ("Containers", homeDir.appendingPathComponent("Library/Containers").path, .container),
            // Logs
            ("Logs", homeDir.appendingPathComponent("Library/Logs").path, .logs),
            // Saved Application State
            ("Saved State", homeDir.appendingPathComponent("Library/Saved Application State").path, .savedState),
        ]
        
        for (locationName, searchPath, fileType) in searchPaths {
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: searchPath) else { continue }
            
            for item in contents {
                // Match by bundle ID or app name
                let itemLower = item.lowercased()
                let nameLower = app.name.lowercased().replacingOccurrences(of: ".app", with: "")
                let bundleLower = app.bundleIdentifier?.lowercased() ?? ""
                
                if itemLower.contains(nameLower) || (!bundleLower.isEmpty && itemLower.contains(bundleLower)) {
                    let fullPath = "\(searchPath)/\(item)"
                    let size = directorySize(at: fullPath)
                    
                    files.append(RelatedFile(
                        name: item,
                        path: fullPath,
                        size: size,
                        location: locationName,
                        type: fileType,
                        isSelected: true
                    ))
                }
            }
        }
        
        // Sort by size
        files.sort { $0.size > $1.size }
        relatedFiles = files
    }
    
    /// Get total size of selected files
    var totalSelectedSize: UInt64 {
        relatedFiles.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    /// Toggle file selection
    func toggleFile(_ file: RelatedFile) {
        if let index = relatedFiles.firstIndex(where: { $0.id == file.id }) {
            relatedFiles[index].isSelected.toggle()
        }
    }
    
    /// Uninstall the selected app and its files
    @MainActor
    func uninstall() async -> (success: Bool, errors: [String]) {
        guard let app = selectedApp else { return (false, ["No app selected"]) }
        
        var errors: [String] = []
        
        // Move app to trash
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: app.path), resultingItemURL: nil)
        } catch {
            errors.append("Failed to trash app: \(error.localizedDescription)")
        }
        
        // Move related files to trash
        for file in relatedFiles where file.isSelected {
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
            } catch {
                errors.append("Failed to trash \(file.name): \(error.localizedDescription)")
            }
        }
        
        // Refresh app list
        await scanInstalledApps()
        selectedApp = nil
        relatedFiles = []
        
        return (errors.isEmpty, errors)
    }
    
    /// Open app in Finder
    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    // MARK: - Helpers
    
    private func directorySize(at path: String) -> UInt64 {
        var size: UInt64 = 0
        let url = URL(fileURLWithPath: path)
        
        // Check if it's a file or directory
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator.prefix(500) {
                        if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            size += UInt64(fileSize)
                        }
                    }
                }
            } else {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                    size = (attrs[.size] as? UInt64) ?? 0
                }
            }
        }
        
        return size
    }
}

// MARK: - Models

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let bundleIdentifier: String?
    let version: String?
    let icon: NSImage?
    let size: UInt64
    
    init?(path: String) {
        self.path = path
        self.name = (path as NSString).lastPathComponent
        
        let bundle = Bundle(path: path)
        self.bundleIdentifier = bundle?.bundleIdentifier
        self.version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        
        // Get icon
        self.icon = NSWorkspace.shared.icon(forFile: path)
        
        // Get size (simplified - just get app bundle size)
        var size: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator.prefix(1000) {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += UInt64(fileSize)
                }
            }
        }
        self.size = size
    }
}

struct RelatedFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
    let location: String
    let type: FileType
    var isSelected: Bool
    
    enum FileType: String {
        case support = "Application Support"
        case cache = "Cache"
        case preferences = "Preferences"
        case container = "Container"
        case logs = "Logs"
        case savedState = "Saved State"
        
        var icon: String {
            switch self {
            case .support: return "folder.fill"
            case .cache: return "archivebox"
            case .preferences: return "gearshape"
            case .container: return "shippingbox"
            case .logs: return "doc.text"
            case .savedState: return "clock.arrow.circlepath"
            }
        }
        
        var color: String {
            switch self {
            case .support: return "blue"
            case .cache: return "orange"
            case .preferences: return "purple"
            case .container: return "green"
            case .logs: return "gray"
            case .savedState: return "cyan"
            }
        }
    }
}
