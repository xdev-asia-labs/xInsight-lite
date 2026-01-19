import Foundation

/// PerformanceBenchmarks - Run and track system benchmarks
@MainActor
final class PerformanceBenchmarks: ObservableObject {
    static let shared = PerformanceBenchmarks()
    
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var currentBenchmark: BenchmarkType?
    @Published var progress: Double = 0
    @Published var results: [BenchmarkResult] = []
    @Published var history: [BenchmarkSession] = []
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Run Benchmarks
    
    func runAllBenchmarks() async {
        isRunning = true
        defer { 
            isRunning = false 
            currentBenchmark = nil
            progress = 0
        }
        
        var sessionResults: [BenchmarkResult] = []
        let benchmarks: [BenchmarkType] = [.cpuSingle, .cpuMulti, .memory, .disk, .graphics]
        
        for (index, benchmark) in benchmarks.enumerated() {
            currentBenchmark = benchmark
            progress = Double(index) / Double(benchmarks.count)
            
            let result = await runBenchmark(benchmark)
            sessionResults.append(result)
            results = sessionResults
        }
        
        progress = 1.0
        
        // Save session
        let session = BenchmarkSession(
            id: UUID(),
            date: Date(),
            results: sessionResults
        )
        history.insert(session, at: 0)
        saveHistory()
    }
    
    func runBenchmark(_ type: BenchmarkType) async -> BenchmarkResult {
        let startTime = Date()
        var score: Double = 0
        
        switch type {
        case .cpuSingle:
            score = await runCPUSingleCore()
        case .cpuMulti:
            score = await runCPUMultiCore()
        case .memory:
            score = await runMemory()
        case .disk:
            score = await runDisk()
        case .graphics:
            score = await runGraphics()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return BenchmarkResult(
            type: type,
            score: score,
            duration: duration,
            date: Date()
        )
    }
    
    // MARK: - CPU Single Core
    
    private func runCPUSingleCore() async -> Double {
        let iterations = 50_000_000
        let start = Date()
        
        var result: Double = 0
        for i in 0..<iterations {
            result += sin(Double(i)) * cos(Double(i))
        }
        
        let elapsed = Date().timeIntervalSince(start)
        // Higher is better - normalize to ~1000 for M3 Max
        return (Double(iterations) / elapsed) / 50_000
    }
    
    // MARK: - CPU Multi Core
    
    private func runCPUMultiCore() async -> Double {
        let coreCount = Foundation.ProcessInfo.processInfo.activeProcessorCount
        let iterationsPerCore = 20_000_000
        let start = Date()
        
        await withTaskGroup(of: Double.self) { group in
            for _ in 0..<coreCount {
                group.addTask {
                    var result: Double = 0
                    for i in 0..<iterationsPerCore {
                        result += sin(Double(i)) * cos(Double(i))
                    }
                    return result
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(start)
        return (Double(coreCount * iterationsPerCore) / elapsed) / 50_000
    }
    
    // MARK: - Memory
    
    private func runMemory() async -> Double {
        let size = 100_000_000  // 100MB
        let start = Date()
        
        // Allocation
        var array = [UInt8](repeating: 0, count: size)
        
        // Sequential write
        for i in 0..<size {
            array[i] = UInt8(i & 0xFF)
        }
        
        // Random read
        var sum: UInt64 = 0
        for _ in 0..<1_000_000 {
            let index = Int.random(in: 0..<size)
            sum += UInt64(array[index])
        }
        
        let elapsed = Date().timeIntervalSince(start)
        // Normalize to ~1000
        return (Double(size) / elapsed) / 100_000
    }
    
    // MARK: - Disk
    
    private func runDisk() async -> Double {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("xinsight_bench_\(UUID().uuidString)")
        let size = 50_000_000  // 50MB
        let data = Data(count: size)
        
        let start = Date()
        
        // Write
        try? data.write(to: testFile)
        
        // Read
        _ = try? Data(contentsOf: testFile)
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
        
        let elapsed = Date().timeIntervalSince(start)
        // MB/s normalized to score
        return (Double(size * 2) / elapsed) / 1_000_000 * 10
    }
    
    // MARK: - Graphics (CPU fallback)
    
    private func runGraphics() async -> Double {
        // Simple matrix operations as GPU proxy
        let size = 500
        let start = Date()
        
        var matrixA = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        var matrixB = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        var result = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        
        // Initialize
        for i in 0..<size {
            for j in 0..<size {
                matrixA[i][j] = Double.random(in: 0...1)
                matrixB[i][j] = Double.random(in: 0...1)
            }
        }
        
        // Multiply
        for i in 0..<size {
            for j in 0..<size {
                for k in 0..<size {
                    result[i][j] += matrixA[i][k] * matrixB[k][j]
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(start)
        // GFLOPS normalized
        let flops = Double(size * size * size * 2)
        return (flops / elapsed) / 1_000_000_000 * 100
    }
    
    // MARK: - History
    
    private func loadHistory() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "benchmark_history"),
           let sessions = try? JSONDecoder().decode([BenchmarkSession].self, from: data) {
            history = sessions
        }
    }
    
    private func saveHistory() {
        // Keep only last 10 sessions
        let toSave = Array(history.prefix(10))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: "benchmark_history")
        }
    }
    
    // MARK: - Comparison
    
    func compareWithBaseline() -> [String] {
        guard let latest = history.first else { return [] }
        
        // M3 Max baseline scores (approximate)
        let baselines: [BenchmarkType: Double] = [
            .cpuSingle: 1000,
            .cpuMulti: 12000,
            .memory: 1000,
            .disk: 500,
            .graphics: 800
        ]
        
        var comparisons: [String] = []
        
        for result in latest.results {
            if let baseline = baselines[result.type] {
                let percent = (result.score / baseline) * 100
                comparisons.append("\(result.type.rawValue): \(String(format: "%.0f", percent))% of M3 Max")
            }
        }
        
        return comparisons
    }
}

// MARK: - Models

enum BenchmarkType: String, Codable, CaseIterable {
    case cpuSingle = "CPU Single-Core"
    case cpuMulti = "CPU Multi-Core"
    case memory = "Memory"
    case disk = "Disk I/O"
    case graphics = "Graphics"
    
    var icon: String {
        switch self {
        case .cpuSingle, .cpuMulti: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .graphics: return "gpu"
        }
    }
}

struct BenchmarkResult: Identifiable, Codable {
    let id = UUID()
    let type: BenchmarkType
    let score: Double
    let duration: TimeInterval
    let date: Date
    
    var formattedScore: String {
        String(format: "%.0f", score)
    }
}

struct BenchmarkSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let results: [BenchmarkResult]
    
    var totalScore: Double {
        results.reduce(0) { $0 + $1.score }
    }
}
