import Foundation
import AppKit
import PDFKit

/// ReportGenerator - Generates system health reports in various formats
@MainActor
final class ReportGenerator: ObservableObject {
    static let shared = ReportGenerator()
    
    // MARK: - Published Properties
    @Published var isGenerating: Bool = false
    @Published var lastGeneratedPath: URL?
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let historyStore = MetricsHistoryStore.shared
    private let trendAnalyzer = TrendAnalyzer.shared
    
    // MARK: - Report Types
    
    enum ReportType: String, CaseIterable {
        case systemHealth = "System Health Report"
        case performanceTrends = "Performance Trends Report"
        case securityAudit = "Security Audit Report"
        case diskUsage = "Disk Usage Report"
    }
    
    enum ExportFormat: String, CaseIterable {
        case html = "HTML"
        case csv = "CSV"
        case json = "JSON"
        case pdf = "PDF"
        
        var fileExtension: String {
            switch self {
            case .html: return "html"
            case .csv: return "csv"
            case .json: return "json"
            case .pdf: return "pdf"
            }
        }
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Report Generation
    
    /// Generate a report and save to file
    func generateReport(
        type: ReportType,
        format: ExportFormat,
        period: AnalysisPeriod = .week,
        metricsCollector: MetricsCollector? = nil,
        securityScanner: SecurityScanner? = nil
    ) async -> URL? {
        isGenerating = true
        errorMessage = nil
        
        defer { isGenerating = false }
        
        do {
            let content: String
            
            switch type {
            case .systemHealth:
                content = await generateSystemHealthReport(
                    format: format,
                    period: period,
                    metricsCollector: metricsCollector
                )
            case .performanceTrends:
                content = await generatePerformanceTrendsReport(format: format, period: period)
            case .securityAudit:
                content = await generateSecurityAuditReport(format: format, scanner: securityScanner)
            case .diskUsage:
                content = await generateDiskUsageReport(format: format)
            }
            
            // Save to file
            let url = try saveReport(content: content, type: type, format: format)
            lastGeneratedPath = url
            return url
            
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - System Health Report
    
    private func generateSystemHealthReport(
        format: ExportFormat,
        period: AnalysisPeriod,
        metricsCollector: MetricsCollector?
    ) async -> String {
        let summary = await trendAnalyzer.getUsageSummary(for: period)
        let currentMetrics = metricsCollector?.currentMetrics ?? SystemMetrics()
        
        switch format {
        case .html:
            return generateHTMLSystemHealth(summary: summary, current: currentMetrics, period: period)
        case .csv:
            return generateCSVSystemHealth(summary: summary, current: currentMetrics)
        case .json:
            return generateJSONSystemHealth(summary: summary, current: currentMetrics)
        case .pdf:
            return generateHTMLSystemHealth(summary: summary, current: currentMetrics, period: period)
        }
    }
    
    private func generateHTMLSystemHealth(summary: UsageSummary?, current: SystemMetrics, period: AnalysisPeriod) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>xInsight - System Health Report</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', 'Helvetica Neue', sans-serif;
                    background: linear-gradient(180deg, #1a1a2e 0%, #16213e 100%);
                    color: #e0e0e0;
                    padding: 40px;
                    min-height: 100vh;
                }
                .container { max-width: 1000px; margin: 0 auto; }
                .header {
                    text-align: center;
                    margin-bottom: 40px;
                    padding: 30px;
                    background: rgba(255,255,255,0.05);
                    border-radius: 16px;
                    border: 1px solid rgba(255,255,255,0.1);
                }
                .header h1 {
                    font-size: 32px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    margin-bottom: 10px;
                }
                .header p { color: #888; font-size: 14px; }
                .section {
                    background: rgba(255,255,255,0.03);
                    border-radius: 16px;
                    padding: 24px;
                    margin-bottom: 24px;
                    border: 1px solid rgba(255,255,255,0.08);
                }
                .section h2 {
                    font-size: 18px;
                    margin-bottom: 20px;
                    color: #fff;
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .metrics-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 16px;
                }
                .metric-card {
                    background: rgba(255,255,255,0.05);
                    border-radius: 12px;
                    padding: 20px;
                    text-align: center;
                }
                .metric-value {
                    font-size: 28px;
                    font-weight: 700;
                    margin-bottom: 8px;
                }
                .metric-label { color: #888; font-size: 13px; }
                .status-good { color: #4ade80; }
                .status-warning { color: #fbbf24; }
                .status-critical { color: #f87171; }
                .footer {
                    text-align: center;
                    padding: 20px;
                    color: #666;
                    font-size: 12px;
                }
                table { width: 100%; border-collapse: collapse; margin-top: 16px; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.1); }
                th { color: #888; font-weight: 500; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🖥 System Health Report</h1>
                    <p>Generated by xInsight • \(dateFormatter.string(from: Date()))</p>
                    <p>Period: \(period.rawValue)</p>
                </div>
                
                <div class="section">
                    <h2>📊 Current System Status</h2>
                    <div class="metrics-grid">
                        <div class="metric-card">
                            <div class="metric-value \(current.cpuUsage > 80 ? "status-warning" : "status-good")">\(String(format: "%.1f%%", current.cpuUsage))</div>
                            <div class="metric-label">CPU Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value \(current.memoryUsagePercent > 80 ? "status-warning" : "status-good")">\(String(format: "%.1f%%", current.memoryUsagePercent))</div>
                            <div class="metric-label">Memory Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value \(current.gpuUsage > 80 ? "status-warning" : "status-good")">\(String(format: "%.1f%%", current.gpuUsage))</div>
                            <div class="metric-label">GPU Usage</div>
                        </div>
                        <div class="metric-card">
                            <div class="metric-value \(current.cpuTemperature > 75 ? "status-warning" : "status-good")">\(String(format: "%.0f°C", current.cpuTemperature))</div>
                            <div class="metric-label">CPU Temperature</div>
                        </div>
                    </div>
                </div>
                
                \(summary != nil ? """
                <div class="section">
                    <h2>📈 Period Summary (\(period.rawValue))</h2>
                    <table>
                        <tr><th>Metric</th><th>Average</th><th>Maximum</th></tr>
                        <tr><td>CPU Usage</td><td>\(String(format: "%.1f%%", summary!.avgCPU))</td><td>\(String(format: "%.1f%%", summary!.maxCPU))</td></tr>
                        <tr><td>Memory Usage</td><td>\(formatBytes(UInt64(summary!.avgMemory)))</td><td>\(formatBytes(UInt64(summary!.maxMemory)))</td></tr>
                        <tr><td>GPU Usage</td><td>\(String(format: "%.1f%%", summary!.avgGPU))</td><td>\(String(format: "%.1f%%", summary!.maxGPU))</td></tr>
                        <tr><td>Temperature</td><td>\(String(format: "%.1f°C", summary!.avgTemperature))</td><td>\(String(format: "%.1f°C", summary!.maxTemperature))</td></tr>
                    </table>
                    <p style="color: #888; margin-top: 16px; font-size: 13px;">Based on \(summary!.sampleCount) data samples</p>
                </div>
                """ : "")
                
                <div class="section">
                    <h2>💻 System Information</h2>
                    <table>
                        <tr><td>macOS Version</td><td>\(Foundation.ProcessInfo.processInfo.operatingSystemVersionString)</td></tr>
                        <tr><td>CPU Cores</td><td>\(Foundation.ProcessInfo.processInfo.processorCount)</td></tr>
                        <tr><td>Physical Memory</td><td>\(formatBytes(Foundation.ProcessInfo.processInfo.physicalMemory))</td></tr>
                        <tr><td>Thermal State</td><td>\(current.thermalState.rawValue)</td></tr>
                        <tr><td>Fan Speed</td><td>\(current.fanSpeed > 0 ? "\(current.fanSpeed) RPM" : "Passive Cooling")</td></tr>
                    </table>
                </div>
                
                <div class="footer">
                    <p>© 2024 xDev.asia • xInsight v1.0</p>
                    <p>This report was generated automatically. For more details, open xInsight Dashboard.</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateCSVSystemHealth(summary: UsageSummary?, current: SystemMetrics) -> String {
        var csv = "Metric,Current Value,Average,Maximum,Unit\n"
        
        csv += "CPU Usage,\(String(format: "%.1f", current.cpuUsage)),\(String(format: "%.1f", summary?.avgCPU ?? 0)),\(String(format: "%.1f", summary?.maxCPU ?? 0)),%\n"
        csv += "Memory Usage,\(String(format: "%.1f", current.memoryUsagePercent)),,,% \n"
        csv += "GPU Usage,\(String(format: "%.1f", current.gpuUsage)),\(String(format: "%.1f", summary?.avgGPU ?? 0)),\(String(format: "%.1f", summary?.maxGPU ?? 0)),%\n"
        csv += "CPU Temperature,\(String(format: "%.1f", current.cpuTemperature)),\(String(format: "%.1f", summary?.avgTemperature ?? 0)),\(String(format: "%.1f", summary?.maxTemperature ?? 0)),°C\n"
        csv += "Fan Speed,\(current.fanSpeed),,,RPM\n"
        
        return csv
    }
    
    private func generateJSONSystemHealth(summary: UsageSummary?, current: SystemMetrics) -> String {
        let report: [String: Any] = [
            "generated": ISO8601DateFormatter().string(from: Date()),
            "version": "1.0",
            "current": [
                "cpuUsage": current.cpuUsage,
                "memoryUsagePercent": current.memoryUsagePercent,
                "gpuUsage": current.gpuUsage,
                "cpuTemperature": current.cpuTemperature,
                "fanSpeed": current.fanSpeed,
                "thermalState": current.thermalState.rawValue
            ],
            "summary": summary != nil ? [
                "avgCPU": summary!.avgCPU,
                "maxCPU": summary!.maxCPU,
                "avgMemory": summary!.avgMemory,
                "maxMemory": summary!.maxMemory,
                "avgGPU": summary!.avgGPU,
                "maxGPU": summary!.maxGPU,
                "avgTemperature": summary!.avgTemperature,
                "maxTemperature": summary!.maxTemperature,
                "sampleCount": summary!.sampleCount
            ] as [String: Any] : [:],
            "system": [
                "macOS": Foundation.ProcessInfo.processInfo.operatingSystemVersionString,
                "cpuCores": Foundation.ProcessInfo.processInfo.processorCount,
                "physicalMemory": Foundation.ProcessInfo.processInfo.physicalMemory
            ]
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
    
    // MARK: - Performance Trends Report
    
    private func generatePerformanceTrendsReport(format: ExportFormat, period: AnalysisPeriod) async -> String {
        await trendAnalyzer.analyzeWeeklyPatterns()
        
        switch format {
        case .csv:
            return generateCSVPerformanceTrends()
        case .json:
            return generateJSONPerformanceTrends()
        default:
            return generateHTMLPerformanceTrends(period: period)
        }
    }
    
    private func generateHTMLPerformanceTrends(period: AnalysisPeriod) -> String {
        let patterns = trendAnalyzer.dailyPatterns
        _ = trendAnalyzer.weeklyPatterns  // Reserved for future enhanced report
        let anomalies = trendAnalyzer.anomalies
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        var patternsHTML = ""
        for pattern in patterns {
            patternsHTML += """
            <tr>
                <td>\(pattern.hourLabel)</td>
                <td>\(String(format: "%.1f%%", pattern.avgCPU))</td>
                <td>\(String(format: "%.1f%%", pattern.avgGPU))</td>
                <td>\(pattern.sampleCount)</td>
            </tr>
            """
        }
        
        var anomaliesHTML = ""
        for anomaly in anomalies.prefix(10) {
            anomaliesHTML += """
            <tr>
                <td>\(anomaly.type.rawValue)</td>
                <td>\(dateFormatter.string(from: anomaly.date))</td>
                <td>\(String(format: "%.1f", anomaly.value))</td>
                <td class="status-\(anomaly.severity.rawValue.lowercased())">\(anomaly.severity.rawValue)</td>
            </tr>
            """
        }
        
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>xInsight - Performance Trends Report</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    background: linear-gradient(180deg, #0f0f1a 0%, #1a1a2e 100%);
                    color: #e0e0e0;
                    padding: 40px;
                }
                .container { max-width: 1000px; margin: 0 auto; }
                h1, h2 { margin-bottom: 20px; }
                .section {
                    background: rgba(255,255,255,0.03);
                    border-radius: 16px;
                    padding: 24px;
                    margin-bottom: 24px;
                }
                table { width: 100%; border-collapse: collapse; }
                th, td { padding: 12px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.1); }
                .status-low { color: #fbbf24; }
                .status-medium { color: #fb923c; }
                .status-high { color: #f87171; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📈 Performance Trends Report</h1>
                <p style="color: #888; margin-bottom: 30px;">Generated: \(dateFormatter.string(from: Date())) • Period: \(period.rawValue)</p>
                
                <div class="section">
                    <h2>🕐 Daily Patterns</h2>
                    <table>
                        <tr><th>Hour</th><th>Avg CPU</th><th>Avg GPU</th><th>Samples</th></tr>
                        \(patternsHTML.isEmpty ? "<tr><td colspan='4'>Not enough data</td></tr>" : patternsHTML)
                    </table>
                </div>
                
                <div class="section">
                    <h2>⚠️ Detected Anomalies</h2>
                    <table>
                        <tr><th>Type</th><th>Date</th><th>Value</th><th>Severity</th></tr>
                        \(anomaliesHTML.isEmpty ? "<tr><td colspan='4'>No anomalies detected</td></tr>" : anomaliesHTML)
                    </table>
                </div>
                
                <div class="section">
                    <h2>📅 Peak Usage Hours</h2>
                    <p>\(trendAnalyzer.peakUsageHours.isEmpty ? "Not enough data" : trendAnalyzer.peakUsageHours.map { "\($0):00" }.joined(separator: ", "))</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    private func generateCSVPerformanceTrends() -> String {
        var csv = "Hour,Avg CPU,Avg GPU,Sample Count\n"
        for pattern in trendAnalyzer.dailyPatterns {
            csv += "\(pattern.hour),\(String(format: "%.1f", pattern.avgCPU)),\(String(format: "%.1f", pattern.avgGPU)),\(pattern.sampleCount)\n"
        }
        return csv
    }
    
    private func generateJSONPerformanceTrends() -> String {
        let report: [String: Any] = [
            "generated": ISO8601DateFormatter().string(from: Date()),
            "dailyPatterns": trendAnalyzer.dailyPatterns.map { [
                "hour": $0.hour,
                "avgCPU": $0.avgCPU,
                "avgGPU": $0.avgGPU,
                "sampleCount": $0.sampleCount
            ] },
            "peakHours": trendAnalyzer.peakUsageHours,
            "anomalies": trendAnalyzer.anomalies.map { [
                "type": $0.type.rawValue,
                "date": ISO8601DateFormatter().string(from: $0.date),
                "value": $0.value,
                "severity": $0.severity.rawValue
            ] }
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{}"
    }
    
    // MARK: - Security Audit Report
    
    private func generateSecurityAuditReport(format: ExportFormat, scanner: SecurityScanner?) async -> String {
        // Simple placeholder - would integrate with SecurityScanner
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        return """
        <!DOCTYPE html>
        <html>
        <head><title>Security Audit Report</title></head>
        <body style="font-family: sans-serif; padding: 40px;">
            <h1>🛡 Security Audit Report</h1>
            <p>Generated: \(dateFormatter.string(from: Date()))</p>
            <p>For detailed security information, please open xInsight Dashboard > Security tab.</p>
        </body>
        </html>
        """
    }
    
    // MARK: - Disk Usage Report
    
    private func generateDiskUsageReport(format: ExportFormat) async -> String {
        // Simple placeholder
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .medium
        
        return """
        <!DOCTYPE html>
        <html>
        <head><title>Disk Usage Report</title></head>
        <body style="font-family: sans-serif; padding: 40px;">
            <h1>💾 Disk Usage Report</h1>
            <p>Generated: \(dateFormatter.string(from: Date()))</p>
            <p>For detailed disk analysis, please open xInsight Dashboard > Disk tab.</p>
        </body>
        </html>
        """
    }
    
    // MARK: - File Operations
    
    private func saveReport(content: String, type: ReportType, format: ExportFormat) throws -> URL {
        let fileManager = FileManager.default
        
        // Create reports directory
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ReportGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access Documents directory"])
        }
        
        let reportsDir = documentsDir.appendingPathComponent("xInsight Reports", isDirectory: true)
        try fileManager.createDirectory(at: reportsDir, withIntermediateDirectories: true)
        
        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(type.rawValue.replacingOccurrences(of: " ", with: "_"))_\(timestamp).\(format.fileExtension)"
        
        let fileURL = reportsDir.appendingPathComponent(filename)
        
        // Write content
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
    
    // MARK: - Helpers
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
    
    /// Open the reports folder in Finder
    func openReportsFolder() {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let reportsDir = documentsDir.appendingPathComponent("xInsight Reports")
        
        NSWorkspace.shared.open(reportsDir)
    }
    
    /// Open a specific report file
    func openReport(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
