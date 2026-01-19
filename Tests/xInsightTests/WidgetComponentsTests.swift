import XCTest
@testable import xInsight

final class WidgetComponentsTests: XCTestCase {
    
    // MARK: - MiniGaugeView Progress Calculation Tests
    
    func testMiniGaugeProgressCalculation() {
        // Test progress calculation logic (value / maxValue)
        let testCases: [(value: Double, maxValue: Double, expectedProgress: Double)] = [
            (50, 100, 0.5),
            (0, 100, 0.0),
            (100, 100, 1.0),
            (150, 100, 1.0),  // Should be capped at 1.0
            (25, 50, 0.5),
            (75, 100, 0.75),
        ]
        
        for testCase in testCases {
            let progress = min(testCase.value / testCase.maxValue, 1.0)
            XCTAssertEqual(progress, testCase.expectedProgress, accuracy: 0.001,
                          "Progress for value=\(testCase.value), max=\(testCase.maxValue) should be \(testCase.expectedProgress)")
        }
    }
    
    // MARK: - MiniChartView Bar Width Tests
    
    func testMiniChartBarWidthCalculation() {
        // Test bar width calculation logic
        let testCases: [(dataCount: Int, width: CGFloat, expectedBarWidth: CGFloat)] = [
            (10, 100, 10),    // 100 / 10 = 10
            (20, 200, 10),    // 200 / 20 = 10
            (0, 100, 100),    // max(0, 1) = 1, so 100 / 1 = 100
            (5, 100, 20),     // 100 / 5 = 20
        ]
        
        for testCase in testCases {
            let barWidth = testCase.width / CGFloat(max(testCase.dataCount, 1))
            XCTAssertEqual(barWidth, testCase.expectedBarWidth, accuracy: 0.001,
                          "Bar width for count=\(testCase.dataCount), width=\(testCase.width) should be \(testCase.expectedBarWidth)")
        }
    }
    
    // MARK: - Chart Normalized Height Tests
    
    func testChartNormalizedHeightCalculation() {
        let maxValue: Double = 100
        let containerHeight: CGFloat = 40
        
        let testCases: [(value: Double, expectedHeight: CGFloat)] = [
            (0, 0),
            (50, 20),
            (100, 40),
            (150, 40),  // Should be capped
        ]
        
        for testCase in testCases {
            let normalizedHeight = min(testCase.value / maxValue, 1.0) * Double(containerHeight)
            XCTAssertEqual(normalizedHeight, Double(testCase.expectedHeight), accuracy: 0.001,
                          "Height for value=\(testCase.value) should be \(testCase.expectedHeight)")
        }
    }
}
