import Foundation
import UserNotifications

/// ScheduledReports - Generates and sends daily/weekly system reports
@MainActor
final class ScheduledReports: ObservableObject {
    static let shared = ScheduledReports()
    
    // MARK: - Published Properties
    @Published var isEnabled = false
    @Published var dailyReportTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var weeklyReportDay: Int = 1 // Monday
    @Published var lastDailyReport: Date?
    @Published var lastWeeklyReport: Date?
    @Published var reportHistory: [ReportRecord] = []
    
    // MARK: - Dependencies
    private let historyStore = MetricsHistoryStore.shared
    private let healthScore = SystemHealthScore.shared
    
    private var timer: Timer?
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Enable/Disable
    
    func enable() {
        isEnabled = true
        scheduleReports()
        saveSettings()
    }
    
    func disable() {
        isEnabled = false
        timer?.invalidate()
        timer = nil
        saveSettings()
    }
    
    // MARK: - Scheduling
    
    private func scheduleReports() {
        timer?.invalidate()
        
        // Check every hour
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAndGenerateReports()
            }
        }
    }
    
    private func checkAndGenerateReports() {
        let now = Date()
        let calendar = Calendar.current
        
        // Check daily report
        let currentHour = calendar.component(.hour, from: now)
        let reportHour = calendar.component(.hour, from: dailyReportTime)
        
        if currentHour == reportHour {
            if lastDailyReport == nil || !calendar.isDateInToday(lastDailyReport!) {
                Task {
                    await generateDailyReport()
                }
            }
        }
        
        // Check weekly report (on specified day at same time)
        let currentWeekday = calendar.component(.weekday, from: now)
        if currentWeekday == weeklyReportDay && currentHour == reportHour {
            if lastWeeklyReport == nil || now.timeIntervalSince(lastWeeklyReport!) > 6 * 24 * 3600 {
                Task {
                    await generateWeeklyReport()
                }
            }
        }
    }
    
    // MARK: - Generate Reports
    
    func generateDailyReport() async {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: endDate)!
        
        let hourlyData = await historyStore.getHourlyAverages(from: startDate, to: endDate)
        
        guard !hourlyData.isEmpty else { return }
        
        let avgCPU = hourlyData.map(\.avgCPU).reduce(0, +) / Double(hourlyData.count)
        let maxCPU = hourlyData.map(\.maxCPU).max() ?? 0
        let avgTemp = hourlyData.map(\.avgTemperature).reduce(0, +) / Double(hourlyData.count)
        
        let summary = DailyReportSummary(
            date: endDate,
            avgCPU: avgCPU,
            maxCPU: maxCPU,
            avgTemperature: avgTemp,
            healthScore: healthScore.overallScore,
            sampleCount: hourlyData.map(\.sampleCount).reduce(0, +)
        )
        
        // Send notification
        sendReportNotification(
            title: "📊 Daily System Report",
            body: "Avg CPU: \(String(format: "%.1f", avgCPU))% | Health: \(healthScore.overallScore)/100"
        )
        
        // Save record
        let record = ReportRecord(
            type: .daily,
            date: endDate,
            summary: "CPU: \(String(format: "%.1f", avgCPU))%, Health: \(healthScore.overallScore)"
        )
        reportHistory.insert(record, at: 0)
        lastDailyReport = endDate
        saveSettings()
    }
    
    func generateWeeklyReport() async {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        let dailyData = await historyStore.getDailyAverages(from: startDate, to: endDate)
        
        guard !dailyData.isEmpty else { return }
        
        let avgCPU = dailyData.map(\.avgCPU).reduce(0, +) / Double(dailyData.count)
        let maxCPU = dailyData.map(\.maxCPU).max() ?? 0
        let avgTemp = dailyData.map(\.avgTemperature).reduce(0, +) / Double(dailyData.count)
        
        // Calculate trend
        let cpuTrend = calculateTrend(dailyData.map(\.avgCPU))
        
        // Send notification
        sendReportNotification(
            title: "📈 Weekly System Report",
            body: "Week avg CPU: \(String(format: "%.1f", avgCPU))% | Trend: \(cpuTrend > 0 ? "↑" : "↓")"
        )
        
        let record = ReportRecord(
            type: .weekly,
            date: endDate,
            summary: "Week avg: \(String(format: "%.1f", avgCPU))% CPU, \(String(format: "%.0f", avgTemp))°C"
        )
        reportHistory.insert(record, at: 0)
        lastWeeklyReport = endDate
        saveSettings()
    }
    
    // MARK: - Helpers
    
    private func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let first = values.prefix(values.count / 2).reduce(0, +) / Double(values.count / 2)
        let second = values.suffix(values.count / 2).reduce(0, +) / Double(values.count / 2)
        return second - first
    }
    
    private func sendReportNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "report_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "reports_enabled")
        UserDefaults.standard.set(dailyReportTime.timeIntervalSince1970, forKey: "daily_report_time")
        UserDefaults.standard.set(weeklyReportDay, forKey: "weekly_report_day")
        UserDefaults.standard.set(lastDailyReport?.timeIntervalSince1970, forKey: "last_daily_report")
        UserDefaults.standard.set(lastWeeklyReport?.timeIntervalSince1970, forKey: "last_weekly_report")
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "reports_enabled")
        if let time = UserDefaults.standard.object(forKey: "daily_report_time") as? TimeInterval {
            dailyReportTime = Date(timeIntervalSince1970: time)
        }
        weeklyReportDay = UserDefaults.standard.integer(forKey: "weekly_report_day")
        if weeklyReportDay == 0 { weeklyReportDay = 1 }
        
        if let last = UserDefaults.standard.object(forKey: "last_daily_report") as? TimeInterval {
            lastDailyReport = Date(timeIntervalSince1970: last)
        }
        if let last = UserDefaults.standard.object(forKey: "last_weekly_report") as? TimeInterval {
            lastWeeklyReport = Date(timeIntervalSince1970: last)
        }
    }
}

// MARK: - Models

struct DailyReportSummary {
    let date: Date
    let avgCPU: Double
    let maxCPU: Double
    let avgTemperature: Double
    let healthScore: Int
    let sampleCount: Int
}

struct ReportRecord: Identifiable {
    let id = UUID()
    let type: ReportType
    let date: Date
    let summary: String
    
    enum ReportType: String {
        case daily = "Daily"
        case weekly = "Weekly"
    }
}
