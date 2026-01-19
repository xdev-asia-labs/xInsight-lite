import Foundation
import IOKit.ps

/// Service to monitor battery health and status
final class BatteryService: ObservableObject {
    static let shared = BatteryService()
    
    @Published var batteryInfo: BatteryInfo = BatteryInfo()
    @Published var isAvailable: Bool = false
    
    private var timer: Timer?
    
    private init() {
        refresh()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            isAvailable = false
            return
        }
        
        isAvailable = true
        
        // Basic info from Power Source
        let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
        let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
        let isPluggedIn = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let timeToEmpty = description[kIOPSTimeToEmptyKey] as? Int
        let timeToFull = description[kIOPSTimeToFullChargeKey] as? Int
        
        // Get detailed battery info from IOKit (AppleSmartBattery)
        let detailedInfo = getBatteryDetails()
        
        batteryInfo = BatteryInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: detailedInfo.designCapacity,
            rawMaxCapacity: detailedInfo.rawMaxCapacity,
            cycleCount: detailedInfo.cycleCount,
            designCycleCount: detailedInfo.designCycleCount,
            temperature: detailedInfo.temperature,
            voltage: detailedInfo.voltage,
            amperage: detailedInfo.amperage,
            wattage: detailedInfo.wattage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            isFullyCharged: detailedInfo.isFullyCharged,
            timeToEmpty: timeToEmpty,
            timeToFull: timeToFull,
            healthPercent: detailedInfo.healthPercent,
            condition: detailedInfo.condition,
            serialNumber: detailedInfo.serialNumber,
            deviceName: detailedInfo.deviceName,
            adapterWatts: detailedInfo.adapterWatts,
            adapterDescription: detailedInfo.adapterDescription,
            cellCount: detailedInfo.cellCount
        )
    }
    
    private func getBatteryDetails() -> (
        designCapacity: Int, rawMaxCapacity: Int, cycleCount: Int, designCycleCount: Int,
        temperature: Double, voltage: Double, amperage: Int, wattage: Double,
        healthPercent: Double, condition: String, isFullyCharged: Bool,
        serialNumber: String, deviceName: String,
        adapterWatts: Int, adapterDescription: String, cellCount: Int
    ) {
        var result = (
            designCapacity: 0, rawMaxCapacity: 0, cycleCount: 0, designCycleCount: 1000,
            temperature: 0.0, voltage: 0.0, amperage: 0, wattage: 0.0,
            healthPercent: 100.0, condition: "Normal", isFullyCharged: false,
            serialNumber: "", deviceName: "",
            adapterWatts: 0, adapterDescription: "", cellCount: 3
        )
        
        // Find battery service
        let matchingDict = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return result
        }
        
        defer { IOObjectRelease(iterator) }
        
        let service = IOIteratorNext(iterator)
        defer { if service != 0 { IOObjectRelease(service) } }
        
        guard service != 0 else { return result }
        
        // Get properties
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = props?.takeRetainedValue() as? [String: Any] else {
            return result
        }
        
        // Extract all values
        result.designCapacity = properties["DesignCapacity"] as? Int ?? 0
        result.rawMaxCapacity = properties["AppleRawMaxCapacity"] as? Int ?? properties["MaxCapacity"] as? Int ?? result.designCapacity
        result.cycleCount = properties["CycleCount"] as? Int ?? 0
        result.designCycleCount = properties["DesignCycleCount9C"] as? Int ?? 1000
        result.isFullyCharged = properties["FullyCharged"] as? Bool ?? false
        
        // Temperature (in centi-Kelvin, convert to Celsius)
        if let tempRaw = properties["Temperature"] as? Int {
            result.temperature = Double(tempRaw) / 100.0 - 273.15
        }
        
        // Voltage (in mV, convert to V)
        if let voltageRaw = properties["Voltage"] as? Int {
            result.voltage = Double(voltageRaw) / 1000.0
        }
        
        // Amperage (in mA) - can be negative when discharging
        result.amperage = properties["Amperage"] as? Int ?? properties["InstantAmperage"] as? Int ?? 0
        
        // Calculate wattage
        result.wattage = abs(Double(result.amperage)) * result.voltage / 1000.0
        
        // Serial and device name
        result.serialNumber = properties["Serial"] as? String ?? ""
        result.deviceName = properties["DeviceName"] as? String ?? ""
        
        // Adapter details
        if let adapterDetails = properties["AdapterDetails"] as? [String: Any] {
            result.adapterWatts = adapterDetails["Watts"] as? Int ?? 0
            result.adapterDescription = adapterDetails["Description"] as? String ?? ""
        }
        
        // Cell count from BatteryData
        if let batteryData = properties["BatteryData"] as? [String: Any],
           let cellVoltage = batteryData["CellVoltage"] as? [Any] {
            result.cellCount = cellVoltage.count
        }
        
        // Health percent based on raw capacity
        if result.designCapacity > 0 {
            result.healthPercent = Double(result.rawMaxCapacity) / Double(result.designCapacity) * 100.0
        }
        
        // Condition based on health
        if result.healthPercent >= 80 {
            result.condition = "Normal"
        } else if result.healthPercent >= 60 {
            result.condition = "Service Recommended"
        } else {
            result.condition = "Service Required"
        }
        
        return result
    }
}

// MARK: - Battery Info Model

struct BatteryInfo {
    var currentCapacity: Int = 0
    var maxCapacity: Int = 100
    var designCapacity: Int = 0
    var rawMaxCapacity: Int = 0
    var cycleCount: Int = 0
    var designCycleCount: Int = 1000
    var temperature: Double = 0
    var voltage: Double = 0
    var amperage: Int = 0
    var wattage: Double = 0
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var isFullyCharged: Bool = false
    var timeToEmpty: Int? = nil
    var timeToFull: Int? = nil
    var healthPercent: Double = 100
    var condition: String = "Normal"
    var serialNumber: String = ""
    var deviceName: String = ""
    var adapterWatts: Int = 0
    var adapterDescription: String = ""
    var cellCount: Int = 3
    
    var chargePercent: Double {
        guard maxCapacity > 0 else { return 0 }
        return Double(currentCapacity) / Double(maxCapacity) * 100
    }
    
    var timeRemaining: String {
        if isFullyCharged {
            return "Fully Charged"
        }
        if isCharging, let time = timeToFull, time > 0 {
            let hours = time / 60
            let mins = time % 60
            return hours > 0 ? "\(hours)h \(mins)m to full" : "\(mins)m to full"
        } else if let time = timeToEmpty, time > 0, time < 65535 {
            let hours = time / 60
            let mins = time % 60
            return hours > 0 ? "\(hours)h \(mins)m remaining" : "\(mins)m remaining"
        }
        return isPluggedIn ? "On Power" : "Calculating..."
    }
    
    var powerSource: String {
        if isPluggedIn {
            if adapterWatts > 0 {
                return "\(adapterWatts)W Adapter"
            }
            return "Power Adapter"
        }
        return "Battery"
    }
    
    var conditionColor: String {
        switch condition {
        case "Normal": return "green"
        case "Service Recommended": return "orange"
        default: return "red"
        }
    }
    
    var cycleProgress: Double {
        guard designCycleCount > 0 else { return 0 }
        return min(1.0, Double(cycleCount) / Double(designCycleCount))
    }
    
    var capacityMah: String {
        "\(rawMaxCapacity) / \(designCapacity) mAh"
    }
    
    var powerDraw: String {
        if amperage == 0 {
            return "0 W"
        }
        return String(format: "%.1f W", wattage)
    }
}
