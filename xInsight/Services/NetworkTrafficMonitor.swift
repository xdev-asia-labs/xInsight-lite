import Foundation
import Network

/// NetworkTrafficMonitor - Detailed network traffic analysis per application
@MainActor
final class NetworkTrafficMonitor: ObservableObject {
    static let shared = NetworkTrafficMonitor()
    
    // MARK: - Published Properties
    @Published var appTraffic: [AppNetworkUsage] = []
    @Published var totalBytesIn: UInt64 = 0
    @Published var totalBytesOut: UInt64 = 0
    @Published var currentRateIn: Double = 0 // bytes/sec
    @Published var currentRateOut: Double = 0
    @Published var connectionCount: Int = 0
    
    private var lastMeasurement: Date = Date()
    private var lastBytesIn: UInt64 = 0
    private var lastBytesOut: UInt64 = 0
    
    private init() {}
    
    // MARK: - Update Traffic
    
    func update() async {
        // Get network statistics using netstat
        let connections = await getActiveConnections()
        connectionCount = connections.count
        
        // Group by process
        var grouped: [String: AppNetworkUsage] = [:]
        
        for conn in connections {
            if grouped[conn.processName] == nil {
                grouped[conn.processName] = AppNetworkUsage(
                    name: conn.processName,
                    pid: conn.pid,
                    bytesIn: 0,
                    bytesOut: 0,
                    connections: []
                )
            }
            grouped[conn.processName]?.connections.append(conn)
            grouped[conn.processName]?.bytesIn += conn.bytesIn
            grouped[conn.processName]?.bytesOut += conn.bytesOut
        }
        
        appTraffic = grouped.values.sorted { $0.totalBytes > $1.totalBytes }
        
        // Calculate totals and rates
        let newBytesIn = appTraffic.reduce(0) { $0 + $1.bytesIn }
        let newBytesOut = appTraffic.reduce(0) { $0 + $1.bytesOut }
        
        let elapsed = Date().timeIntervalSince(lastMeasurement)
        if elapsed > 0 && lastBytesIn > 0 {
            currentRateIn = Double(newBytesIn - lastBytesIn) / elapsed
            currentRateOut = Double(newBytesOut - lastBytesOut) / elapsed
        }
        
        totalBytesIn = newBytesIn
        totalBytesOut = newBytesOut
        lastBytesIn = newBytesIn
        lastBytesOut = newBytesOut
        lastMeasurement = Date()
    }
    
    // MARK: - Get Connections
    
    private func getActiveConnections() async -> [NetworkConnection] {
        var connections: [NetworkConnection] = []
        
        // Use lsof to get network connections
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-i", "-n", "-P"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                connections = parseNetworkOutput(output)
            }
        } catch {}
        
        return connections
    }
    
    private func parseNetworkOutput(_ output: String) -> [NetworkConnection] {
        var connections: [NetworkConnection] = []
        let lines = output.components(separatedBy: "\n").dropFirst() // Skip header
        
        for line in lines {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 9 else { continue }
            
            let processName = String(parts[0])
            let pid = Int32(parts[1]) ?? 0
            let type = String(parts[4])
            
            guard type == "IPv4" || type == "IPv6" else { continue }
            
            // Parse address:port
            let name = String(parts[8])
            let components = name.components(separatedBy: "->")
            
            let localAddr = components.first ?? ""
            let remoteAddr = components.count > 1 ? components[1] : ""
            
            connections.append(NetworkConnection(
                processName: processName,
                pid: pid,
                type: type == "IPv4" ? .ipv4 : .ipv6,
                localAddress: localAddr,
                remoteAddress: remoteAddr,
                state: .established,
                bytesIn: 0,
                bytesOut: 0
            ))
        }
        
        return connections
    }
    
    // MARK: - Formatted Helpers
    
    func formattedRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return "\(Int(bytesPerSec)) B/s"
        } else if bytesPerSec < 1_048_576 {
            return String(format: "%.1f KB/s", bytesPerSec / 1024)
        } else {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576)
        }
    }
}

// MARK: - Models

struct AppNetworkUsage: Identifiable {
    let id = UUID()
    let name: String
    let pid: Int32
    var bytesIn: UInt64
    var bytesOut: UInt64
    var connections: [NetworkConnection]
    
    var totalBytes: UInt64 { bytesIn + bytesOut }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
}

struct NetworkConnection: Identifiable {
    let id = UUID()
    let processName: String
    let pid: Int32
    let type: ConnectionType
    let localAddress: String
    let remoteAddress: String
    let state: ConnectionState
    var bytesIn: UInt64
    var bytesOut: UInt64
    
    enum ConnectionType {
        case ipv4, ipv6
    }
    
    enum ConnectionState: String {
        case established = "ESTABLISHED"
        case listen = "LISTEN"
        case timeWait = "TIME_WAIT"
        case closeWait = "CLOSE_WAIT"
        case other = "OTHER"
    }
}
