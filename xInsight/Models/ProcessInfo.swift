import Foundation

// MARK: - Process Info Model
struct ProcessInfo: Identifiable, Hashable {
    let id: UUID
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let icon: Data?  // App icon as PNG data
    
    // Resource Usage
    var cpuUsage: Double           // 0-100%
    var memoryUsage: UInt64        // Bytes
    var diskReadBytes: UInt64      // Total bytes read
    var diskWriteBytes: UInt64     // Total bytes written
    var networkBytesIn: UInt64     // Total bytes received
    var networkBytesOut: UInt64    // Total bytes sent
    var threadCount: Int
    
    // Process State
    var state: ProcessState
    var user: String
    var startTime: Date?
    var parentPID: Int32?
    
    // Grouping
    var category: ProcessCategory
    
    init(pid: Int32, name: String) {
        self.id = UUID()
        self.pid = pid
        self.name = name
        self.bundleIdentifier = nil
        self.icon = nil
        self.cpuUsage = 0
        self.memoryUsage = 0
        self.diskReadBytes = 0
        self.diskWriteBytes = 0
        self.networkBytesIn = 0
        self.networkBytesOut = 0
        self.threadCount = 0
        self.state = .running
        self.user = "unknown"
        self.startTime = nil
        self.parentPID = nil
        self.category = .system
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }
    
    static func == (lhs: ProcessInfo, rhs: ProcessInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}

// MARK: - Process State
enum ProcessState: String, CaseIterable {
    case running = "Running"
    case sleeping = "Sleeping"
    case idle = "Idle"
    case stopped = "Stopped"
    case zombie = "Zombie"
    case unknown = "Unknown"
}

// MARK: - Process Category
enum ProcessCategory: String, CaseIterable {
    case browser = "Browsers"
    case developer = "Developer Tools"
    case productivity = "Productivity"
    case media = "Media"
    case communication = "Communication"
    case system = "System"
    case background = "Background"
    case other = "Other"
    
    var iconName: String {
        switch self {
        case .browser: return "globe"
        case .developer: return "hammer"
        case .productivity: return "doc.text"
        case .media: return "play.circle"
        case .communication: return "bubble.left.and.bubble.right"
        case .system: return "gearshape"
        case .background: return "moon"
        case .other: return "square.grid.2x2"
        }
    }
    
    static func categorize(processName: String, bundleId: String?) -> ProcessCategory {
        let name = processName.lowercased()
        let bundle = bundleId?.lowercased() ?? ""
        
        // Browsers
        if name.contains("chrome") || name.contains("safari") || 
           name.contains("firefox") || name.contains("edge") ||
           name.contains("brave") || name.contains("arc") ||
           bundle.contains("browser") {
            return .browser
        }
        
        // Developer Tools
        if name.contains("xcode") || name.contains("vscode") ||
           name.contains("code") || name.contains("terminal") ||
           name.contains("iterm") || name.contains("docker") ||
           name.contains("simulator") || name.contains("git") ||
           bundle.contains("developer") {
            return .developer
        }
        
        // Media
        if name.contains("spotify") || name.contains("music") ||
           name.contains("vlc") || name.contains("quicktime") ||
           name.contains("photos") || name.contains("preview") ||
           bundle.contains("music") || bundle.contains("video") {
            return .media
        }
        
        // Communication
        if name.contains("slack") || name.contains("discord") ||
           name.contains("zoom") || name.contains("teams") ||
           name.contains("messages") || name.contains("mail") ||
           name.contains("telegram") {
            return .communication
        }
        
        // Productivity
        if name.contains("pages") || name.contains("numbers") ||
           name.contains("keynote") || name.contains("word") ||
           name.contains("excel") || name.contains("notion") ||
           name.contains("obsidian") || name.contains("notes") {
            return .productivity
        }
        
        // System processes
        if name.contains("kernel") || name.contains("launchd") ||
           name.contains("mds") || name.contains("spotlight") ||
           name.contains("finder") || name.contains("dock") ||
           name.contains("windowserver") || name.hasPrefix("com.apple") ||
           bundle.hasPrefix("com.apple") {
            return .system
        }
        
        // Background daemons
        if name.hasSuffix("d") || name.hasSuffix("agent") ||
           name.contains("helper") || name.contains("daemon") {
            return .background
        }
        
        return .other
    }
}

// MARK: - Formatted Helpers
extension ProcessInfo {
    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
    
    var formattedCPU: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    var displayName: String {
        // Clean up process name for display
        var cleanName = name
        if cleanName.hasSuffix(" Helper") {
            cleanName = String(cleanName.dropLast(7))
        }
        if cleanName.hasSuffix(" (GPU)") {
            cleanName = String(cleanName.dropLast(6))
        }
        return cleanName
    }
}
