import Foundation
import AppKit

/// Large Files Scanner - Find large files on disk for cleanup
@MainActor
class LargeFilesScanner: ObservableObject {
    static let shared = LargeFilesScanner()
    
    @Published var scanResults: [LargeFile] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var currentPath: String = ""
    @Published var totalScanned: Int = 0
    
    /// Minimum file size to include (default 100MB)
    var minSize: UInt64 = 100_000_000
    
    /// Maximum number of files to return
    var maxResults = 100
    
    struct LargeFile: Identifiable, Equatable, Sendable {
        let id = UUID()
        let name: String
        let path: String
        let size: UInt64
        let modifiedDate: Date
        let fileType: FileType
        var isSelected: Bool = false
        
        enum FileType: String, Sendable {
            case video
            case archive
            case diskImage
            case application
            case other
            
            var icon: String {
                switch self {
                case .video: return "film"
                case .archive: return "archivebox"
                case .diskImage: return "externaldrive"
                case .application: return "app"
                case .other: return "doc"
                }
            }
            
            var color: String {
                switch self {
                case .video: return "purple"
                case .archive: return "orange"
                case .diskImage: return "blue"
                case .application: return "green"
                case .other: return "gray"
                }
            }
        }
        
        static func == (lhs: LargeFile, rhs: LargeFile) -> Bool {
            lhs.path == rhs.path
        }
    }
    
    // Common large file locations to scan
    private let scanPaths: [String] = [
        "~/Downloads",
        "~/Desktop",
        "~/Documents",
        "~/Movies",
        "~/Music",
        "/Applications"
    ]
    
    // MARK: - Scan
    
    func scan() async {
        isScanning = true
        scanProgress = 0
        scanResults = []
        totalScanned = 0
        
        var allFiles: [LargeFile] = []
        let totalPaths = Double(scanPaths.count)
        let capturedMinSize = self.minSize  // Capture for sendable closure
        
        for (index, path) in scanPaths.enumerated() {
            let expandedPath = NSString(string: path).expandingTildeInPath
            currentPath = expandedPath
            
            if let files = await scanDirectory(at: expandedPath, minSize: capturedMinSize) {
                allFiles.append(contentsOf: files)
            }
            
            scanProgress = Double(index + 1) / totalPaths
        }
        
        // Sort by size (largest first) and limit results
        allFiles.sort { $0.size > $1.size }
        scanResults = Array(allFiles.prefix(maxResults))
        
        isScanning = false
        currentPath = ""
    }
    
    private nonisolated func scanDirectory(at path: String, minSize: UInt64) async -> [LargeFile]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fileManager = FileManager.default
                var files: [LargeFile] = []
                
                guard fileManager.fileExists(atPath: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let url = URL(fileURLWithPath: path)
                let resourceKeys: Set<URLResourceKey> = [
                    .fileSizeKey, 
                    .totalFileAllocatedSizeKey, 
                    .contentModificationDateKey, 
                    .isDirectoryKey,
                    .isRegularFileKey
                ]
                
                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: Array(resourceKeys),
                    options: [.skipsHiddenFiles],
                    errorHandler: { _, _ in true }
                ) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                for case let fileURL as URL in enumerator {
                    guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                        continue
                    }
                    
                    // Skip directories
                    if resourceValues.isDirectory == true {
                        continue
                    }
                    
                    // Get file size
                    let fileSize = UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0)
                    
                    // Only include files larger than minSize
                    if fileSize >= minSize {
                        let modDate = resourceValues.contentModificationDate ?? Date()
                        let fileType = Self.determineFileType(for: fileURL)
                        
                        files.append(LargeFile(
                            name: fileURL.lastPathComponent,
                            path: fileURL.path,
                            size: fileSize,
                            modifiedDate: modDate,
                            fileType: fileType
                        ))
                    }
                }
                
                continuation.resume(returning: files)
            }
        }
    }
    
    private static nonisolated func determineFileType(for url: URL) -> LargeFile.FileType {
        let ext = url.pathExtension.lowercased()
        
        switch ext {
        case "mp4", "mov", "avi", "mkv", "m4v", "wmv", "flv":
            return .video
        case "zip", "rar", "7z", "tar", "gz", "bz2":
            return .archive
        case "dmg", "iso", "img", "pkg":
            return .diskImage
        case "app":
            return .application
        default:
            return .other
        }
    }
    
    // MARK: - Actions
    
    func toggleSelection(_ file: LargeFile) {
        if let index = scanResults.firstIndex(where: { $0.id == file.id }) {
            scanResults[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        for i in scanResults.indices {
            scanResults[i].isSelected = true
        }
    }
    
    func deselectAll() {
        for i in scanResults.indices {
            scanResults[i].isSelected = false
        }
    }
    
    var selectedFiles: [LargeFile] {
        scanResults.filter { $0.isSelected }
    }
    
    var totalSelectedSize: UInt64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }
    
    /// Delete selected files (move to trash)
    func deleteSelected() async -> (deleted: Int, errors: [String]) {
        var deletedCount = 0
        var errors: [String] = []
        let fileManager = FileManager.default
        
        for file in selectedFiles {
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                deletedCount += 1
            } catch {
                errors.append("\(file.name): \(error.localizedDescription)")
            }
        }
        
        // Remove deleted files from results
        scanResults.removeAll { file in
            selectedFiles.contains(where: { $0.path == file.path }) && errors.allSatisfy { !$0.contains(file.name) }
        }
        
        return (deletedCount, errors)
    }
    
    /// Reveal file in Finder
    func revealInFinder(_ file: LargeFile) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }
    
    /// Open file with default application
    func openFile(_ file: LargeFile) {
        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
    }
}
