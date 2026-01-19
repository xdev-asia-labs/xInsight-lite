import Foundation
import Combine

/// Main orchestrator for collecting system metrics
@MainActor
class MetricsCollector: ObservableObject {
    // MARK: - Published Properties
    @Published var currentMetrics: SystemMetrics = SystemMetrics()
    @Published var metricsHistory: [SystemMetrics] = []
    @Published var isCollecting: Bool = false
    
    // MARK: - Sub-collectors
    private let cpuMetrics = CPUMetrics()
    private let memoryMetrics = MemoryMetrics()
    private let diskMetrics = DiskMetrics()
    private let thermalMetrics = ThermalMetrics()
    private let gpuMetrics = GPUMetrics()
    
    // MARK: - Configuration
    private let updateInterval: TimeInterval = 2.0  // Update every 2 seconds
    private let historyLimit: Int = 300  // Keep 10 minutes of history (300 * 2s)
    private let historySaveInterval: TimeInterval = 300  // Save to DB every 5 minutes
    
    // MARK: - Private
    private var updateTask: Task<Void, Never>?
    private var historySaveTask: Task<Void, Never>?
    private var lastHistorySave: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        startCollecting()
        startHistorySaving()
    }
    
    deinit {
        updateTask?.cancel()
        historySaveTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start collecting metrics
    func startCollecting() {
        guard !isCollecting else { return }
        isCollecting = true
        
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.collectMetrics()
                try? await Task.sleep(nanoseconds: UInt64(self?.updateInterval ?? 2.0) * 1_000_000_000)
            }
        }
    }
    
    /// Stop collecting metrics
    func stopCollecting() {
        updateTask?.cancel()
        updateTask = nil
        historySaveTask?.cancel()
        historySaveTask = nil
        isCollecting = false
    }
    
    /// Start periodic history saving to database
    private func startHistorySaving() {
        historySaveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self?.historySaveInterval ?? 300) * 1_000_000_000)
                await self?.saveToHistory()
            }
        }
    }
    
    /// Save current metrics to persistent history
    private func saveToHistory() async {
        let metrics = currentMetrics
        await MetricsHistoryStore.shared.saveSnapshot(metrics)
        lastHistorySave = Date()
        
        // Cleanup old data periodically (once per day)
        let calendar = Calendar.current
        if calendar.component(.hour, from: Date()) == 3 { // 3 AM
            MetricsHistoryStore.shared.cleanupOldData()
        }
    }
    
    /// Force an immediate metrics update
    func refresh() async {
        await collectMetrics()
    }
    
    // MARK: - Private Methods
    
    private func collectMetrics() async {
        var metrics = SystemMetrics()
        
        // Collect CPU metrics
        let cpu = cpuMetrics.collect()
        metrics.cpuUsage = cpu.usage
        metrics.cpuPerformanceCores = cpu.performanceCores
        metrics.cpuEfficiencyCores = cpu.efficiencyCores
        
        // Collect Memory metrics
        let memory = memoryMetrics.collect()
        metrics.memoryUsed = memory.used
        metrics.memoryTotal = memory.total
        metrics.memoryPressure = memory.pressure
        metrics.swapUsed = memory.swapUsed
        metrics.memoryWired = memory.wired
        metrics.memoryCompressed = memory.compressed
        
        // Collect GPU metrics (Apple Silicon)
        let gpu = gpuMetrics.collect()
        metrics.gpuUsage = gpu.usage
        metrics.gpuMemoryUsed = gpu.memoryUsed
        metrics.gpuTemperature = gpu.temperature
        
        // Collect Disk metrics
        let disk = diskMetrics.collect()
        metrics.diskReadRate = disk.readRate
        metrics.diskWriteRate = disk.writeRate
        metrics.diskReadOps = disk.readOps
        metrics.diskWriteOps = disk.writeOps
        
        // Collect Thermal metrics
        let thermal = thermalMetrics.collect()
        metrics.cpuTemperature = thermal.cpuTemp
        if metrics.gpuTemperature == 0 {
            metrics.gpuTemperature = thermal.gpuTemp
        }
        metrics.fanSpeed = thermal.fanSpeed
        metrics.thermalState = thermal.state
        
        // Update published values
        await MainActor.run {
            self.currentMetrics = metrics
            self.metricsHistory.append(metrics)
            
            // Trim history to limit
            if self.metricsHistory.count > self.historyLimit {
                self.metricsHistory.removeFirst(self.metricsHistory.count - self.historyLimit)
            }
        }
    }
}

// MARK: - Convenience Computed Properties
extension MetricsCollector {
    /// Average CPU usage over last 30 seconds
    var averageCPU: Double {
        let recent = metricsHistory.suffix(15)  // 15 * 2s = 30s
        guard !recent.isEmpty else { return currentMetrics.cpuUsage }
        return recent.map(\.cpuUsage).reduce(0, +) / Double(recent.count)
    }
    
    /// Average memory usage over last 30 seconds
    var averageMemory: Double {
        let recent = metricsHistory.suffix(15)
        guard !recent.isEmpty else { return currentMetrics.memoryUsagePercent }
        return recent.map(\.memoryUsagePercent).reduce(0, +) / Double(recent.count)
    }
    
    /// Average GPU usage over last 30 seconds
    var averageGPU: Double {
        let recent = metricsHistory.suffix(15)
        guard !recent.isEmpty else { return currentMetrics.gpuUsage }
        return recent.map(\.gpuUsage).reduce(0, +) / Double(recent.count)
    }
    
    /// Trend direction for CPU (increasing, stable, decreasing)
    var cpuTrend: TrendDirection {
        calculateTrend(for: \.cpuUsage)
    }
    
    /// Trend direction for Memory
    var memoryTrend: TrendDirection {
        calculateTrend(for: \.memoryUsagePercent)
    }
    
    /// Trend direction for GPU
    var gpuTrend: TrendDirection {
        calculateTrend(for: \.gpuUsage)
    }
    
    private func calculateTrend(for keyPath: KeyPath<SystemMetrics, Double>) -> TrendDirection {
        let recent = metricsHistory.suffix(10)
        guard recent.count >= 5 else { return .stable }
        
        let values = recent.map { $0[keyPath: keyPath] }
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let diff = secondAvg - firstAvg
        if diff > 5 { return .increasing }
        if diff < -5 { return .decreasing }
        return .stable
    }
}

enum TrendDirection {
    case increasing
    case stable
    case decreasing
    
    var iconName: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }
    
    var color: String {
        switch self {
        case .increasing: return "red"
        case .stable: return "gray"
        case .decreasing: return "green"
        }
    }
}
