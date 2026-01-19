import Foundation

/// Disk Cleanup Service - Quét và dọn dẹp các file rác
class DiskCleanup: ObservableObject {
    @Published var scanResults: [CleanupCategory] = []
    @Published var isScanning = false
    @Published var totalCleanableSize: UInt64 = 0
    
    struct CleanupCategory: Identifiable {
        let id = UUID()
        let name: String
        let localizedKey: String
        let icon: String
        let path: String
        var size: UInt64
        var files: [CleanupFile]
        var isSelected: Bool = true
    }
    
    struct CleanupFile: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let size: UInt64
        let modifiedDate: Date
    }
    
    // MARK: - Cleanup Categories
    private let cleanupPaths: [(name: String, localizedKey: String, icon: String, path: String)] = [
        // System
        ("System Caches", "systemCaches", "folder.badge.gearshape", "~/Library/Caches"),
        ("Application Logs", "applicationLogs", "doc.text", "~/Library/Logs"),
        ("Trash", "trash", "trash", "~/.Trash"),
        ("Downloads (30+ days)", "downloads30Days", "arrow.down.circle", "~/Downloads"),
        
        // Browsers
        ("Safari Cache", "safariCache", "safari", "~/Library/Caches/com.apple.Safari"),
        ("Chrome Cache", "chromeCache", "globe", "~/Library/Caches/Google/Chrome"),
        ("Firefox Cache", "firefoxCache", "flame", "~/Library/Caches/Firefox"),
        ("Edge Cache", "edgeCache", "globe", "~/Library/Caches/Microsoft Edge"),
        ("Brave Cache", "braveCache", "shield", "~/Library/Caches/BraveSoftware"),
        
        // Mail
        ("Mail Downloads", "mailDownloads", "envelope", "~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"),
        ("Mail Attachments", "mailAttachments", "paperclip", "~/Library/Mail"),
        
        // Developer
        ("Xcode Derived Data", "xcodeDerivedData", "hammer", "~/Library/Developer/Xcode/DerivedData"),
        ("Xcode Archives", "xcodeArchives", "archivebox", "~/Library/Developer/Xcode/Archives"),
        ("iOS Simulators", "iosSimulators", "iphone", "~/Library/Developer/CoreSimulator/Devices"),
        ("npm Cache", "npmCache", "shippingbox", "~/.npm/_cacache"),
        ("Yarn Cache", "yarnCache", "shippingbox", "~/Library/Caches/Yarn"),
        ("CocoaPods Cache", "cocoapodsCache", "shippingbox", "~/Library/Caches/CocoaPods"),
        ("Gradle Cache", "gradleCache", "shippingbox", "~/.gradle/caches"),
        
        // Docker & Containers
        ("Docker Images", "dockerImages", "server.rack", "~/Library/Containers/com.docker.docker/Data"),
        ("Homebrew Cache", "homebrewCache", "cup.and.saucer", "~/Library/Caches/Homebrew"),
        
        // iOS Backups
        ("iOS Backups", "iosBackups", "iphone.gen3", "~/Library/Application Support/MobileSync/Backup"),
        
        // Screenshots & Screen Recordings
        ("Screenshot Cache", "screenshotCache", "camera.viewfinder", "~/Library/Caches/com.apple.screencaptureui"),
        
        // Misc
        ("Old macOS Updates", "oldMacosUpdates", "arrow.down.app", "/Library/Updates"),
        ("Spotlight Index", "spotlightIndex", "magnifyingglass", "~/.Spotlight-V100")
    ]
    
    // MARK: - Scan
    func scan() async {
        await MainActor.run { isScanning = true }
        
        var categories: [CleanupCategory] = []
        
        for (name, localizedKey, icon, path) in cleanupPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            
            if let (size, files) = await scanDirectory(at: expandedPath, isDownloads: path.contains("Downloads")) {
                if size > 0 {
                    categories.append(CleanupCategory(
                        name: name,
                        localizedKey: localizedKey,
                        icon: icon,
                        path: expandedPath,
                        size: size,
                        files: files
                    ))
                }
            }
        }
        
        // Sort by size (largest first)
        categories.sort { $0.size > $1.size }
        
        // Capture as let for concurrency safety
        let finalCategories = categories
        let totalSize = finalCategories.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        
        await MainActor.run {
            self.scanResults = finalCategories
            self.totalCleanableSize = totalSize
            self.isScanning = false
        }
    }
    
    private func scanDirectory(at path: String, isDownloads: Bool = false) async -> (UInt64, [CleanupFile])? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager.default
                var files: [CleanupFile] = []
                
                guard fileManager.fileExists(atPath: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Use allocatedSize for accurate directory size
                let url = URL(fileURLWithPath: path)
                let totalSize = self.allocatedSizeOfDirectory(at: url)
                
                // Get top-level items for display
                let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .totalFileAllocatedSizeKey]
                
                if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(resourceKeys), options: []) {
                    let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
                    
                    for fileURL in contents.prefix(50) {  // Limit to 50 items for performance
                        guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else { continue }
                        
                        let modDate = resourceValues.contentModificationDate ?? Date()
                        
                        // For Downloads, only include files older than 30 days
                        if isDownloads && modDate > thirtyDaysAgo {
                            continue
                        }
                        
                        let fileSize: UInt64
                        if resourceValues.isDirectory == true {
                            fileSize = self.allocatedSizeOfDirectory(at: fileURL)
                        } else {
                            fileSize = UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0)
                        }
                        
                        files.append(CleanupFile(
                            name: fileURL.lastPathComponent,
                            path: fileURL.path,
                            size: fileSize,
                            modifiedDate: modDate
                        ))
                    }
                }
                
                continuation.resume(returning: (totalSize, files))
            }
        }
    }
    
    /// Calculate allocated size of a directory using `du` command for speed
    private func allocatedSizeOfDirectory(at url: URL) -> UInt64 {
        // Use du command which is much faster than FileManager enumeration
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]  // -s: summary, -k: kilobytes
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Format: "12345\t/path/to/dir"
                let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\t")
                if let sizeKB = UInt64(parts.first ?? "0") {
                    return sizeKB * 1024  // Convert KB to bytes
                }
            }
        } catch {
            // Fallback to quick FileManager scan if du fails
            return quickSizeEstimate(at: url)
        }
        
        return 0
    }
    
    /// Quick size estimate using shallow enumeration
    private func quickSizeEstimate(at url: URL) -> UInt64 {
        let fileManager = FileManager.default
        var totalSize: UInt64 = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        
        for fileURL in contents.prefix(100) {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += UInt64(size)
            }
        }
        
        // Rough estimate: multiply by 10 if directory has many items
        if contents.count > 100 {
            totalSize *= UInt64(contents.count / 100 + 1)
        }
        
        return totalSize
    }
    
    // MARK: - Clean
    func clean(categories: [CleanupCategory]) async -> (cleaned: UInt64, errors: [String]) {
        var totalCleaned: UInt64 = 0
        var errors: [String] = []
        let fileManager = FileManager.default
        
        for category in categories where category.isSelected {
            // Special handling for Trash - use Finder to empty
            if category.path.contains(".Trash") {
                do {
                    let trashURL = URL(fileURLWithPath: category.path)
                    let contents = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
                    for item in contents {
                        try fileManager.removeItem(at: item)
                    }
                    totalCleaned += category.size
                } catch {
                    errors.append("Trash: \(error.localizedDescription)")
                }
                continue
            }
            
            // For other categories, delete individual files
            for file in category.files {
                do {
                    try fileManager.removeItem(atPath: file.path)
                    totalCleaned += file.size
                } catch {
                    errors.append("\(file.name): \(error.localizedDescription)")
                }
            }
        }
        
        // Rescan after cleanup
        await scan()
        
        return (totalCleaned, errors)
    }
    
    // MARK: - Toggle Category
    func toggleCategory(_ category: CleanupCategory) {
        if let index = scanResults.firstIndex(where: { $0.id == category.id }) {
            scanResults[index].isSelected.toggle()
            totalCleanableSize = scanResults.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        }
    }
}

// MARK: - Size Formatting
extension UInt64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
}
