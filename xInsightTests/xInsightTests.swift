import XCTest
@testable import xInsight

final class xInsightTests: XCTestCase {
    
    func testSystemMetricsInitialization() {
        let metrics = SystemMetrics()
        XCTAssertGreaterThan(metrics.memoryTotal, 0)
        XCTAssertGreaterThan(metrics.cpuCoreCount, 0)
    }
    
    func testMemoryPressureValues() {
        XCTAssertEqual(MemoryPressure.normal.color, "green")
        XCTAssertEqual(MemoryPressure.warning.color, "yellow")
        XCTAssertEqual(MemoryPressure.critical.color, "red")
    }
    
    func testThermalStateValues() {
        XCTAssertEqual(ThermalState.nominal.color, "green")
        XCTAssertEqual(ThermalState.critical.color, "red")
    }
    
    func testProcessCategorization() {
        // Browser detection
        XCTAssertEqual(
            ProcessCategory.categorize(processName: "Google Chrome", bundleId: nil),
            .browser
        )
        
        // Developer tools detection
        XCTAssertEqual(
            ProcessCategory.categorize(processName: "Xcode", bundleId: nil),
            .developer
        )
        
        // System process detection
        XCTAssertEqual(
            ProcessCategory.categorize(processName: "kernel_task", bundleId: nil),
            .system
        )
    }
    
    func testInsightSeverityComparison() {
        XCTAssertTrue(Severity.info < Severity.warning)
        XCTAssertTrue(Severity.warning < Severity.critical)
    }
}
