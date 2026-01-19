import SwiftUI

/// Disk Detail Tab - Shows disk usage breakdown with charts and large file detection
struct DiskDetailTab: View {
    @State private var diskInfo: DiskInfo = DiskInfo()
    @State private var isScanning: Bool = true
    @State private var largeFiles: [LargeFile] = []
    @State private var categoryBreakdown: [DiskCategory] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Disk Usage Overview
                diskOverviewSection
                
                // Usage Breakdown Pie Chart
                pieChartSection
                
                // Category Breakdown
                categorySection
                
                // Large Files Detection
                largeFilesSection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await scanDisk()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(.diskDetail))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(L10n.string(.appDescription))
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button(action: { Task { await scanDisk() } }) {
                Label(L10n.string(.rescan), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isScanning)
        }
    }
    
    // MARK: - Disk Overview
    
    private var diskOverviewSection: some View {
        HStack(spacing: 20) {
            // Total Space
            VStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.title)
                    .foregroundColor(.blue)
                
                Text(L10n.string(.total))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatBytes(diskInfo.totalSpace))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            // Used Space
            VStack(spacing: 8) {
                Image(systemName: "chart.pie.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Text(L10n.string(.used))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatBytes(diskInfo.usedSpace))
                    .font(.headline)
                
                Text(String(format: L10n.string(.percentValue), Int(diskInfo.usagePercent)))
                    .font(.caption)
                    .foregroundColor(usageColor)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            // Free Space
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle")
                    .font(.title)
                    .foregroundColor(.green)
                
                Text(L10n.string(.available))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(formatBytes(diskInfo.freeSpace))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Pie Chart
    
    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.string(.storageBreakdown))
                .font(.headline)
            
            HStack(spacing: 40) {
                // Pie Chart
                ZStack {
                    ForEach(Array(categoryBreakdown.enumerated()), id: \.element.id) { index, category in
                        PieSlice(
                            startAngle: startAngle(for: index),
                            endAngle: endAngle(for: index),
                            color: category.color
                        )
                        .fill(category.color)
                    }
                    
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .frame(width: 100, height: 100)
                    
                    VStack {
                        Text(String(format: L10n.string(.percentValue), Int(diskInfo.usagePercent)))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(L10n.string(.used))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 200, height: 200)
                
                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(categoryBreakdown) { category in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 12, height: 12)
                            
                            Text(category.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text(formatBytes(category.size))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.usageByCategory))
                .font(.headline)
            
            ForEach(categoryBreakdown) { category in
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                            .frame(width: 24)
                        
                        Text(category.name)
                        
                        Spacer()
                        
                        Text(formatBytes(category.size))
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            Rectangle()
                                .fill(category.color)
                                .frame(width: geo.size.width * (category.percent / 100), height: 8)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Large Files Section
    
    private var largeFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(format: L10n.string(.largeFilesCount), largeFiles.count))
                    .font(.headline)
                
                Spacer()
                
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            if largeFiles.isEmpty && !isScanning {
                Text(L10n.string(.noLargeFiles))
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(largeFiles.prefix(10)) { file in
                    HStack {
                        Image(systemName: iconForFile(file.name))
                            .foregroundColor(.accentColor)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(file.name)
                                .lineLimit(1)
                            Text(file.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Text(formatBytes(file.size))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(file.size > 1_000_000_000 ? .red : .orange)
                    }
                    .padding(.vertical, 4)
                }
                
                if largeFiles.count > 10 {
                    Text(String(format: L10n.string(.andMoreFiles), largeFiles.count - 10))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func scanDisk() async {
        isScanning = true
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadDiskInfo() }
            group.addTask { await self.loadCategoryBreakdown() }
            group.addTask { await self.findLargeFiles() }
        }
        
        isScanning = false
    }
    
    private func loadDiskInfo() async {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? UInt64) ?? 0
            let free = (attrs[.systemFreeSize] as? UInt64) ?? 0
            let used = total - free
            
            await MainActor.run {
                diskInfo = DiskInfo(
                    totalSpace: total,
                    freeSpace: free,
                    usedSpace: used
                )
            }
        }
    }
    
    private func loadCategoryBreakdown() async {
        // Simulate category breakdown based on common usage patterns
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        
        var categories: [DiskCategory] = []
        
        let dirs: [(name: String, path: String, icon: String, color: Color)] = [
            ("Applications", "/Applications", "app.badge", .blue),
            ("Documents", homeDir.appendingPathComponent("Documents").path, "doc.fill", .green),
            ("Downloads", homeDir.appendingPathComponent("Downloads").path, "arrow.down.circle", .orange),
            ("Developer", homeDir.appendingPathComponent("Developer").path, "hammer", .purple),
            ("Library", homeDir.appendingPathComponent("Library").path, "folder.fill.badge.gearshape", .gray),
            ("Movies", homeDir.appendingPathComponent("Movies").path, "film", .red),
            ("Music", homeDir.appendingPathComponent("Music").path, "music.note", .pink),
            ("Pictures", homeDir.appendingPathComponent("Pictures").path, "photo", .cyan),
        ]
        
        for (name, path, icon, color) in dirs {
            let size = directorySize(at: path)
            if size > 0 {
                categories.append(DiskCategory(
                    name: name,
                    size: size,
                    percent: 0,
                    icon: icon,
                    color: color
                ))
            }
        }
        
        // Calculate percentages
        let totalSize = categories.reduce(0) { $0 + $1.size }
        var finalCategories = categories.map { cat in
            var c = cat
            c.percent = totalSize > 0 ? Double(cat.size) / Double(totalSize) * 100 : 0
            return c
        }
        
        // Sort by size
        finalCategories.sort { $0.size > $1.size }
        
        let result = finalCategories
        await MainActor.run {
            categoryBreakdown = result
        }
    }
    
    private func findLargeFiles() async {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        var files: [LargeFile] = []
        
        let searchPaths = [
            homeDir.appendingPathComponent("Downloads"),
            homeDir.appendingPathComponent("Documents"),
            homeDir.appendingPathComponent("Desktop"),
            homeDir.appendingPathComponent("Movies"),
        ]
        
        for searchPath in searchPaths {
            if let enumerator = FileManager.default.enumerator(
                at: searchPath,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          values.isRegularFile == true,
                          let size = values.fileSize,
                          size > 500_000_000 else { continue } // > 500 MB
                    
                    files.append(LargeFile(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: UInt64(size)
                    ))
                }
            }
        }
        
        files.sort { $0.size > $1.size }
        
        let result = files
        await MainActor.run {
            largeFiles = result
        }
    }
    
    private func directorySize(at path: String) -> UInt64 {
        var size: UInt64 = 0
        let url = URL(fileURLWithPath: path)
        
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator.prefix(1000) { // Limit for performance
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += UInt64(fileSize)
                }
            }
        }
        
        return size
    }
    
    private func startAngle(for index: Int) -> Angle {
        let preceding = categoryBreakdown.prefix(index).reduce(0) { $0 + $1.percent }
        return .degrees(preceding * 3.6 - 90)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let preceding = categoryBreakdown.prefix(index + 1).reduce(0) { $0 + $1.percent }
        return .degrees(preceding * 3.6 - 90)
    }
    
    private var usageColor: Color {
        if diskInfo.usagePercent > 90 { return .red }
        if diskInfo.usagePercent > 75 { return .orange }
        if diskInfo.usagePercent > 50 { return .yellow }
        return .green
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return "film"
        case "dmg", "iso", "pkg": return "shippingbox"
        case "zip", "rar", "7z": return "archivebox"
        case "app": return "app"
        default: return "doc.fill"
        }
    }
}

// MARK: - Models

struct DiskInfo {
    var totalSpace: UInt64 = 0
    var freeSpace: UInt64 = 0
    var usedSpace: UInt64 = 0
    
    var usagePercent: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }
}

struct DiskCategory: Identifiable {
    let id = UUID()
    let name: String
    let size: UInt64
    var percent: Double
    let icon: String
    let color: Color
}

struct LargeFile: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: UInt64
}

// MARK: - Pie Slice Shape

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var color: Color
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    DiskDetailTab()
        .frame(width: 700, height: 900)
}
