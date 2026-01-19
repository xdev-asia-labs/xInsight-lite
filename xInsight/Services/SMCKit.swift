import Foundation
import IOKit

/// SMC Key types
enum SMCDataType: String {
    case uint8 = "ui8 "
    case uint16 = "ui16"
    case uint32 = "ui32"
    case sp78 = "sp78"  // Fixed point 7.8
    case flt = "flt "   // Float
    case flag = "flag"
    case ch8 = "ch8*"
}

/// SMC Key structure
struct SMCKey {
    let code: UInt32
    let info: DataInfo
    
    struct DataInfo {
        var dataSize: UInt32
        var dataType: UInt32
        var dataAttributes: UInt8
    }
}

/// SMC Value structure
struct SMCValue {
    var key: UInt32
    var vers: SMCVers
    var pLimitData: SMCPLimitData
    var keyInfo: SMCKeyInfo
    var result: UInt8
    var status: UInt8
    var data8: UInt8
    var data32: UInt32
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
}

struct SMCVers {
    var major: UInt8
    var minor: UInt8
    var build: UInt8
    var reserved: UInt8
    var release: UInt16
}

struct SMCPLimitData {
    var version: UInt16
    var length: UInt16
    var cpuPLimit: UInt32
    var gpuPLimit: UInt32
    var memPLimit: UInt32
}

struct SMCKeyInfo {
    var dataSize: UInt32
    var dataType: UInt32
    var dataAttributes: UInt8
}

/// Native SMC access for fan control
final class SMCKit {
    static let shared = SMCKit()
    
    private var connection: io_connect_t = 0
    private let kSMCHandleYMC: UInt32 = 2
    private let kSMCReadKey: UInt8 = 5
    private let kSMCWriteKey: UInt8 = 6
    private let kSMCGetKeyInfo: UInt8 = 9
    
    private init() {
        open()
    }
    
    deinit {
        close()
    }
    
    // MARK: - Connection
    
    @discardableResult
    func open() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            print("SMC: Could not find AppleSMC service")
            return false
        }
        
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        
        if result != kIOReturnSuccess {
            print("SMC: Could not open connection")
            return false
        }
        
        return true
    }
    
    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }
    
    // MARK: - Fan Control
    
    /// Get number of fans
    func getFanCount() -> Int {
        guard let value = readKey("FNum") else { return 0 }
        return Int(value[0])
    }
    
    /// Get current fan speed (RPM)
    func getFanSpeed(fanIndex: Int) -> Int {
        let key = String(format: "F%dAc", fanIndex)
        guard let value = readKey(key) else { return 0 }
        return decodeSpeed(value)
    }
    
    /// Get minimum fan speed (RPM)
    func getFanMinSpeed(fanIndex: Int) -> Int {
        let key = String(format: "F%dMn", fanIndex)
        guard let value = readKey(key) else { return 0 }
        return decodeSpeed(value)
    }
    
    /// Get maximum fan speed (RPM)
    func getFanMaxSpeed(fanIndex: Int) -> Int {
        let key = String(format: "F%dMx", fanIndex)
        guard let value = readKey(key) else { return 0 }
        return decodeSpeed(value)
    }
    
    /// Get target fan speed (RPM)
    func getFanTargetSpeed(fanIndex: Int) -> Int {
        let key = String(format: "F%dTg", fanIndex)
        guard let value = readKey(key) else { return 0 }
        return decodeSpeed(value)
    }
    
    /// Set fan speed (RPM) - requires root or entitlements
    func setFanSpeed(fanIndex: Int, speed: Int) -> Bool {
        // First, enable manual fan control for this fan
        let modeKey = String(format: "F%dMd", fanIndex)
        let modeData: [UInt8] = [1] // 1 = manual mode
        guard writeKey(modeKey, data: modeData, type: "ui8 ") else {
            print("SMC: Failed to set manual mode")
            return false
        }
        
        // Set target speed
        let targetKey = String(format: "F%dTg", fanIndex)
        let speedData = encodeSpeed(speed)
        return writeKey(targetKey, data: speedData, type: "fpe2")
    }
    
    /// Set fan to automatic mode
    func setFanAutomatic(fanIndex: Int) -> Bool {
        let modeKey = String(format: "F%dMd", fanIndex)
        let modeData: [UInt8] = [0] // 0 = automatic mode
        return writeKey(modeKey, data: modeData, type: "ui8 ")
    }
    
    // MARK: - Temperature Sensors
    
    /// Get CPU temperature
    func getCPUTemperature() -> Double {
        // Try different CPU temperature keys
        let keys = ["TC0P", "TC0D", "TC0E", "TC0F", "TCAD", "TCXC"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 120 {
                    return temp
                }
            }
        }
        return 0
    }
    
    /// Get GPU temperature
    func getGPUTemperature() -> Double {
        let keys = ["TG0P", "TG0D", "TCGC", "TG1D"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 120 {
                    return temp
                }
            }
        }
        return 0
    }
    
    /// Get SSD temperature
    func getSSDTemperature() -> Double {
        let keys = ["TH0P", "TH0x", "Ts0P"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 100 {
                    return temp
                }
            }
        }
        return 0
    }
    
    /// Get Memory temperature
    func getMemoryTemperature() -> Double {
        let keys = ["Ts0S", "TM0P", "TM0S"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 100 {
                    return temp
                }
            }
        }
        return 0
    }
    
    /// Get Battery temperature
    func getBatteryTemperature() -> Double {
        let keys = ["TB0T", "TB1T", "TB2T"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 80 {
                    return temp
                }
            }
        }
        return 0
    }
    
    /// Get Ambient temperature
    func getAmbientTemperature() -> Double {
        let keys = ["TA0P", "TA1P", "TA0S"]
        for key in keys {
            if let value = readKey(key) {
                let temp = decodeTemperature(value)
                if temp > 0 && temp < 60 {
                    return temp
                }
            }
        }
        return 0
    }
    
    // MARK: - Low Level SMC Access
    
    private func readKey(_ keyString: String) -> [UInt8]? {
        guard connection != 0 else { return nil }
        
        var inputStruct = SMCValue(
            key: stringToUInt32(keyString),
            vers: SMCVers(major: 0, minor: 0, build: 0, reserved: 0, release: 0),
            pLimitData: SMCPLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0),
            keyInfo: SMCKeyInfo(dataSize: 0, dataType: 0, dataAttributes: 0),
            result: 0,
            status: 0,
            data8: kSMCGetKeyInfo,
            data32: 0,
            bytes: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        )
        
        var outputStruct = inputStruct
        var outputSize = MemoryLayout<SMCValue>.size
        
        // Get key info first
        var result = IOConnectCallStructMethod(
            connection,
            UInt32(kSMCHandleYMC),
            &inputStruct,
            MemoryLayout<SMCValue>.size,
            &outputStruct,
            &outputSize
        )
        
        guard result == kIOReturnSuccess else { return nil }
        
        // Now read the actual value
        inputStruct.keyInfo.dataSize = outputStruct.keyInfo.dataSize
        inputStruct.data8 = kSMCReadKey
        
        result = IOConnectCallStructMethod(
            connection,
            UInt32(kSMCHandleYMC),
            &inputStruct,
            MemoryLayout<SMCValue>.size,
            &outputStruct,
            &outputSize
        )
        
        guard result == kIOReturnSuccess else { return nil }
        
        // Extract bytes
        let mirror = Mirror(reflecting: outputStruct.bytes)
        var bytes: [UInt8] = []
        for child in mirror.children {
            if let byte = child.value as? UInt8 {
                bytes.append(byte)
            }
        }
        
        return Array(bytes.prefix(Int(outputStruct.keyInfo.dataSize)))
    }
    
    private func writeKey(_ keyString: String, data: [UInt8], type: String) -> Bool {
        guard connection != 0 else { return false }
        
        var inputStruct = SMCValue(
            key: stringToUInt32(keyString),
            vers: SMCVers(major: 0, minor: 0, build: 0, reserved: 0, release: 0),
            pLimitData: SMCPLimitData(version: 0, length: 0, cpuPLimit: 0, gpuPLimit: 0, memPLimit: 0),
            keyInfo: SMCKeyInfo(dataSize: UInt32(data.count), dataType: stringToUInt32(type), dataAttributes: 0),
            result: 0,
            status: 0,
            data8: kSMCWriteKey,
            data32: 0,
            bytes: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
        )
        
        // Copy data to bytes
        withUnsafeMutableBytes(of: &inputStruct.bytes) { ptr in
            for (i, byte) in data.enumerated() where i < 32 {
                ptr[i] = byte
            }
        }
        
        var outputStruct = inputStruct
        var outputSize = MemoryLayout<SMCValue>.size
        
        let result = IOConnectCallStructMethod(
            connection,
            UInt32(kSMCHandleYMC),
            &inputStruct,
            MemoryLayout<SMCValue>.size,
            &outputStruct,
            &outputSize
        )
        
        return result == kIOReturnSuccess
    }
    
    // MARK: - Helpers
    
    private func stringToUInt32(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for (i, char) in str.utf8.enumerated() where i < 4 {
            result = result << 8 | UInt32(char)
        }
        return result
    }
    
    private func decodeSpeed(_ bytes: [UInt8]) -> Int {
        guard bytes.count >= 2 else { return 0 }
        // fpe2 format: 14.2 fixed point
        let value = (Int(bytes[0]) << 8) + Int(bytes[1])
        return value >> 2
    }
    
    private func encodeSpeed(_ speed: Int) -> [UInt8] {
        // fpe2 format: 14.2 fixed point
        let value = speed << 2
        return [UInt8(value >> 8), UInt8(value & 0xFF)]
    }
    
    private func decodeTemperature(_ bytes: [UInt8]) -> Double {
        guard bytes.count >= 2 else { return 0 }
        // sp78 format: signed 7.8 fixed point
        let value = (Int(bytes[0]) << 8) + Int(bytes[1])
        // Handle signed value
        if bytes[0] & 0x80 != 0 {
            return Double(value - 65536) / 256.0
        }
        return Double(value) / 256.0
    }
}
