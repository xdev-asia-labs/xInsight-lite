import XCTest
@testable import xInsight

@MainActor
final class StatusBarControllerTests: XCTestCase {
    
    // Check if running in CI environment (headless, no graphics context)
    private var isRunningInCI: Bool {
        ProcessInfo.processInfo.environment["CI"] != nil ||
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != nil
    }
    
    // MARK: - Initialization Tests
    
    func testSharedInstance() throws {
        // Skip in CI - StatusBarController.shared creates UI elements
        try XCTSkipIf(isRunningInCI, "Skipping UI test in CI environment")
        
        let controller = StatusBarController.shared
        XCTAssertNotNil(controller, "StatusBarController should have a shared instance")
    }
    
    func testWidgetTypesExist() {
        // Verify all widget types are defined
        let types = StatusBarController.WidgetType.allCases
        XCTAssertEqual(types.count, 9, "Should have 9 widget types")
        
        // Check each type has an icon
        for type in types {
            XCTAssertFalse(type.icon.isEmpty, "Widget \(type.rawValue) should have an icon")
        }
    }
    
    // MARK: - Widget Type Tests
    
    func testWidgetTypeIcons() {
        let types = StatusBarController.WidgetType.allCases
        let expectedIcons = [
            "brain.head.profile",  // xinsight
            "cpu",                 // cpu
            "rectangle.3.group",   // gpu
            "memorychip",          // ram
            "internaldrive",       // disk
            "network",             // network
            "battery.100",         // battery
            "cable.connector",     // port
            "trash.circle.fill"    // cleanup
        ]
        
        for (index, type) in types.enumerated() {
            XCTAssertEqual(type.icon, expectedIcons[index], "Icon for \(type.rawValue) should match")
        }
    }
    
    // MARK: - Widget Enable/Disable Tests
    
    func testWidgetEnabledByDefault() throws {
        // Skip in CI - StatusBarController.shared creates UI elements
        try XCTSkipIf(isRunningInCI, "Skipping UI test in CI environment")
        
        let controller = StatusBarController.shared
        
        // All widgets should be enabled by default
        for type in StatusBarController.WidgetType.allCases {
            let enabled = controller.isWidgetEnabled(type)
            XCTAssertTrue(enabled, "Widget \(type.rawValue) should be enabled by default")
        }
    }
    
    func testToggleWidget() throws {
        // Skip in CI - StatusBarController.shared creates UI elements
        try XCTSkipIf(isRunningInCI, "Skipping UI test in CI environment")
        
        let controller = StatusBarController.shared
        let testType = StatusBarController.WidgetType.cpu
        
        // Get initial state
        let initialState = controller.isWidgetEnabled(testType)
        
        // Toggle off
        controller.toggleWidget(testType, enabled: false)
        XCTAssertFalse(controller.isWidgetEnabled(testType), "Widget should be disabled after toggle off")
        
        // Toggle back on
        controller.toggleWidget(testType, enabled: true)
        XCTAssertTrue(controller.isWidgetEnabled(testType), "Widget should be enabled after toggle on")
        
        // Restore initial state
        controller.toggleWidget(testType, enabled: initialState)
    }
    
    // MARK: - Widget Type Enum Tests
    
    func testWidgetTypeRawValues() {
        XCTAssertEqual(StatusBarController.WidgetType.xinsight.rawValue, "xinsight")
        XCTAssertEqual(StatusBarController.WidgetType.cpu.rawValue, "cpu")
        XCTAssertEqual(StatusBarController.WidgetType.gpu.rawValue, "gpu")
        XCTAssertEqual(StatusBarController.WidgetType.ram.rawValue, "ram")
        XCTAssertEqual(StatusBarController.WidgetType.disk.rawValue, "disk")
        XCTAssertEqual(StatusBarController.WidgetType.network.rawValue, "network")
        XCTAssertEqual(StatusBarController.WidgetType.battery.rawValue, "battery")
        XCTAssertEqual(StatusBarController.WidgetType.port.rawValue, "port")
        XCTAssertEqual(StatusBarController.WidgetType.cleanup.rawValue, "cleanup")
    }
}
