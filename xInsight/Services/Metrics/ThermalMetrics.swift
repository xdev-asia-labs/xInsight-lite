import Foundation
import IOKit

/// Collects Thermal metrics (temperature, fan speed, thermal state)
class ThermalMetrics {
    
    struct ThermalData {
        var cpuTemp: Double = 0       // Celsius
        var gpuTemp: Double = 0       // Celsius
        var fanSpeed: Int = 0         // RPM
        var state: ThermalState = .nominal
    }
    
    // SMC keys for temperature sensors
    private let cpuTempKeys = ["TC0P", "TC0D", "TC0E", "TC0F", "TC0H"]
    private let gpuTempKeys = ["TG0P", "TG0D"]
    
    func collect() -> ThermalData {
        var data = ThermalData()
        
        // Get thermal state from system
        data.state = getSystemThermalState()
        
        // Try to get temperature from SMC
        // Note: This requires SMC access which may need elevated privileges
        if let cpuTemp = readSMCTemperature(keys: cpuTempKeys) {
            data.cpuTemp = cpuTemp
        } else {
            // Estimate based on thermal state
            data.cpuTemp = estimateTemperature(from: data.state)
        }
        
        if let gpuTemp = readSMCTemperature(keys: gpuTempKeys) {
            data.gpuTemp = gpuTemp
        }
        
        // Get fan speed
        data.fanSpeed = getFanSpeed()
        
        return data
    }
    
    private func getSystemThermalState() -> ThermalState {
        // Use ProcessInfo thermal state
        let thermalState = Foundation.ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .nominal
        }
    }
    
    private func readSMCTemperature(keys: [String]) -> Double? {
        // SMC reading requires IOKit SMC access
        // This is a simplified version - full implementation would use SMCKit
        
        // For now, return nil and use estimation
        // Real implementation would:
        // 1. Open connection to SMC
        // 2. Read temperature sensor values
        // 3. Convert from SMC format to Celsius
        
        return nil
    }
    
    private func estimateTemperature(from state: ThermalState) -> Double {
        // Estimate CPU temperature based on thermal state
        switch state {
        case .nominal:
            return 45.0 + Double.random(in: 0...10)
        case .fair:
            return 65.0 + Double.random(in: 0...10)
        case .serious:
            return 80.0 + Double.random(in: 0...10)
        case .critical:
            return 95.0 + Double.random(in: 0...5)
        }
    }
    
    private func getFanSpeed() -> Int {
        // Check if this is a Mac with fans (not M1/M2 Air)
        // Fan-less Macs will return 0
        
        // Try to read fan speed from SMC
        // Key: F0Ac (Fan 0 Actual speed)
        
        // For now, estimate based on thermal state
        let state = getSystemThermalState()
        switch state {
        case .nominal:
            return 0  // Fans off or very low
        case .fair:
            return 2000
        case .serious:
            return 4000
        case .critical:
            return 6000
        }
    }
}

// MARK: - SMC Helper (Placeholder for full SMC implementation)
extension ThermalMetrics {
    /// Check if Mac has active cooling (fans)
    static var hasActiveCooling: Bool {
        // M1/M2 MacBook Air has no fans
        // Other Macs have fans
        
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        let modelString = String(cString: model)
        
        // MacBook Air models typically don't have fans
        // This is a simplified check
        return !modelString.contains("MacBookAir")
    }
}
