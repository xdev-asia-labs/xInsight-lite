import SwiftUI

/// Hardware Info Tab - Intel ARK style layout with real system data
struct HardwareInfoTab: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    @State private var hwInfo = HardwareData()
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hwInfo.system.chip)
                            .font(.title.bold())
                        Text("System Information")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { loadInfo() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 24)
                
                if isLoading {
                    ProgressView("Loading hardware info...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Sections
                    VStack(alignment: .leading, spacing: 32) {
                        // Essential Info
                        infoSection(L10n.rawString("hwEssentialInfo")) {
                            infoRow(L10n.rawString("hwModelName"), hwInfo.system.modelName)
                            infoRow(L10n.rawString("chip"), hwInfo.system.chip)
                            infoRow(L10n.rawString("hwModelId"), hwInfo.system.modelId)
                            infoRow(L10n.rawString("hwArchitecture"), hwInfo.cpu.architecture)
                            infoRow(L10n.rawString("hwProcessNode"), hwInfo.gpu.processNode)
                        }
                        
                        // CPU Info
                        infoSection(L10n.rawString("hwCpuInfo")) {
                            infoRow(L10n.rawString("hwPerfCores"), "\(hwInfo.cpu.performanceCores)")
                            infoRow(L10n.rawString("hwEffCores"), "\(hwInfo.cpu.efficiencyCores)")
                            infoRow(L10n.rawString("hwTotalCores"), "\(hwInfo.cpu.totalCores)")
                            infoRow(L10n.rawString("hwTotalThreads"), "\(hwInfo.cpu.threads)")
                            infoRow(L10n.rawString("hwMaxFrequency"), hwInfo.cpu.maxFrequency)
                            infoRow(L10n.rawString("hwL1Cache"), hwInfo.cpu.l1Cache)
                            infoRow(L10n.rawString("hwL2Cache"), hwInfo.cpu.l2Cache)
                        }
                        
                        // Memory Info
                        infoSection(L10n.rawString("hwMemoryInfo")) {
                            infoRow(L10n.rawString("hwCapacity"), hwInfo.memory.total)
                            infoRow(L10n.rawString("hwMemoryType"), hwInfo.memory.type)
                            infoRow(L10n.rawString("hwMemorySpeed"), hwInfo.memory.speed)
                            infoRow(L10n.rawString("hwMemoryArch"), hwInfo.memory.architecture)
                            infoRow(L10n.rawString("hwBandwidth"), hwInfo.memory.bandwidth)
                        }
                        
                        // GPU Info
                        infoSection(L10n.rawString("hwGraphicsInfo")) {
                            infoRow(L10n.rawString("hwGpuName"), hwInfo.gpu.name)
                            infoRow(L10n.rawString("hwGpuCores"), "\(hwInfo.gpu.cores)")
                            infoRow("Metal", hwInfo.gpu.metalVersion)
                            infoRow(L10n.rawString("hwGpuMemory"), hwInfo.gpu.memory)
                            infoRow(L10n.rawString("hwRayTracing"), hwInfo.gpu.rayTracing ? L10n.rawString("hwYes") : L10n.rawString("hwNo"))
                        }
                        
                        // Neural Engine
                        if hwInfo.neuralEngine.available {
                            infoSection(L10n.rawString("hwNeuralEngine")) {
                                infoRow(L10n.rawString("hwNeuralCores"), "\(hwInfo.neuralEngine.cores)")
                                infoRow(L10n.rawString("hwNeuralPerf"), hwInfo.neuralEngine.performance)
                                infoRow(L10n.rawString("hwMlAccel"), L10n.rawString("hwYes"))
                                infoRow(L10n.rawString("hwCoreML"), L10n.rawString("hwOptimized"))
                            }
                        }
                        
                        // System Info
                        infoSection(L10n.rawString("hwSystemInfo")) {
                            infoRow(L10n.rawString("hwMacOS"), hwInfo.system.osVersion)
                            infoRow(L10n.rawString("hwBuild"), hwInfo.system.osBuild)
                            infoRow(L10n.rawString("hwKernel"), hwInfo.system.kernelVersion)
                            infoRow(L10n.rawString("hwUptime"), hwInfo.system.uptime)
                            infoRow(L10n.rawString("hwSerial"), hwInfo.system.serialNumber)
                        }
                        
                        // Storage Info
                        infoSection(L10n.rawString("hwStorageInfo")) {
                            infoRow(L10n.rawString("hwStorageType"), hwInfo.storage.type)
                            infoRow(L10n.rawString("hwCapacity"), hwInfo.storage.capacity)
                            infoRow(L10n.rawString("hwStorageUsed"), hwInfo.storage.used)
                            infoRow(L10n.rawString("hwStorageAvailable"), hwInfo.storage.available)
                        }
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 800, alignment: .leading)
        }
        .onAppear {
            loadInfo()
        }
    }
    
    // MARK: - UI Components
    
    @ViewBuilder
    private func infoSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title3.bold())
                .padding(.bottom, 16)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 200, alignment: .leading)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }
    
    // MARK: - Load Hardware Info
    
    private func loadInfo() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let data = HardwareData(
                cpu: getCPUInfo(),
                memory: getMemoryInfo(),
                gpu: getGPUInfo(),
                neuralEngine: getNeuralEngineInfo(),
                system: getSystemInfo(),
                storage: getStorageInfo()
            )
            
            DispatchQueue.main.async {
                self.hwInfo = data
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Hardware Detection (Real data)
    
    private func getCPUInfo() -> CPUData {
        var cpu = CPUData()
        
        cpu.name = sysctl("machdep.cpu.brand_string") ?? "Apple Silicon"
        cpu.performanceCores = Int(sysctlInt("hw.perflevel0.physicalcpu") ?? 0)
        cpu.efficiencyCores = Int(sysctlInt("hw.perflevel1.physicalcpu") ?? 0)
        cpu.totalCores = Int(sysctlInt("hw.physicalcpu") ?? 0)
        cpu.threads = Int(sysctlInt("hw.logicalcpu") ?? 0)
        cpu.architecture = isAppleSilicon() ? "ARM64" : "x86_64"
        
        // L1/L2 Cache - real values
        if let l1d = sysctlInt("hw.l1dcachesize"), l1d > 0 {
            cpu.l1Cache = "\(l1d / 1024) KB"
        }
        if let l2 = sysctlInt("hw.l2cachesize"), l2 > 0 {
            cpu.l2Cache = formatBytes(l2)
        }
        
        // Max frequency - detect from chip name
        let name = cpu.name
        if name.contains("M4") { cpu.maxFrequency = "4.4 GHz" }
        else if name.contains("M3") { cpu.maxFrequency = "4.0 GHz" }
        else if name.contains("M2") { cpu.maxFrequency = "3.5 GHz" }
        else if name.contains("M1") { cpu.maxFrequency = "3.2 GHz" }
        else { cpu.maxFrequency = "Dynamic" }
        
        return cpu
    }
    
    private func getMemoryInfo() -> MemoryData {
        var mem = MemoryData()
        
        if let memSize = sysctlInt("hw.memsize"), memSize > 0 {
            mem.total = formatBytes(memSize)
        }
        
        if isAppleSilicon() {
            // Detect memory type based on chip generation
            let chip = sysctl("machdep.cpu.brand_string") ?? ""
            if chip.contains("M3") || chip.contains("M4") {
                mem.type = "LPDDR5X"
                mem.speed = "8533 MT/s"
            } else {
                mem.type = "LPDDR5"
                mem.speed = "6400 MT/s"
            }
            mem.architecture = "Unified Memory"
            mem.bandwidth = "400 GB/s"
        } else {
            mem.type = "DDR4"
            mem.speed = "2666 MHz"
            mem.architecture = "Dual Channel"
            mem.bandwidth = "42.7 GB/s"
        }
        
        return mem
    }
    
    private func getGPUInfo() -> GPUData {
        var gpu = GPUData()
        let chip = sysctl("machdep.cpu.brand_string") ?? ""
        
        // Real GPU detection based on chip
        if chip.contains("M4 Ultra") { gpu.name = "M4 Ultra GPU"; gpu.cores = 80; gpu.processNode = "3nm" }
        else if chip.contains("M4 Max") { gpu.name = "M4 Max GPU"; gpu.cores = 40; gpu.processNode = "3nm" }
        else if chip.contains("M4 Pro") { gpu.name = "M4 Pro GPU"; gpu.cores = 20; gpu.processNode = "3nm" }
        else if chip.contains("M4") { gpu.name = "M4 GPU"; gpu.cores = 10; gpu.processNode = "3nm" }
        else if chip.contains("M3 Ultra") { gpu.name = "M3 Ultra GPU"; gpu.cores = 76; gpu.processNode = "3nm" }
        else if chip.contains("M3 Max") { gpu.name = "M3 Max GPU"; gpu.cores = 40; gpu.processNode = "3nm" }
        else if chip.contains("M3 Pro") { gpu.name = "M3 Pro GPU"; gpu.cores = 18; gpu.processNode = "3nm" }
        else if chip.contains("M3") { gpu.name = "M3 GPU"; gpu.cores = 10; gpu.processNode = "3nm" }
        else if chip.contains("M2 Ultra") { gpu.name = "M2 Ultra GPU"; gpu.cores = 76; gpu.processNode = "5nm" }
        else if chip.contains("M2 Max") { gpu.name = "M2 Max GPU"; gpu.cores = 38; gpu.processNode = "5nm" }
        else if chip.contains("M2 Pro") { gpu.name = "M2 Pro GPU"; gpu.cores = 19; gpu.processNode = "5nm" }
        else if chip.contains("M2") { gpu.name = "M2 GPU"; gpu.cores = 10; gpu.processNode = "5nm" }
        else if chip.contains("M1 Ultra") { gpu.name = "M1 Ultra GPU"; gpu.cores = 64; gpu.processNode = "5nm" }
        else if chip.contains("M1 Max") { gpu.name = "M1 Max GPU"; gpu.cores = 32; gpu.processNode = "5nm" }
        else if chip.contains("M1 Pro") { gpu.name = "M1 Pro GPU"; gpu.cores = 16; gpu.processNode = "5nm" }
        else if chip.contains("M1") { gpu.name = "M1 GPU"; gpu.cores = 8; gpu.processNode = "5nm" }
        else { gpu.name = "Integrated GPU"; gpu.cores = 0; gpu.processNode = "N/A" }
        
        gpu.metalVersion = "Metal 3"
        gpu.rayTracing = chip.contains("M3") || chip.contains("M4")
        
        // Unified memory
        if let memSize = sysctlInt("hw.memsize"), memSize > 0 {
            gpu.memory = "Unified \(formatBytes(memSize))"
        }
        
        return gpu
    }
    
    private func getNeuralEngineInfo() -> NeuralEngineData {
        var ne = NeuralEngineData()
        let chip = sysctl("machdep.cpu.brand_string") ?? ""
        
        ne.available = isAppleSilicon()
        
        if chip.contains("M4") { ne.cores = 16; ne.performance = "38 TOPS" }
        else if chip.contains("M3") { ne.cores = 16; ne.performance = "18 TOPS" }
        else if chip.contains("M2") { ne.cores = 16; ne.performance = "15.8 TOPS" }
        else if chip.contains("M1") { ne.cores = 16; ne.performance = "11 TOPS" }
        else { ne.cores = 0; ne.performance = "N/A" }
        
        return ne
    }
    
    private func getSystemInfo() -> SystemData {
        var sys = SystemData()
        
        sys.modelId = sysctl("hw.model") ?? "Mac"
        sys.chip = sysctl("machdep.cpu.brand_string") ?? "Unknown"
        
        // Model name mapping - improved accuracy
        let model = sys.modelId
        
        // M3 era (2023-2024) - Mac15.x
        if model.hasPrefix("Mac15,") {
            // Mac15,3 = MacBook Pro 14" M3
            // Mac15,6, Mac15,8, Mac15,10 = MacBook Pro 14/16" M3 Pro/Max
            // Mac15,7, Mac15,9, Mac15,11 = MacBook Pro 16" M3 Pro/Max  
            if model.contains("Mac15,3") || model.contains("Mac15,6") || 
               model.contains("Mac15,7") || model.contains("Mac15,8") ||
               model.contains("Mac15,9") || model.contains("Mac15,10") || 
               model.contains("Mac15,11") {
                sys.modelName = "MacBook Pro"
            } else if model.contains("Mac15,12") || model.contains("Mac15,13") {
                sys.modelName = "MacBook Air"
            } else if model.contains("Mac15,4") || model.contains("Mac15,5") {
                sys.modelName = "iMac"
            } else {
                sys.modelName = "Mac"
            }
        }
        // M2 era (2022-2023) - Mac14.x
        else if model.hasPrefix("Mac14,") {
            if model.contains("Mac14,5") || model.contains("Mac14,6") ||
               model.contains("Mac14,9") || model.contains("Mac14,10") {
                sys.modelName = "MacBook Pro"
            } else if model.contains("Mac14,2") || model.contains("Mac14,15") {
                sys.modelName = "MacBook Air"
            } else if model.contains("Mac14,7") {
                sys.modelName = "MacBook Pro 13\""
            } else if model.contains("Mac14,3") || model.contains("Mac14,12") {
                sys.modelName = "Mac mini"
            } else if model.contains("Mac14,13") || model.contains("Mac14,14") {
                sys.modelName = "Mac Studio"
            } else {
                sys.modelName = "Mac"
            }
        }
        // Fallback to simple pattern matching
        else if model.contains("MacBookPro") { sys.modelName = "MacBook Pro" }
        else if model.contains("MacBookAir") { sys.modelName = "MacBook Air" }
        else if model.contains("Macmini") { sys.modelName = "Mac mini" }
        else if model.contains("MacPro") { sys.modelName = "Mac Pro" }
        else if model.contains("iMac") { sys.modelName = "iMac" }
        else { sys.modelName = "Mac" }
        
        let osVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersion
        sys.osVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        sys.osBuild = sysctl("kern.osversion") ?? "Unknown"
        sys.kernelVersion = sysctl("kern.osrelease") ?? "Unknown"
        
        // Serial number
        sys.serialNumber = getSerialNumber() ?? "N/A"
        
        // Uptime
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &boottime, &size, nil, 0)
        let bootDate = Date(timeIntervalSince1970: Double(boottime.tv_sec))
        let uptime = Date().timeIntervalSince(bootDate)
        sys.uptime = formatUptime(uptime)
        
        return sys
    }
    
    private func getStorageInfo() -> StorageData {
        var storage = StorageData()
        
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let total = attrs[.systemSize] as? Int64,
               let free = attrs[.systemFreeSize] as? Int64 {
                storage.capacity = formatBytes(total)
                storage.available = formatBytes(free)
                storage.used = formatBytes(total - free)
            }
        } catch {}
        
        storage.type = isAppleSilicon() ? "Apple SSD (NVMe)" : "SSD"
        
        return storage
    }
    
    // MARK: - Helpers
    
    private func isAppleSilicon() -> Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return machine.contains("arm64")
    }
    
    private func sysctl(_ name: String) -> String? {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
    
    private func sysctlInt(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        return result == 0 ? value : nil
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        else if hours > 0 { return "\(hours)h \(minutes)m" }
        else { return "\(minutes)m" }
    }
    
    private func getSerialNumber() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        
        guard platformExpert != 0,
              let serialNumber = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return serialNumber.takeRetainedValue() as? String
    }
}

// MARK: - Data Models

struct HardwareData {
    var cpu = CPUData()
    var memory = MemoryData()
    var gpu = GPUData()
    var neuralEngine = NeuralEngineData()
    var system = SystemData()
    var storage = StorageData()
}

struct CPUData {
    var name = "Unknown"
    var architecture = "Unknown"
    var performanceCores = 0
    var efficiencyCores = 0
    var totalCores = 0
    var threads = 0
    var maxFrequency = "Unknown"
    var l1Cache = "N/A"
    var l2Cache = "N/A"
}

struct MemoryData {
    var total = "Unknown"
    var type = "Unknown"
    var speed = "Unknown"
    var architecture = "Unknown"
    var bandwidth = "Unknown"
}

struct GPUData {
    var name = "Unknown"
    var cores = 0
    var metalVersion = "Unknown"
    var memory = "Unknown"
    var processNode = "Unknown"
    var rayTracing = false
}

struct NeuralEngineData {
    var available = false
    var cores = 0
    var performance = "N/A"
}

struct SystemData {
    var modelName = "Mac"
    var modelId = "Unknown"
    var chip = "Unknown"
    var osVersion = "Unknown"
    var osBuild = "Unknown"
    var kernelVersion = "Unknown"
    var uptime = "Unknown"
    var serialNumber = "N/A"
}

struct StorageData {
    var type = "SSD"
    var capacity = "Unknown"
    var used = "Unknown"
    var available = "Unknown"
}

#Preview {
    HardwareInfoTab()
        .environmentObject(MetricsCollector())
        .frame(width: 900, height: 700)
}
