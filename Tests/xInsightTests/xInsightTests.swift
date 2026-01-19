import XCTest
@testable import xInsight

final class xInsightTests: XCTestCase {
    
    // MARK: - SMCKit Tests
    
    func testSMCKitInstance() {
        let smc = SMCKit.shared
        XCTAssertNotNil(smc, "SMCKit should have a shared instance")
    }
    
    func testGetFanCount() {
        let fanCount = SMCKit.shared.getFanCount()
        // Most Macs have 0-2 fans
        XCTAssertTrue(fanCount >= 0 && fanCount <= 4, "Fan count should be between 0 and 4")
    }
    
    func testGetCPUTemperature() {
        let temp = SMCKit.shared.getCPUTemperature()
        // Temperature should be reasonable (0-120°C)
        XCTAssertTrue(temp >= 0 && temp < 120, "CPU temperature should be between 0 and 120°C")
    }
    
    // MARK: - BatteryService Tests
    
    func testBatteryServiceInstance() {
        let battery = BatteryService.shared
        XCTAssertNotNil(battery, "BatteryService should have a shared instance")
    }
    
    func testBatteryInfo() {
        let info = BatteryService.shared.batteryInfo
        // Health should be 0-100%
        XCTAssertTrue(info.healthPercent >= 0 && info.healthPercent <= 100, "Battery health should be 0-100%")
    }
    
    // MARK: - SecurityScanner Tests
    
    func testSecurityScannerInstance() {
        let scanner = SecurityScanner.shared
        XCTAssertNotNil(scanner, "SecurityScanner should have a shared instance")
    }
    
    func testSecurityScore() {
        let score = SecurityScanner.shared.securityStatus.overallScore
        // Score should be 0-100
        XCTAssertTrue(score >= 0 && score <= 100, "Security score should be 0-100")
    }
    
    // MARK: - StartupManager Tests
    
    func testStartupManagerInstance() {
        let manager = StartupManager.shared
        XCTAssertNotNil(manager, "StartupManager should have a shared instance")
    }
    
    // MARK: - AppUninstaller Tests
    
    func testAppUninstallerInstance() {
        let uninstaller = AppUninstaller.shared
        XCTAssertNotNil(uninstaller, "AppUninstaller should have a shared instance")
    }
    
    // MARK: - Utility Tests
    
    func testByteFormatting() {
        let bytes: UInt64 = 1_073_741_824 // 1 GB
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("Go"), "Should format as GB")
    }
}
