import Foundation
import Combine

/// Docker Container Monitor Service
/// Monitors Docker containers, images, and provides management capabilities
@MainActor
final class DockerMonitor: ObservableObject {
    static let shared = DockerMonitor()
    
    // MARK: - Published Properties
    @Published var isDockerInstalled = false
    @Published var isDockerRunning = false
    @Published var containers: [Container] = []
    @Published var images: [DockerImage] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private var refreshTimer: Timer?
    
    private init() {
        checkDockerStatus()
    }
    
    // MARK: - Docker Status
    
    func checkDockerStatus() {
        Task {
            isDockerInstalled = await checkDockerInstalled()
            if isDockerInstalled {
                isDockerRunning = await checkDockerRunning()
                if isDockerRunning {
                    await refreshAll()
                }
            }
        }
    }
    
    private func checkDockerInstalled() async -> Bool {
        let paths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        return paths.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }
    
    private func checkDockerRunning() async -> Bool {
        let output = await runDockerCommand(["info", "--format", "{{.ServerVersion}}"])
        return output != nil && !output!.isEmpty
    }
    
    // MARK: - Refresh
    
    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshContainers() }
            group.addTask { await self.refreshImages() }
        }
    }
    
    func refreshContainers() async {
        guard let output = await runDockerCommand([
            "ps", "-a", "--format",
            "{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}|{{.State}}"
        ]) else { return }
        
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        containers = lines.compactMap { line -> Container? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 6 else { return nil }
            
            return Container(
                id: parts[0],
                name: parts[1],
                image: parts[2],
                status: parts[3],
                ports: parts[4],
                state: ContainerState(rawValue: parts[5].lowercased()) ?? .unknown
            )
        }
    }
    
    func refreshImages() async {
        guard let output = await runDockerCommand([
            "images", "--format",
            "{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}|{{.CreatedSince}}"
        ]) else { return }
        
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        images = lines.compactMap { line -> DockerImage? in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 5 else { return nil }
            
            return DockerImage(
                id: parts[0],
                repository: parts[1],
                tag: parts[2],
                size: parts[3],
                created: parts[4]
            )
        }
    }
    
    // MARK: - Container Actions
    
    func startContainer(_ container: Container) async -> Bool {
        let result = await runDockerCommand(["start", container.id])
        await refreshContainers()
        return result != nil
    }
    
    func stopContainer(_ container: Container) async -> Bool {
        let result = await runDockerCommand(["stop", container.id])
        await refreshContainers()
        return result != nil
    }
    
    func restartContainer(_ container: Container) async -> Bool {
        let result = await runDockerCommand(["restart", container.id])
        await refreshContainers()
        return result != nil
    }
    
    func removeContainer(_ container: Container, force: Bool = false) async -> Bool {
        var args = ["rm"]
        if force { args.append("-f") }
        args.append(container.id)
        
        let result = await runDockerCommand(args)
        await refreshContainers()
        return result != nil
    }
    
    func getContainerLogs(_ container: Container, lines: Int = 100) async -> String {
        return await runDockerCommand(["logs", "--tail", "\(lines)", container.id]) ?? ""
    }
    
    func getContainerStats(_ container: Container) async -> ContainerStats? {
        guard let output = await runDockerCommand([
            "stats", "--no-stream", "--format",
            "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}",
            container.id
        ]) else { return nil }
        
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "|")
        guard parts.count >= 5 else { return nil }
        
        return ContainerStats(
            cpuPercent: parts[0],
            memoryUsage: parts[1],
            memoryPercent: parts[2],
            networkIO: parts[3],
            blockIO: parts[4]
        )
    }
    
    // MARK: - Image Actions
    
    func pullImage(_ name: String) async -> Bool {
        let result = await runDockerCommand(["pull", name])
        await refreshImages()
        return result != nil
    }
    
    func removeImage(_ image: DockerImage, force: Bool = false) async -> Bool {
        var args = ["rmi"]
        if force { args.append("-f") }
        args.append(image.id)
        
        let result = await runDockerCommand(args)
        await refreshImages()
        return result != nil
    }
    
    // MARK: - System
    
    func pruneSystem() async -> String {
        return await runDockerCommand(["system", "prune", "-f"]) ?? "Prune failed"
    }
    
    func getDiskUsage() async -> String {
        return await runDockerCommand(["system", "df"]) ?? ""
    }
    
    // MARK: - Helper
    
    private func runDockerCommand(_ args: [String]) async -> String? {
        let dockerPath = findDockerPath()
        guard let path = dockerPath else {
            lastError = "Docker not found"
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                
                if process.terminationStatus != 0 {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    Task { @MainActor in
                        self.lastError = error
                    }
                }
                
                continuation.resume(returning: output)
            } catch {
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                }
                continuation.resume(returning: nil)
            }
        }
    }
    
    private func findDockerPath() -> String? {
        let paths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker"
        ]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    
    // MARK: - Auto-Refresh
    
    func startAutoRefresh(interval: TimeInterval = 10) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshContainers()
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Models

struct Container: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: String
    let state: ContainerState
    
    var isRunning: Bool { state == .running }
    
    var statusColor: String {
        switch state {
        case .running: return "green"
        case .exited: return "gray"
        case .paused: return "yellow"
        case .restarting: return "orange"
        default: return "gray"
        }
    }
}

enum ContainerState: String {
    case running
    case exited
    case paused
    case restarting
    case created
    case dead
    case removing
    case unknown
}

struct DockerImage: Identifiable, Hashable {
    let id: String
    let repository: String
    let tag: String
    let size: String
    let created: String
    
    var fullName: String {
        tag == "<none>" ? repository : "\(repository):\(tag)"
    }
}

struct ContainerStats {
    let cpuPercent: String
    let memoryUsage: String
    let memoryPercent: String
    let networkIO: String
    let blockIO: String
}
