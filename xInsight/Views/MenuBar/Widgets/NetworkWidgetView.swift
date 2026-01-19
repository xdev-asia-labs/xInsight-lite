import SwiftUI

/// Network Widget - Shows upload/download speeds and details
struct NetworkWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Network")
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
            
            VStack(spacing: 16) {
                // Speed indicators
                HStack(spacing: 30) {
                    SpeedIndicator(
                        label: "Upload",
                        value: formatBytes(Int64(metricsCollector.currentMetrics.networkBytesOut)),
                        icon: "arrow.up",
                        color: .green
                    )
                    
                    SpeedIndicator(
                        label: "Download",
                        value: formatBytes(Int64(metricsCollector.currentMetrics.networkBytesIn)),
                        icon: "arrow.down",
                        color: .blue
                    )
                }
                
                // Usage history
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage history")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    MiniChartView(
                        data: networkHistoryData,
                        maxValue: max(networkHistoryData.max() ?? 100, 100),
                        color: .blue
                    )
                    .frame(height: 40)
                }
                
                Divider()
                
                // Network details
                VStack(alignment: .leading, spacing: 6) {
                    DetailRowFull(label: "Public IP:", value: getPublicIP())
                    DetailRowFull(label: "Local IP:", value: getLocalIP())
                    DetailRowFull(label: "Interface:", value: getActiveInterface())
                    DetailRowFull(label: "Network:", value: getNetworkName())
                }
                
                Divider()
                
                // Top processes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top processes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(topNetworkProcesses.prefix(4), id: \.name) { process in
                        HStack {
                            Text(process.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("↑ 0 KB/s")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("↓ 0 KB/s")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var topNetworkProcesses: [ProcessInfo] {
        // In real implementation, we'd track network usage per process
        processMonitor.processes.prefix(4).map { $0 }
    }
    
    private var networkHistoryData: [Double] {
        // Generate sample history based on current network
        let current = Double(metricsCollector.currentMetrics.networkBytesIn + metricsCollector.currentMetrics.networkBytesOut) / 1000
        return (0..<20).map { _ in
            max(0, current + Double.random(in: -10...10))
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1_000
        if kb > 1000 {
            return String(format: "%.1f MB/s", kb / 1000)
        }
        return String(format: "%.0f KB/s", kb)
    }
    
    private func getPublicIP() -> String { "—" }
    private func getLocalIP() -> String { getWiFiAddress() ?? "—" }
    private func getActiveInterface() -> String { "Wi-Fi (en0)" }
    private func getNetworkName() -> String { getCurrentWiFiSSID() ?? "—" }
    
    private func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                let interface = ptr!.pointee
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                        address = String(cString: hostname)
                    }
                }
                ptr = interface.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return address
    }
    
    private func getCurrentWiFiSSID() -> String? {
        // Requires CoreWLAN and proper entitlements
        return nil
    }
}

struct SpeedIndicator: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(.headline, design: .monospaced))
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct DetailRowFull: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
        }
    }
}
