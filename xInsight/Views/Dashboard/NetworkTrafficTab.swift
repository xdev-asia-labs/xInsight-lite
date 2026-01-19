import SwiftUI

/// Network Traffic Tab - Comprehensive network and disk I/O monitoring
struct NetworkTrafficTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @State private var diskReadHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var diskWriteHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var networkInHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var networkOutHistory: [Double] = Array(repeating: 0, count: 60)
    @State private var selectedSection = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                quickStatsSection
                
                Picker("Section", selection: $selectedSection) {
                    Text("Network").tag(0)
                    Text("Disk I/O").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                if selectedSection == 0 {
                    networkDetailSection
                    networkHistorySection
                    connectionInfoSection
                } else {
                    diskDetailSection
                    diskHistorySection
                    diskInfoSection
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(metricsCollector.$currentMetrics) { _ in
            updateHistory()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            // Icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "network")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Network & Disk I/O")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Real-time bandwidth and storage monitoring")
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.caption)
                    }
                    
                    Text("Interface: en0 (Wi-Fi)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        HStack(spacing: 16) {
            // Network Download
            QuickStatCard(
                title: "Download",
                value: formatSpeed(metricsCollector.currentMetrics.networkDownloadSpeed),
                subtitle: "MB/s",
                icon: "arrow.down.circle.fill",
                color: .blue,
                trend: networkInHistory.last ?? 0 > (networkInHistory.dropLast().last ?? 0) ? .up : .down
            )
            
            // Network Upload
            QuickStatCard(
                title: "Upload",
                value: formatSpeed(metricsCollector.currentMetrics.networkUploadSpeed),
                subtitle: "MB/s",
                icon: "arrow.up.circle.fill",
                color: .cyan,
                trend: networkOutHistory.last ?? 0 > (networkOutHistory.dropLast().last ?? 0) ? .up : .down
            )
            
            // Disk Read
            QuickStatCard(
                title: "Disk Read",
                value: formatSpeed(metricsCollector.currentMetrics.diskReadSpeed),
                subtitle: "MB/s",
                icon: "arrow.down.doc.fill",
                color: .green,
                trend: diskReadHistory.last ?? 0 > (diskReadHistory.dropLast().last ?? 0) ? .up : .down
            )
            
            // Disk Write
            QuickStatCard(
                title: "Disk Write",
                value: formatSpeed(metricsCollector.currentMetrics.diskWriteSpeed),
                subtitle: "MB/s",
                icon: "arrow.up.doc.fill",
                color: .orange,
                trend: diskWriteHistory.last ?? 0 > (diskWriteHistory.dropLast().last ?? 0) ? .up : .down
            )
        }
    }
    
    // MARK: - Network Detail
    
    private var networkDetailSection: some View {
        HStack(spacing: 16) {
            // Download gauge
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: min(metricsCollector.currentMetrics.networkDownloadSpeed / 100, 1))
                        .stroke(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.blue)
                        Text(formatSpeed(metricsCollector.currentMetrics.networkDownloadSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("MB/s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Download")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // Upload gauge
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: min(metricsCollector.currentMetrics.networkUploadSpeed / 50, 1))
                        .stroke(
                            LinearGradient(colors: [.cyan, .teal], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.cyan)
                        Text(formatSpeed(metricsCollector.currentMetrics.networkUploadSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("MB/s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Upload")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // Total stats
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.purple)
                    Text("Session Stats")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Total Downloaded", value: formatBytes(calculateTotalBytes(networkInHistory)))
                    StatRow(label: "Total Uploaded", value: formatBytes(calculateTotalBytes(networkOutHistory)))
                    StatRow(label: "Avg Download", value: "\(formatSpeed(networkInHistory.reduce(0, +) / 60)) MB/s")
                    StatRow(label: "Avg Upload", value: "\(formatSpeed(networkOutHistory.reduce(0, +) / 60)) MB/s")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Network History
    
    private var networkHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Network Activity (60s)", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack {
                    // Download line
                    Path { path in
                        guard networkInHistory.count > 1 else { return }
                        let maxValue = max(networkInHistory.max() ?? 1, 1)
                        let step = geometry.size.width / CGFloat(networkInHistory.count - 1)
                        
                        for (index, value) in networkInHistory.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(value / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    
                    // Upload line
                    Path { path in
                        guard networkOutHistory.count > 1 else { return }
                        let maxValue = max(networkOutHistory.max() ?? 1, 1)
                        let step = geometry.size.width / CGFloat(networkOutHistory.count - 1)
                        
                        for (index, value) in networkOutHistory.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(value / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
                }
            }
            .frame(height: 100)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 20, height: 3)
                    Text("Download")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .frame(width: 20, height: 3)
                    Text("Upload")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Connection Info
    
    private var connectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Connection Details", systemImage: "link")
                    .font(.headline)
                Spacer()
                Text("\(metricsCollector.currentMetrics.activeConnections) active")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                ConnectionInfoCard(title: "Interface", value: "en0 (Wi-Fi)", icon: "wifi", color: .blue)
                ConnectionInfoCard(title: "Local IP", value: getLocalIP(), icon: "number", color: .green)
                ConnectionInfoCard(title: "Status", value: "Connected", icon: "checkmark.circle.fill", color: .green)
                ConnectionInfoCard(title: "Type", value: "802.11ax", icon: "antenna.radiowaves.left.and.right", color: .purple)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Disk Detail
    
    private var diskDetailSection: some View {
        HStack(spacing: 16) {
            // Read gauge
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: min(metricsCollector.currentMetrics.diskReadSpeed / 500, 1))
                        .stroke(
                            LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.green)
                        Text(formatSpeed(metricsCollector.currentMetrics.diskReadSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("MB/s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Read")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // Write gauge
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: min(metricsCollector.currentMetrics.diskWriteSpeed / 300, 1))
                        .stroke(
                            LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.orange)
                        Text(formatSpeed(metricsCollector.currentMetrics.diskWriteSpeed))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("MB/s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("Write")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
            
            // IO Operations
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundColor(.purple)
                    Text("I/O Operations")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Read Ops", value: "\(metricsCollector.currentMetrics.diskReadOps)")
                    StatRow(label: "Write Ops", value: "\(metricsCollector.currentMetrics.diskWriteOps)")
                    StatRow(label: "Total Data Read", value: formatBytes(calculateTotalBytes(diskReadHistory)))
                    StatRow(label: "Total Data Written", value: formatBytes(calculateTotalBytes(diskWriteHistory)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Disk History
    
    private var diskHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Disk Activity (60s)", systemImage: "chart.xyaxis.line")
                    .font(.headline)
                Spacer()
            }
            
            GeometryReader { geometry in
                ZStack {
                    // Read line
                    Path { path in
                        guard diskReadHistory.count > 1 else { return }
                        let maxValue = max(diskReadHistory.max() ?? 1, 1)
                        let step = geometry.size.width / CGFloat(diskReadHistory.count - 1)
                        
                        for (index, value) in diskReadHistory.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(value / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    
                    // Write line
                    Path { path in
                        guard diskWriteHistory.count > 1 else { return }
                        let maxValue = max(diskWriteHistory.max() ?? 1, 1)
                        let step = geometry.size.width / CGFloat(diskWriteHistory.count - 1)
                        
                        for (index, value) in diskWriteHistory.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(value / maxValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 3]))
                }
            }
            .frame(height: 100)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(8)
            
            HStack(spacing: 24) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.green)
                        .frame(width: 20, height: 3)
                    Text("Read")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .frame(width: 20, height: 3)
                    Text("Write")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Disk Info
    
    private var diskInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Storage Information", systemImage: "internaldrive.fill")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                ConnectionInfoCard(title: "Type", value: "NVMe SSD", icon: "bolt.fill", color: .blue)
                ConnectionInfoCard(title: "Protocol", value: "PCIe 4.0", icon: "cpu", color: .purple)
                ConnectionInfoCard(title: "Max Read", value: "7.4 GB/s", icon: "gauge.with.dots.needle.100percent", color: .green)
                ConnectionInfoCard(title: "Max Write", value: "6.3 GB/s", icon: "gauge.with.dots.needle.67percent", color: .orange)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Helpers
    
    private func updateHistory() {
        diskReadHistory.append(metricsCollector.currentMetrics.diskReadSpeed)
        diskWriteHistory.append(metricsCollector.currentMetrics.diskWriteSpeed)
        networkInHistory.append(metricsCollector.currentMetrics.networkDownloadSpeed)
        networkOutHistory.append(metricsCollector.currentMetrics.networkUploadSpeed)
        
        if diskReadHistory.count > 60 { diskReadHistory.removeFirst() }
        if diskWriteHistory.count > 60 { diskWriteHistory.removeFirst() }
        if networkInHistory.count > 60 { networkInHistory.removeFirst() }
        if networkOutHistory.count > 60 { networkOutHistory.removeFirst() }
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed < 0.01 { return "0.00" }
        return String(format: "%.2f", speed)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        if bytes > 1024 { return String(format: "%.1f GB", bytes / 1024) }
        return String(format: "%.0f MB", bytes)
    }
    
    private func calculateTotalBytes(_ history: [Double]) -> Double {
        history.reduce(0, +)
    }
    
    private func getLocalIP() -> String {
        var address = "192.168.1.x"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let name = String(cString: interface.ifa_name)
                
                if name == "en0" {
                    let family = interface.ifa_addr.pointee.sa_family
                    if family == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(
                            interface.ifa_addr,
                            socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        ) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let trend: Trend
    
    enum Trend {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .neutral: return "minus"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: trend.icon)
                    .font(.caption2)
                    .foregroundColor(trend == .up ? .green : .red)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct ConnectionInfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }
}

#Preview {
    NetworkTrafficTab()
        .environmentObject(MetricsCollector())
        .frame(width: 900, height: 900)
}
