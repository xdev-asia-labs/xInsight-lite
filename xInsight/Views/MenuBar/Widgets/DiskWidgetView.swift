import SwiftUI

/// Disk Widget - Shows disk usage per volume
struct DiskWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Disk")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            VStack(spacing: 12) {
                // Volumes
                ForEach(getVolumes(), id: \.name) { volume in
                    DiskVolumeRow(volume: volume)
                }
                
                Divider()
                
                // I/O Activity
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        IOStatView(
                            label: "Read",
                            value: metricsCollector.currentMetrics.formattedDiskRead,
                            icon: "arrow.down.circle",
                            color: .green
                        )
                        
                        IOStatView(
                            label: "Write",
                            value: metricsCollector.currentMetrics.formattedDiskWrite,
                            icon: "arrow.up.circle",
                            color: .blue
                        )
                    }
                }
            }
            .padding()
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func getVolumes() -> [VolumeInfo] {
        var volumes: [VolumeInfo] = []
        
        // Get main disk info
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            let used = total - free
            
            volumes.append(VolumeInfo(
                name: "Macintosh HD",
                total: total,
                used: used,
                free: free
            ))
        }
        
        return volumes
    }
}

struct VolumeInfo {
    let name: String
    let total: Int64
    let used: Int64
    let free: Int64
    
    var usagePercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }
}

struct DiskVolumeRow: View {
    let volume: VolumeInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "internaldrive")
                    .font(.caption)
                Text(volume.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(usageColor)
                        .frame(width: geo.size.width * (volume.usagePercent / 100))
                }
            }
            .frame(height: 10)
            .cornerRadius(2)
            
            HStack {
                Text("Used \(formatBytes(volume.used)) from \(formatBytes(volume.total))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", volume.usagePercent))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var usageColor: Color {
        if volume.usagePercent > 90 { return .red }
        if volume.usagePercent > 75 { return .orange }
        return .blue
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.2f GB", gb)
    }
}

struct IOStatView: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
            }
        }
    }
}
