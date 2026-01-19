import XCTest
@testable import xInsight

final class FanControlTests: XCTestCase {
    
    func testFanControlServiceDetection() {
        let service = FanControlService.shared
        
        // Test that service initializes
        XCTAssertNotNil(service)
        
        // Test tool detection (may or may not be installed)
        service.checkInstalledTools()
        
        // If tool is detected, it should be one of the known tools
        if let tool = service.installedTool {
            XCTAssertTrue(FanControlService.FanControlTool.allCases.contains(tool))
        }
    }
    
    func testFanControlToolPaths() {
        // Test that all tools have valid paths
        for tool in FanControlService.FanControlTool.allCases {
            XCTAssertFalse(tool.appPath.isEmpty, "Tool \(tool.rawValue) should have a path")
            XCTAssertTrue(tool.appPath.hasPrefix("/Applications/"), "Tool path should be in /Applications")
            XCTAssertTrue(tool.appPath.hasSuffix(".app"), "Tool path should end with .app")
        }
    }
    
    func testFanControlToolURLs() {
        // Test that all tools have valid download URLs
        for tool in FanControlService.FanControlTool.allCases {
            let url = tool.downloadURL
            XCTAssertNotNil(url, "Tool \(tool.rawValue) should have a download URL")
            XCTAssertTrue(url.absoluteString.hasPrefix("http"), "URL should be http/https")
        }
    }
    
    func testAdvancedFanControlScriptPath() async {
        let service = FanControlService.shared
        
        // Test with invalid RPM (should return error)
        let result1 = await service.runSetFanSpeed(-100)
        XCTAssertFalse(result1.success)
        XCTAssertTrue(result1.message.contains("Error") || result1.message.contains("not found"))
        
        // Note: We can't actually test successful execution because:
        // 1. It requires sudo password
        // 2. It requires SIP disabled
        // 3. It requires smc tool installed
        // So we just verify the method exists and returns proper error format
    }
    
    func testAppleSiliconDetection() {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        // Verify we can detect architecture
        XCTAssertNotNil(machine)
        
        if let machine = machine {
            // Should contain either "arm64" (Apple Silicon) or "x86_64" (Intel)
            XCTAssertTrue(machine.contains("arm64") || machine.contains("x86_64"))
        }
    }
}
