import Foundation

/// ScheduledExports - Automatic export of reports on schedule
@MainActor
final class ScheduledExports: ObservableObject {
    static let shared = ScheduledExports()
    
    // MARK: - Published Properties
    @Published var isEnabled = false
    @Published var exportFormat: ReportGenerator.ExportFormat = .html
    @Published var exportFrequency: ExportFrequency = .weekly
    @Published var exportPath: URL?
    @Published var lastExport: Date?
    @Published var exportHistory: [ExportRecord] = []
    
    private var timer: Timer?
    private let reportGenerator = ReportGenerator.shared
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Configuration
    
    func configure(format: ReportGenerator.ExportFormat, frequency: ExportFrequency, path: URL) {
        exportFormat = format
        exportFrequency = frequency
        exportPath = path
        saveSettings()
    }
    
    // MARK: - Enable/Disable
    
    func enable() {
        isEnabled = true
        scheduleExports()
        saveSettings()
    }
    
    func disable() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
        saveSettings()
    }
    
    // MARK: - Scheduling
    
    private func scheduleExports() {
        timer?.invalidate()
        
        // Check hourly
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndExport()
            }
        }
    }
    
    private func checkAndExport() {
        guard isEnabled else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        var shouldExport = false
        
        switch exportFrequency {
        case .daily:
            // Export at 6 AM
            let hour = calendar.component(.hour, from: now)
            if hour == 6 {
                if lastExport == nil || !calendar.isDateInToday(lastExport!) {
                    shouldExport = true
                }
            }
            
        case .weekly:
            // Export on Monday at 6 AM
            let weekday = calendar.component(.weekday, from: now)
            let hour = calendar.component(.hour, from: now)
            if weekday == 2 && hour == 6 {
                if lastExport == nil || now.timeIntervalSince(lastExport!) > 6 * 24 * 3600 {
                    shouldExport = true
                }
            }
            
        case .monthly:
            // Export on 1st of month at 6 AM
            let day = calendar.component(.day, from: now)
            let hour = calendar.component(.hour, from: now)
            if day == 1 && hour == 6 {
                if lastExport == nil || !calendar.isDate(lastExport!, equalTo: now, toGranularity: .month) {
                    shouldExport = true
                }
            }
        }
        
        if shouldExport {
            Task {
                await performExport()
            }
        }
    }
    
    // MARK: - Export
    
    func performExport() async {
        guard let basePath = exportPath else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let timestamp = dateFormatter.string(from: Date())
        
        let filename = "xInsight_Report_\(timestamp).\(exportFormat.fileExtension)"
        let fullPath = basePath.appendingPathComponent(filename)
        
        // Use the reportGenerator's generateReport method
        if let generatedPath = await reportGenerator.generateReport(
            type: .systemHealth,
            format: exportFormat,
            period: .week
        ) {
            // Move from generated path to our target path
            do {
                try FileManager.default.moveItem(at: generatedPath, to: fullPath)
            } catch {
                // Use generated path as-is
                lastExport = Date()
                saveSettings()
                return
            }
        }
        
        let record = ExportRecord(
            date: Date(),
            format: exportFormat,
            path: fullPath.path,
            size: (try? FileManager.default.attributesOfItem(atPath: fullPath.path)[.size] as? Int64) ?? 0
        )
        exportHistory.insert(record, at: 0)
        
        // Keep only last 20
        if exportHistory.count > 20 {
            exportHistory = Array(exportHistory.prefix(20))
        }
        
        lastExport = Date()
        saveSettings()
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "scheduled_exports_enabled")
        UserDefaults.standard.set(exportFormat.rawValue, forKey: "export_format")
        UserDefaults.standard.set(exportFrequency.rawValue, forKey: "export_frequency")
        if let path = exportPath {
            UserDefaults.standard.set(path.path, forKey: "export_path")
        }
        UserDefaults.standard.set(lastExport?.timeIntervalSince1970, forKey: "last_export")
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "scheduled_exports_enabled")
        if let fmt = UserDefaults.standard.string(forKey: "export_format"),
           let format = ReportGenerator.ExportFormat(rawValue: fmt) {
            exportFormat = format
        }
        if let freq = UserDefaults.standard.string(forKey: "export_frequency"),
           let frequency = ExportFrequency(rawValue: freq) {
            exportFrequency = frequency
        }
        if let path = UserDefaults.standard.string(forKey: "export_path") {
            exportPath = URL(fileURLWithPath: path)
        }
        if let last = UserDefaults.standard.object(forKey: "last_export") as? TimeInterval {
            lastExport = Date(timeIntervalSince1970: last)
        }
    }
}

// MARK: - Models

enum ExportFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
}

struct ExportRecord: Identifiable {
    let id = UUID()
    let date: Date
    let format: ReportGenerator.ExportFormat
    let path: String
    let size: Int64
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
