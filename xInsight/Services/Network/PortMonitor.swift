import Foundation
import Darwin

/// Port information model
struct PortInfo: Identifiable, Hashable {
    let id = UUID()
    let port: UInt16
    let processName: String
    let pid: Int32
    let protocol_: String  // tcp or udp
    let localAddress: String
    let state: PortState
    let timestamp: Date
    
    enum PortState: String {
        case listen = "LISTEN"
        case established = "ESTABLISHED"
        case timeWait = "TIME_WAIT"
        case closeWait = "CLOSE_WAIT"
        case unknown = "UNKNOWN"
        
        var color: String {
            switch self {
            case .listen: return "green"
            case .established: return "blue"
            case .timeWait: return "yellow"
            case .closeWait: return "orange"
            case .unknown: return "gray"
            }
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(port)
        hasher.combine(pid)
    }
    
    static func == (lhs: PortInfo, rhs: PortInfo) -> Bool {
        lhs.port == rhs.port && lhs.pid == rhs.pid
    }
}

/// Simple port scanner without complex async/notification logic
enum PortScanner {
    /// Get listening ports - runs lsof on background thread with timeout
    static func getListeningPorts() async -> [PortInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                var ports: [PortInfo] = []
                
                // Use lsof to get listening ports
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
                task.arguments = ["-iTCP", "-sTCP:LISTEN", "-P", "-n"]
                
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice
                
                do {
                    try task.run()
                    
                    // Add timeout - kill after 10 seconds
                    let deadline = DispatchTime.now() + .seconds(10)
                    DispatchQueue.global().asyncAfter(deadline: deadline) {
                        if task.isRunning {
                            task.terminate()
                            print("lsof timed out, killed process")
                        }
                    }
                    
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        ports = parseLsofOutput(output)
                    }
                } catch {
                    print("Error running lsof: \(error)")
                }
                
                continuation.resume(returning: ports.sorted { $0.port < $1.port })
            }
        }
    }
    
    private static func parseLsofOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: "\n")
        
        // Skip header line
        for line in lines.dropFirst() {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            guard components.count >= 9 else { continue }
            
            let processName = String(components[0])
            let pidStr = String(components[1])
            let nameColumn = String(components[8])
            
            guard let pid = Int32(pidStr) else { continue }
            
            // Parse port from NAME column (e.g., "*:3000" or "127.0.0.1:8080")
            if let colonIndex = nameColumn.lastIndex(of: ":") {
                let portStr = String(nameColumn[nameColumn.index(after: colonIndex)...])
                if let port = UInt16(portStr) {
                    let localAddress = String(nameColumn[..<colonIndex])
                    
                    let portInfo = PortInfo(
                        port: port,
                        processName: processName,
                        pid: pid,
                        protocol_: "TCP",
                        localAddress: localAddress == "*" ? "0.0.0.0" : localAddress,
                        state: .listen,
                        timestamp: Date()
                    )
                    
                    // Avoid duplicates
                    if !ports.contains(where: { $0.port == port && $0.pid == pid }) {
                        ports.append(portInfo)
                    }
                }
            }
        }
        
        return ports
    }
}

// MARK: - Common Ports Description
extension PortInfo {
    var commonDescription: String? {
        switch port {
        case 22: return "SSH"
        case 80: return "HTTP"
        case 443: return "HTTPS"
        case 3000: return "Dev Server (Node/React)"
        case 3306: return "MySQL"
        case 5000: return "Flask/Dev Server"
        case 5432: return "PostgreSQL"
        case 5672: return "RabbitMQ"
        case 6379: return "Redis"
        case 8000: return "Django/Dev Server"
        case 8080: return "HTTP Alt/Tomcat"
        case 8443: return "HTTPS Alt"
        case 9000: return "PHP-FPM"
        case 27017: return "MongoDB"
        default: return nil
        }
    }
    
    var displayName: String {
        if let desc = commonDescription {
            return "\(port) (\(desc))"
        }
        return "\(port)"
    }
}
