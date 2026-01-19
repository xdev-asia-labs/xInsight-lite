import Foundation
import AppKit
import UserNotifications

/// Smart Cleanup Service - Background automatic cleanup scheduling
@MainActor
class SmartCleanupService: ObservableObject {
    static let shared = SmartCleanupService()
    
    @Published var isEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "smartCleanup_enabled")
            if isEnabled {
                scheduleNextCleanup()
            } else {
                cancelScheduledCleanup()
            }
        }
    }
    
    @Published var lastCleanupDate: Date? {
        didSet {
            if let date = lastCleanupDate {
                UserDefaults.standard.set(date, forKey: "smartCleanup_lastDate")
            }
        }
    }
    
    @Published var totalCleaned: UInt64 = 0
    @Published var cleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours default
    @Published var isRunning = false
    
    private var cleanupTimer: Timer?
    private let diskCleanup = DiskCleanup()
    
    private init() {
        // Load saved settings
        isEnabled = UserDefaults.standard.bool(forKey: "smartCleanup_enabled")
        lastCleanupDate = UserDefaults.standard.object(forKey: "smartCleanup_lastDate") as? Date
        totalCleaned = UInt64(UserDefaults.standard.integer(forKey: "smartCleanup_totalCleaned"))
        
        // Check if cleanup is due on startup
        if isEnabled {
            checkAndRunIfDue()
        }
    }
    
    // MARK: - Public Methods
    
    func start() {
        isEnabled = true
        scheduleNextCleanup()
        print("🧹 Smart Cleanup started (interval: \(Int(cleanupInterval / 3600))h)")
    }
    
    func stop() {
        isEnabled = false
        cancelScheduledCleanup()
        print("🧹 Smart Cleanup stopped")
    }
    
    /// Run cleanup immediately
    func runNow() async {
        guard !isRunning else { return }
        await performCleanup()
    }
    
    // MARK: - Private Methods
    
    private func checkAndRunIfDue() {
        guard let lastDate = lastCleanupDate else {
            // Never run before, run now
            Task { await performCleanup() }
            return
        }
        
        let timeSinceLastCleanup = Date().timeIntervalSince(lastDate)
        if timeSinceLastCleanup >= cleanupInterval {
            Task { await performCleanup() }
        } else {
            // Schedule next cleanup
            scheduleNextCleanup()
        }
    }
    
    private func scheduleNextCleanup() {
        cancelScheduledCleanup()
        
        var nextRun: TimeInterval = cleanupInterval
        
        if let lastDate = lastCleanupDate {
            let timeSinceLastCleanup = Date().timeIntervalSince(lastDate)
            nextRun = max(60, cleanupInterval - timeSinceLastCleanup) // At least 1 minute
        }
        
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: nextRun, repeats: false) { [weak self] _ in
            guard let strongSelf = self else { return }
            Task { @MainActor in
                await strongSelf.performCleanup()
            }
        }
        
        print("🧹 Next cleanup scheduled in \(Int(nextRun / 60)) minutes")
    }
    
    private func cancelScheduledCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
    
    private func performCleanup() async {
        isRunning = true
        print("🧹 Starting background cleanup...")
        
        // Scan first
        await diskCleanup.scan()
        
        // Filter only safe categories (exclude user data like Downloads)
        let safeCategories = diskCleanup.scanResults.filter { category in
            let safePaths = [
                "Caches", "Logs", "Derived", "DerivedData", ".npm", 
                "CocoaPods", "Homebrew", "Yarn", "gradle"
            ]
            return safePaths.contains { category.path.contains($0) }
        }
        
        // Select safe categories
        var categoriesToClean = safeCategories
        for i in 0..<categoriesToClean.count {
            categoriesToClean[i].isSelected = true
        }
        
        if categoriesToClean.isEmpty {
            print("🧹 No safe items to clean")
            isRunning = false
            lastCleanupDate = Date()
            scheduleNextCleanup()
            return
        }
        
        let totalToClean = categoriesToClean.reduce(0) { $0 + $1.size }
        print("🧹 Found \(totalToClean.formattedSize) to clean in \(categoriesToClean.count) categories")
        
        // Perform cleanup
        let (cleaned, errors) = await diskCleanup.clean(categories: categoriesToClean)
        
        // Update stats
        lastCleanupDate = Date()
        totalCleaned += cleaned
        UserDefaults.standard.set(Int(totalCleaned), forKey: "smartCleanup_totalCleaned")
        
        print("🧹 Cleanup completed: \(cleaned.formattedSize) freed")
        
        if !errors.isEmpty {
            print("🧹 Cleanup errors: \(errors.count)")
        }
        
        // Send notification if significant cleanup
        if cleaned > 50 * 1024 * 1024 { // > 50MB
            sendCleanupNotification(cleaned: cleaned)
        }
        
        isRunning = false
        scheduleNextCleanup()
    }
    
    private func sendCleanupNotification(cleaned: UInt64) {
        // Use UserNotifications directly for cleanup notification
        let content = UNMutableNotificationContent()
        content.title = "Smart Cleanup Complete"
        content.body = "Freed \(cleaned.formattedSize) of disk space"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
