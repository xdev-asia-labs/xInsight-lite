import Foundation
import Darwin

/// Monitors running processes and their resource usage
@MainActor
class ProcessMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var processes: [ProcessInfo] = []
    @Published var groupedProcesses: [ProcessCategory: [ProcessInfo]] = [:]
    @Published var topCPUProcesses: [ProcessInfo] = []
    @Published var topMemoryProcesses: [ProcessInfo] = []
    
    // MARK: - Configuration
    private let updateInterval: TimeInterval = 3.0
    private let topProcessCount = 5
    
    // MARK: - Private
    private var updateTask: Task<Void, Never>?
    private var previousCPUTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]
    
    // MARK: - Initialization
    init() {
        startMonitoring()
    }
    
    deinit {
        updateTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateProcesses()
                try? await Task.sleep(nanoseconds: UInt64(self?.updateInterval ?? 3.0) * 1_000_000_000)
            }
        }
    }
    
    func stopMonitoring() {
        updateTask?.cancel()
        updateTask = nil
    }
    
    func refresh() async {
        await updateProcesses()
    }
    
    // MARK: - Process Listing
    
    private func updateProcesses() async {
        let processList = getProcessList()
        
        await MainActor.run {
            self.processes = processList
            self.updateGroupedProcesses()
            self.updateTopProcesses()
        }
    }
    
    private func getProcessList() -> [ProcessInfo] {
        var processes: [ProcessInfo] = []
        
        // Get list of all PIDs
        let pids = getAllPIDs()
        
        for pid in pids {
            if var processInfo = getProcessInfo(pid: pid) {
                // Calculate CPU usage
                processInfo.cpuUsage = calculateCPUUsage(for: pid)
                
                // Get memory usage
                processInfo.memoryUsage = MemoryMetrics.memoryUsage(for: pid)
                
                // Categorize process
                processInfo.category = ProcessCategory.categorize(
                    processName: processInfo.name,
                    bundleId: processInfo.bundleIdentifier
                )
                
                processes.append(processInfo)
            }
        }
        
        return processes.sorted { $0.cpuUsage > $1.cpuUsage }
    }
    
    private func getAllPIDs() -> [Int32] {
        // Get number of processes
        var numPids = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard numPids > 0 else { return [] }
        
        // Allocate buffer for PIDs
        let pidCount = Int(numPids) / MemoryLayout<Int32>.size
        var pids = [Int32](repeating: 0, count: pidCount)
        
        // Get actual PIDs
        numPids = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, numPids)
        
        // Filter out invalid PIDs (0)
        return pids.filter { $0 > 0 }
    }
    
    private func getProcessInfo(pid: Int32) -> ProcessInfo? {
        // Get process name - use MAXPATHLEN * 4 as the buffer size
        let maxPathSize = 4096  // PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN
        var pathBuffer = [CChar](repeating: 0, count: maxPathSize)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(maxPathSize))
        
        guard pathLength > 0 else { return nil }
        
        let path = String(cString: pathBuffer)
        let name = (path as NSString).lastPathComponent
        
        // Skip kernel and system processes we can't inspect
        if name.isEmpty || name == "kernel_task" && pid != 0 {
            // Keep kernel_task but skip truly empty ones
        }
        
        var process = ProcessInfo(pid: pid, name: name)
        
        // Get bundle identifier if it's an app
        if let bundleId = getBundleIdentifier(from: path) {
            process = ProcessInfo(pid: pid, name: name)
            // Note: Would set bundleIdentifier here if ProcessInfo had a mutable init
        }
        
        return process
    }
    
    private func getBundleIdentifier(from path: String) -> String? {
        // Check if path is inside an .app bundle
        if path.contains(".app/") {
            let components = path.components(separatedBy: ".app/")
            if let appPath = components.first {
                let fullAppPath = appPath + ".app"
                if let bundle = Bundle(path: fullAppPath) {
                    return bundle.bundleIdentifier
                }
            }
        }
        return nil
    }
    
    private func calculateCPUUsage(for pid: Int32) -> Double {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)
        guard result == size else { return 0 }
        
        let currentUser = taskInfo.pti_total_user
        let currentSystem = taskInfo.pti_total_system
        let now = Date()
        
        defer {
            previousCPUTimes[pid] = (currentUser, currentSystem, now)
        }
        
        guard let previous = previousCPUTimes[pid] else {
            return 0
        }
        
        let timeDelta = now.timeIntervalSince(previous.timestamp)
        guard timeDelta > 0.1 else { return 0 }  // Need at least 100ms
        
        let userDelta = currentUser - previous.user
        let systemDelta = currentSystem - previous.system
        let totalDelta = userDelta + systemDelta
        
        // pti_total_user/system are in Mach absolute time units
        // Convert using mach_timebase_info
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        
        // Convert to nanoseconds: ticks * numer / denom
        let nanoseconds = Double(totalDelta) * Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        
        // CPU percentage = (CPU nanoseconds / wall time nanoseconds) * 100
        let wallNanoseconds = timeDelta * 1_000_000_000
        let cpuPercent = (nanoseconds / wallNanoseconds) * 100
        
        return min(max(cpuPercent, 0), 400)  // Max 400% for 4+ cores
    }
    
    // MARK: - Grouping and Sorting
    
    private func updateGroupedProcesses() {
        var grouped: [ProcessCategory: [ProcessInfo]] = [:]
        
        for category in ProcessCategory.allCases {
            grouped[category] = []
        }
        
        for process in processes {
            grouped[process.category, default: []].append(process)
        }
        
        // Sort each group by CPU usage
        for (category, procs) in grouped {
            grouped[category] = procs.sorted { $0.cpuUsage > $1.cpuUsage }
        }
        
        self.groupedProcesses = grouped
    }
    
    private func updateTopProcesses() {
        topCPUProcesses = Array(processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(topProcessCount))
        
        topMemoryProcesses = Array(processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(topProcessCount))
    }
}

// MARK: - Process Actions
extension ProcessMonitor {
    /// Terminate a process gracefully
    func terminateProcess(_ process: ProcessInfo) -> Bool {
        let result = kill(process.pid, SIGTERM)
        return result == 0
    }
    
    /// Force quit a process
    func forceQuitProcess(_ process: ProcessInfo) -> Bool {
        let result = kill(process.pid, SIGKILL)
        return result == 0
    }
}
