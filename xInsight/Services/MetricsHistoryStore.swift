import Foundation
import SQLite3

/// MetricsHistoryStore - Persistent storage for metrics history
/// Uses SQLite for efficient long-term storage of system metrics
@MainActor
final class MetricsHistoryStore: ObservableObject {
    static let shared = MetricsHistoryStore()
    
    // MARK: - Published Properties
    @Published var isReady: Bool = false
    @Published var totalSnapshots: Int = 0
    @Published var oldestSnapshot: Date?
    @Published var newestSnapshot: Date?
    
    // MARK: - Configuration
    private let retentionDays: Int = 30  // Keep 30 days of data
    private let sampleInterval: TimeInterval = 300  // 5 minutes between samples
    
    // MARK: - SQLite
    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.xinsight.metricsdb", qos: .utility)
    
    // MARK: - Initialization
    private init() {
        setupDatabase()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Database Setup
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        
        // Create Application Support directory if needed
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("MetricsHistoryStore: Could not find Application Support directory")
            return
        }
        
        let xInsightDir = appSupport.appendingPathComponent("xInsight", isDirectory: true)
        
        do {
            try fileManager.createDirectory(at: xInsightDir, withIntermediateDirectories: true)
        } catch {
            print("MetricsHistoryStore: Failed to create directory: \(error)")
            return
        }
        
        let dbPath = xInsightDir.appendingPathComponent("metrics_history.sqlite").path
        
        // Open database on dbQueue for thread safety
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            var dbPointer: OpaquePointer?
            if sqlite3_open(dbPath, &dbPointer) == SQLITE_OK {
                // Store db pointer
                Task { @MainActor [weak self] in
                    self?.db = dbPointer
                    self?.createTablesAsync()
                }
            } else {
                print("MetricsHistoryStore: Failed to open database")
            }
        }
    }
    
    @MainActor
    private func createTablesAsync() {
        guard let db = db else { return }
        
        dbQueue.async { [weak self] in
            self?.createTablesOnQueue(db: db)
            
            Task { @MainActor [weak self] in
                self?.isReady = true
                self?.updateStats()
            }
        }
    }
    
    private func createTablesOnQueue(db: OpaquePointer) {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS metrics_snapshots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp REAL NOT NULL,
            cpu_usage REAL DEFAULT 0,
            cpu_p_cores REAL DEFAULT 0,
            cpu_e_cores REAL DEFAULT 0,
            memory_used INTEGER DEFAULT 0,
            memory_total INTEGER DEFAULT 0,
            memory_pressure TEXT DEFAULT 'Normal',
            gpu_usage REAL DEFAULT 0,
            gpu_memory INTEGER DEFAULT 0,
            disk_read_rate REAL DEFAULT 0,
            disk_write_rate REAL DEFAULT 0,
            cpu_temperature REAL DEFAULT 0,
            gpu_temperature REAL DEFAULT 0,
            fan_speed INTEGER DEFAULT 0,
            thermal_state TEXT DEFAULT 'Nominal',
            network_bytes_in INTEGER DEFAULT 0,
            network_bytes_out INTEGER DEFAULT 0,
            active_process_count INTEGER DEFAULT 0,
            top_processes TEXT DEFAULT ''
        );
        
        CREATE INDEX IF NOT EXISTS idx_timestamp ON metrics_snapshots(timestamp);
        """
        
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTableSQL, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("MetricsHistoryStore: Error creating table: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Save a metrics snapshot to the database
    func saveSnapshot(_ metrics: SystemMetrics, activeProcessCount: Int = 0, topProcesses: [String] = []) {
        guard isReady else { return }
        
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let insertSQL = """
            INSERT INTO metrics_snapshots (
                timestamp, cpu_usage, cpu_p_cores, cpu_e_cores,
                memory_used, memory_total, memory_pressure,
                gpu_usage, gpu_memory,
                disk_read_rate, disk_write_rate,
                cpu_temperature, gpu_temperature, fan_speed, thermal_state,
                network_bytes_in, network_bytes_out,
                active_process_count, top_processes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
                let timestamp = metrics.timestamp.timeIntervalSince1970
                let topProcessesJSON = (try? JSONEncoder().encode(topProcesses)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                
                sqlite3_bind_double(stmt, 1, timestamp)
                sqlite3_bind_double(stmt, 2, metrics.cpuUsage)
                sqlite3_bind_double(stmt, 3, metrics.cpuPerformanceCores)
                sqlite3_bind_double(stmt, 4, metrics.cpuEfficiencyCores)
                sqlite3_bind_int64(stmt, 5, Int64(metrics.memoryUsed))
                sqlite3_bind_int64(stmt, 6, Int64(metrics.memoryTotal))
                sqlite3_bind_text(stmt, 7, metrics.memoryPressure.rawValue, -1, nil)
                sqlite3_bind_double(stmt, 8, metrics.gpuUsage)
                sqlite3_bind_int64(stmt, 9, Int64(metrics.gpuMemoryUsed))
                sqlite3_bind_double(stmt, 10, metrics.diskReadRate)
                sqlite3_bind_double(stmt, 11, metrics.diskWriteRate)
                sqlite3_bind_double(stmt, 12, metrics.cpuTemperature)
                sqlite3_bind_double(stmt, 13, metrics.gpuTemperature)
                sqlite3_bind_int(stmt, 14, Int32(metrics.fanSpeed))
                sqlite3_bind_text(stmt, 15, metrics.thermalState.rawValue, -1, nil)
                sqlite3_bind_int64(stmt, 16, Int64(metrics.networkBytesIn))
                sqlite3_bind_int64(stmt, 17, Int64(metrics.networkBytesOut))
                sqlite3_bind_int(stmt, 18, Int32(activeProcessCount))
                sqlite3_bind_text(stmt, 19, topProcessesJSON, -1, nil)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("MetricsHistoryStore: Error inserting snapshot")
                }
                sqlite3_finalize(stmt)
                
                Task { @MainActor in
                    self.updateStats()
                }
            }
        }
    }
    
    /// Get metrics for a specific time range
    func getMetrics(from startDate: Date, to endDate: Date) async -> [MetricsSnapshot] {
        guard isReady else { return [] }
        
        return await withCheckedContinuation { continuation in
            dbQueue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }
                
                var snapshots: [MetricsSnapshot] = []
                
                let querySQL = """
                SELECT * FROM metrics_snapshots
                WHERE timestamp BETWEEN ? AND ?
                ORDER BY timestamp ASC
                """
                
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_double(stmt, 1, startDate.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 2, endDate.timeIntervalSince1970)
                    
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let snapshot = self.parseSnapshot(stmt: stmt)
                        snapshots.append(snapshot)
                    }
                    sqlite3_finalize(stmt)
                }
                
                continuation.resume(returning: snapshots)
            }
        }
    }
    
    /// Get hourly averages for a date range
    func getHourlyAverages(from startDate: Date, to endDate: Date) async -> [HourlyMetrics] {
        guard isReady else { return [] }
        
        return await withCheckedContinuation { continuation in
            dbQueue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }
                
                var hourlyData: [HourlyMetrics] = []
                
                let querySQL = """
                SELECT 
                    strftime('%Y-%m-%d %H:00:00', datetime(timestamp, 'unixepoch')) as hour_bucket,
                    AVG(cpu_usage) as avg_cpu,
                    AVG(memory_used) as avg_memory,
                    AVG(gpu_usage) as avg_gpu,
                    AVG(cpu_temperature) as avg_temp,
                    MAX(cpu_usage) as max_cpu,
                    MAX(memory_used) as max_memory,
                    COUNT(*) as sample_count
                FROM metrics_snapshots
                WHERE timestamp BETWEEN ? AND ?
                GROUP BY hour_bucket
                ORDER BY hour_bucket ASC
                """
                
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_double(stmt, 1, startDate.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 2, endDate.timeIntervalSince1970)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    dateFormatter.timeZone = TimeZone(identifier: "UTC")
                    
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let hourStr = sqlite3_column_text(stmt, 0) {
                            let hourString = String(cString: hourStr)
                            if let date = dateFormatter.date(from: hourString) {
                                let hourly = HourlyMetrics(
                                    hour: date,
                                    avgCPU: sqlite3_column_double(stmt, 1),
                                    avgMemory: Double(sqlite3_column_int64(stmt, 2)),
                                    avgGPU: sqlite3_column_double(stmt, 3),
                                    avgTemperature: sqlite3_column_double(stmt, 4),
                                    maxCPU: sqlite3_column_double(stmt, 5),
                                    maxMemory: Double(sqlite3_column_int64(stmt, 6)),
                                    sampleCount: Int(sqlite3_column_int(stmt, 7))
                                )
                                hourlyData.append(hourly)
                            }
                        }
                    }
                    sqlite3_finalize(stmt)
                }
                
                continuation.resume(returning: hourlyData)
            }
        }
    }
    
    /// Get daily averages for a date range
    func getDailyAverages(from startDate: Date, to endDate: Date) async -> [DailyMetrics] {
        guard isReady else { return [] }
        
        return await withCheckedContinuation { continuation in
            dbQueue.async { [weak self] in
                guard let self = self, let db = self.db else {
                    continuation.resume(returning: [])
                    return
                }
                
                var dailyData: [DailyMetrics] = []
                
                let querySQL = """
                SELECT 
                    date(datetime(timestamp, 'unixepoch')) as day_bucket,
                    AVG(cpu_usage) as avg_cpu,
                    AVG(memory_used) as avg_memory,
                    AVG(gpu_usage) as avg_gpu,
                    AVG(cpu_temperature) as avg_temp,
                    MAX(cpu_usage) as max_cpu,
                    MAX(cpu_temperature) as max_temp,
                    COUNT(*) as sample_count
                FROM metrics_snapshots
                WHERE timestamp BETWEEN ? AND ?
                GROUP BY day_bucket
                ORDER BY day_bucket ASC
                """
                
                var stmt: OpaquePointer?
                if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_double(stmt, 1, startDate.timeIntervalSince1970)
                    sqlite3_bind_double(stmt, 2, endDate.timeIntervalSince1970)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        if let dayStr = sqlite3_column_text(stmt, 0) {
                            let dayString = String(cString: dayStr)
                            if let date = dateFormatter.date(from: dayString) {
                                let daily = DailyMetrics(
                                    date: date,
                                    avgCPU: sqlite3_column_double(stmt, 1),
                                    avgMemory: Double(sqlite3_column_int64(stmt, 2)),
                                    avgGPU: sqlite3_column_double(stmt, 3),
                                    avgTemperature: sqlite3_column_double(stmt, 4),
                                    maxCPU: sqlite3_column_double(stmt, 5),
                                    maxTemperature: sqlite3_column_double(stmt, 6),
                                    sampleCount: Int(sqlite3_column_int(stmt, 7))
                                )
                                dailyData.append(daily)
                            }
                        }
                    }
                    sqlite3_finalize(stmt)
                }
                
                continuation.resume(returning: dailyData)
            }
        }
    }
    
    /// Clean up old data beyond retention period
    func cleanupOldData() {
        guard isReady else { return }
        
        dbQueue.async { [weak self] in
            guard let self = self, let db = self.db else { return }
            
            let cutoffDate = Date().addingTimeInterval(-Double(self.retentionDays * 24 * 60 * 60))
            
            let deleteSQL = "DELETE FROM metrics_snapshots WHERE timestamp < ?"
            
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_double(stmt, 1, cutoffDate.timeIntervalSince1970)
                
                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("MetricsHistoryStore: Error cleaning up old data")
                } else {
                    let deletedCount = sqlite3_changes(db)
                    if deletedCount > 0 {
                        print("MetricsHistoryStore: Cleaned up \(deletedCount) old snapshots")
                    }
                }
                sqlite3_finalize(stmt)
                
                // Vacuum to reclaim space
                sqlite3_exec(db, "VACUUM", nil, nil, nil)
                
                Task { @MainActor in
                    self.updateStats()
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateStats() {
        guard isReady, let db = db else { return }
        
        dbQueue.async { [weak self] in
            guard let self = self else { return }
            
            var count = 0
            var oldest: Date?
            var newest: Date?
            
            // Get count
            let countSQL = "SELECT COUNT(*) FROM metrics_snapshots"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    count = Int(sqlite3_column_int(stmt, 0))
                }
                sqlite3_finalize(stmt)
            }
            
            // Get oldest
            let oldestSQL = "SELECT MIN(timestamp) FROM metrics_snapshots"
            if sqlite3_prepare_v2(db, oldestSQL, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let timestamp = sqlite3_column_double(stmt, 0)
                    if timestamp > 0 {
                        oldest = Date(timeIntervalSince1970: timestamp)
                    }
                }
                sqlite3_finalize(stmt)
            }
            
            // Get newest
            let newestSQL = "SELECT MAX(timestamp) FROM metrics_snapshots"
            if sqlite3_prepare_v2(db, newestSQL, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let timestamp = sqlite3_column_double(stmt, 0)
                    if timestamp > 0 {
                        newest = Date(timeIntervalSince1970: timestamp)
                    }
                }
                sqlite3_finalize(stmt)
            }
            
            Task { @MainActor in
                self.totalSnapshots = count
                self.oldestSnapshot = oldest
                self.newestSnapshot = newest
            }
        }
    }
    
    private func parseSnapshot(stmt: OpaquePointer?) -> MetricsSnapshot {
        guard let stmt = stmt else {
            return MetricsSnapshot()
        }
        
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
        let memoryPressureStr = sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "Normal"
        let thermalStateStr = sqlite3_column_text(stmt, 15).map { String(cString: $0) } ?? "Nominal"
        let topProcessesJSON = sqlite3_column_text(stmt, 19).map { String(cString: $0) } ?? "[]"
        let topProcesses = (try? JSONDecoder().decode([String].self, from: Data(topProcessesJSON.utf8))) ?? []
        
        return MetricsSnapshot(
            id: Int(sqlite3_column_int64(stmt, 0)),
            timestamp: timestamp,
            cpuUsage: sqlite3_column_double(stmt, 2),
            cpuPCores: sqlite3_column_double(stmt, 3),
            cpuECores: sqlite3_column_double(stmt, 4),
            memoryUsed: UInt64(sqlite3_column_int64(stmt, 5)),
            memoryTotal: UInt64(sqlite3_column_int64(stmt, 6)),
            memoryPressure: MemoryPressure(rawValue: memoryPressureStr) ?? .normal,
            gpuUsage: sqlite3_column_double(stmt, 8),
            gpuMemory: UInt64(sqlite3_column_int64(stmt, 9)),
            diskReadRate: sqlite3_column_double(stmt, 10),
            diskWriteRate: sqlite3_column_double(stmt, 11),
            cpuTemperature: sqlite3_column_double(stmt, 12),
            gpuTemperature: sqlite3_column_double(stmt, 13),
            fanSpeed: Int(sqlite3_column_int(stmt, 14)),
            thermalState: ThermalState(rawValue: thermalStateStr) ?? .nominal,
            networkBytesIn: UInt64(sqlite3_column_int64(stmt, 16)),
            networkBytesOut: UInt64(sqlite3_column_int64(stmt, 17)),
            activeProcessCount: Int(sqlite3_column_int(stmt, 18)),
            topProcesses: topProcesses
        )
    }
}

// MARK: - Data Models

/// A single metrics snapshot from the database
struct MetricsSnapshot: Identifiable {
    let id: Int
    let timestamp: Date
    let cpuUsage: Double
    let cpuPCores: Double
    let cpuECores: Double
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let memoryPressure: MemoryPressure
    let gpuUsage: Double
    let gpuMemory: UInt64
    let diskReadRate: Double
    let diskWriteRate: Double
    let cpuTemperature: Double
    let gpuTemperature: Double
    let fanSpeed: Int
    let thermalState: ThermalState
    let networkBytesIn: UInt64
    let networkBytesOut: UInt64
    let activeProcessCount: Int
    let topProcesses: [String]
    
    init(
        id: Int = 0,
        timestamp: Date = Date(),
        cpuUsage: Double = 0,
        cpuPCores: Double = 0,
        cpuECores: Double = 0,
        memoryUsed: UInt64 = 0,
        memoryTotal: UInt64 = 0,
        memoryPressure: MemoryPressure = .normal,
        gpuUsage: Double = 0,
        gpuMemory: UInt64 = 0,
        diskReadRate: Double = 0,
        diskWriteRate: Double = 0,
        cpuTemperature: Double = 0,
        gpuTemperature: Double = 0,
        fanSpeed: Int = 0,
        thermalState: ThermalState = .nominal,
        networkBytesIn: UInt64 = 0,
        networkBytesOut: UInt64 = 0,
        activeProcessCount: Int = 0,
        topProcesses: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.cpuPCores = cpuPCores
        self.cpuECores = cpuECores
        self.memoryUsed = memoryUsed
        self.memoryTotal = memoryTotal
        self.memoryPressure = memoryPressure
        self.gpuUsage = gpuUsage
        self.gpuMemory = gpuMemory
        self.diskReadRate = diskReadRate
        self.diskWriteRate = diskWriteRate
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.fanSpeed = fanSpeed
        self.thermalState = thermalState
        self.networkBytesIn = networkBytesIn
        self.networkBytesOut = networkBytesOut
        self.activeProcessCount = activeProcessCount
        self.topProcesses = topProcesses
    }
    
    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100
    }
}

/// Hourly aggregated metrics
struct HourlyMetrics: Identifiable {
    var id: Date { hour }
    let hour: Date
    let avgCPU: Double
    let avgMemory: Double
    let avgGPU: Double
    let avgTemperature: Double
    let maxCPU: Double
    let maxMemory: Double
    let sampleCount: Int
}

/// Daily aggregated metrics
struct DailyMetrics: Identifiable {
    var id: Date { date }
    let date: Date
    let avgCPU: Double
    let avgMemory: Double
    let avgGPU: Double
    let avgTemperature: Double
    let maxCPU: Double
    let maxTemperature: Double
    let sampleCount: Int
}
