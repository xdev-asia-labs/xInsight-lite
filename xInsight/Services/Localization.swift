import Foundation

// MARK: - Localization Manager using Apple's standard .strings files

enum L10n {
    // Current language setting
    static var currentLanguage: Language = .system
    
    // Cache for translations
    private static var translationCache: [String: [String: String]] = [:]
    
    enum Language: String, CaseIterable {
        case system = "system"
        case english = "en"
        case vietnamese = "vi"
        case chinese = "zh-Hans"
        case japanese = "ja"
        case korean = "ko"
        case spanish = "es"
        case french = "fr"
        case german = "de"
        
        var displayName: String {
            switch self {
            case .system: return "System"
            case .english: return "English"
            case .vietnamese: return "Tiếng Việt"
            case .chinese: return "简体中文"
            case .japanese: return "日本語"
            case .korean: return "한국어"
            case .spanish: return "Español"
            case .french: return "Français"
            case .german: return "Deutsch"
            }
        }
        
        var resolvedLanguage: Language {
            if self == .system {
                let preferredLanguages = Locale.preferredLanguages
                let lang = preferredLanguages.first ?? "en"
                if lang.starts(with: "vi") { return .vietnamese }
                if lang.starts(with: "zh") { return .chinese }
                if lang.starts(with: "ja") { return .japanese }
                if lang.starts(with: "ko") { return .korean }
                if lang.starts(with: "es") { return .spanish }
                if lang.starts(with: "fr") { return .french }
                if lang.starts(with: "de") { return .german }
                return .english
            }
            return self
        }
    }
    
    // Load translations from .strings files
    static func loadTranslations() {
        let languages = ["en", "vi", "zh-Hans", "ja", "ko", "es", "fr", "de"]
        
        for langCode in languages {
            // Try multiple paths to find the .strings file
            let possiblePaths = [
                // Development path (when running from source)
                "\(FileManager.default.currentDirectoryPath)/Resources/\(langCode).lproj/Localizable.strings",
                // Bundle path
                Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "\(langCode).lproj"),
                // Alternative bundle path
                Bundle.main.path(forResource: langCode, ofType: "lproj").map { "\($0)/Localizable.strings" }
            ].compactMap { $0 }
            
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path),
                   let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                    translationCache[langCode] = dict
                    print("✅ Loaded \(langCode).lproj (\(dict.count) keys) from \(path)")
                    break
                }
            }
            
            if translationCache[langCode] == nil {
                print("⚠️ Failed to load \(langCode).lproj from any path")
            }
        }
    }
    
    static func string(_ key: LocalizedKey) -> String {
        let lang = currentLanguage.resolvedLanguage
        let langCode = lang == .vietnamese ? "vi" : "en"
        
        // Get translation from cache
        if let translation = translationCache[langCode]?[key.rawValue] {
            return translation
        }
        
        // Fallback to English
        if let fallback = translationCache["en"]?[key.rawValue] {
            return fallback
        }
        
        // Last resort: return key name
        return key.rawValue
    }
    
    /// Get localized string by raw key string (for dynamic keys like cleanup categories)
    static func rawString(_ key: String) -> String {
        let lang = currentLanguage.resolvedLanguage
        let langCode = lang == .vietnamese ? "vi" : "en"
        
        // Get translation from cache
        if let translation = translationCache[langCode]?[key] {
            return translation
        }
        
        // Fallback to English
        if let fallback = translationCache["en"]?[key] {
            return fallback
        }
        
        // Last resort: return key name
        return key
    }
    
    static func loadSavedLanguage() {
        if let saved = UserDefaults.standard.string(forKey: "app_language"),
           let lang = Language(rawValue: saved) {
            currentLanguage = lang
        }
    }
}

// MARK: - Localized Keys

enum LocalizedKey: String {
    // App
    case appName
    case appDescription
    
    // Menu Bar
    case menuBarOpen
    case menuBarQuit
    case menuBarRefresh
    
    // Dashboard Tabs
    case overview
    case processes
    case insights
    case timeline
    case ports
    case cleanup
    case settings
    case cpuDetail
    case gpuDetail
    case memoryDetail
    case diskDetail
    case networkTraffic
    case batteryHealth
    case uninstaller
    case startupManager
    case security
    
    // Overview
    case systemOverview
    case systemNormal
    case systemWarning
    case systemCritical
    case systemNormalDesc
    
    // Metrics
    case cpu
    case memory
    case gpu
    case diskIO
    case temperature
    case network
    case fanSpeed
    
    // CPU Detail
    case cpuUsage
    case performanceCores
    case efficiencyCores
    case allCores
    case coreUsage
    case systemLoad
    case userLoad
    case idleTime
    
    // GPU Detail
    case gpuUsage
    case gpuCores
    case gpuMemory
    case gpuTemperature
    case metalPerformance
    
    // Memory Detail
    case memoryUsage
    case memoryUsed
    case memoryFree
    case memoryWired
    case memoryCompressed
    case memorySwap
    case memoryPressure
    
    // Status
    case avgCPU
    case avgMemory
    case avgGPU
    case last30s
    case samples
    case collected
    case activeInsights
    case noIssues
    case selectInsightDetail
    
    // Actions
    case refresh
    case close
    case configure
    case reset
    case done
    case scan
    case clean
    case stop
    case start
    
    // Fan Control
    case fanControl
    case fanAuto
    case fanManual
    case fanSpeed_rpm
    case noFan
    
    // Hardware
    case chip
    case cores
    case type
    case total
    case hardware
    case details
    case history
    case trend
    case rising
    case falling
    case stable
    case current
    case average
    
    // Sidebar Sections
    case monitor
    case analysis
    case tools
    
    // Settings Tabs
    case language
    case notifications
    case thresholds
    case about
    case general
    
    // Settings General
    case launchAtLogin
    case showInDock
    case refreshInterval
    case notifyWhen
    case warningThresholds
    case resetToDefaults
    
    // Time Intervals
    case oneSecond
    case twoSeconds
    case fiveSeconds
    case tenSeconds
    case intervalDescription
    
    // Common Actions
    case download
    case upload
    case uninstall
    case remove
    case revealInFinder
    case checkForUpdates
    case rescan
    case setSpeed
    case openSecuritySettings
    case openInstalled
    case stopPort
    case openPlist
    
    // Status Messages
    case upToDate
    case updateAvailable
    case checkingUpdates
    case currentVersion
    case latestVersion
    case version
    
    // Thermal
    case thermal
    case nominal
    case normal
    
    // Notification Settings
    case enableNotifications
    case cpuExceedsThreshold
    case memoryPressureHigh
    case thermalThrottling
    case portStartsStops
    case notificationSound
    case `default`
    case subtle
    case none
    
    // Fan Control Specific
    case fanControlWarning
    case fanAutoManaged
    case sipDisabled
    case installSmcTool
    case sudoPrompt
    case resetToAutomatic
    case advancedMode
    case requiresSIPSudo
    case downloadMacsFanControl
    case forMoreControl
    case currentRPM
    case cpuTemp
    case status
    case idle
    
    // Disk & Cleanup
    case largeFiles
    case scanning
    case filesFound
    case successfullyFreed
    case confirmDelete
    case cannotBeUndone
    case ofData
    
    // Processes
    case killProcess
    case forceQuit
    case processName
    case pid
    case user
    case sortBy
    
    // Battery
    case chargeLevel
    case charging
    case discharging
    case notCharging
    case cycleCount
    case condition
    case maximumCapacity
    case timeRemaining
    case powerSource
    case battery
    case acPower
    
    // Security
    case sipEnabled
    case sipDisabledStatus
    case firewallEnabled
    case firewallDisabled
    case gatekeeperEnabled
    case filevaultEnabled
    case filevaultDisabled
    
    // Startup Manager
    case loginItems
    case launchAgents
    case launchDaemons
    case enabled
    case disabled
    
    // More
    case moreInfo
    case preview
    case auto
    case copyright
    case mitLicense
    case appleSilicon
    case appleSiliconMac
    case thermalManagement
    case unifiedLPDDR5
    case appleSiliconIntegrated
    
    // Network Traffic Tab
    case networkAndDisk
    case realTimeIO
    case read
    case write
    case activity60s
    case activeConnections
    
    // Uninstaller Tab
    case installedApps
    case appSize
    case relatedFiles
    case totalToRemove
    case selectAnApp
    case findAllRelatedFiles
    case movedToTrash
    
    // Disk Detail Tab
    case storageBreakdown
    case usageByCategory
    case available
    case used
    
    // Overview Tab
    case recentActivity
    case clickToConfigure
    case ruleBasedDetection
    case configureWarningThresholds
    case coreMLAnomalyDetection
    case onDeviceMachineLearning
    case howItWorks
    case noExternalServices
    
    // Insights Tab
    case description
    case relatedProcesses
    case suggestions
    
    // Security Tab
    case securityChecks
    case recommendations
    case suspiciousItemsFound
    case systemIntegrityProtection
    case protectsSystemFiles
    case gatekeeper
    case blocksUnverifiedApps
    case fileVault
    case encryptsStartupDisk
    case firewall
    case blocksUnwantedConnections
    
    // Startup Manager Tab
    case filter
    case all
    case userOnly
    case systemOnly
    
    // Common
    case items
    case files
    case on
    case off
    case active
    case selectToView
    
    // Battery Health Tab
    case health
    case rawCapacity
    case cells
    case power
    case detailedStatistics
    case serialNumber
    case device
    case charger
    case batteryTips
    case noBatteryDetected
    case noBatteryInfo
    
    // Large Files
    case largeFilesTitle
    case noLargeFiles
    case moreFiles
    
    // Port Details
    case portDetails
    case noActivePorts
    case noServicesListening
    case selectPortToView
    
    // GPU Detail Tab
    case metal3Ready
    case unifiedMemoryArchitecture
    case gpuSharesMemory
    case gpuMemoryUsed
    
    // Memory Detail Tab
    case systemHealth
    
    // Processes Tab
    case sort
    
    // Common Labels
    case localIP
    case connected
    
    // Fan Control Tab
    case rpm
    case requiresSipDisabled
    case advancedUsersOnly
    case targetFanSpeed
    case rpmRange
    case output
    case requirements
    case manualModeOverride
    case targetSpeed
    case systemTemperatures
    case fanSpeedHistory
    
    // Common Labels - Additional
    case mbps
    case thisMayTakeAMoment
    case diskIsClean
    case noSignificantJunkFiles
    
    // Format Strings
    case portsCount
    case andMoreItems
    case canBeFreed
    case freedWithErrors
    case deleteConfirm
    case andMoreFiles
    case largeFilesCount
    case terminateProcess
    case scanAgain
    
    // Time Intervals
    case seconds1
    case seconds2
    case seconds5
    case seconds10
    
    // Static UI
    case vietnamese
    case english
    case bullet
    
    // New keys (non-duplicate)
    case threshold
    case notInstalled
    case andMoreFilesCategory
    
    // Additional static strings (truly new)
    case tryMacsFanControl
    case sipWarning
    case appleRestricted
    case macosManagesFans
    
    // Final batch of static strings
    case noEvents
    case insightsWillBeRecorded
    case noStartupItems
    case program
    case plistLocation
    case removeLaunchAgentWarning
    case selectStartupItem
    case itemsCount
    case coresHighFreq
    case coresLowPower
    
    // Startup Manager & Battery additional
    case viewDetailsManage
    case autoStart
    case ofCycles
    
    // Format strings for dynamic values
    case percentValue
    case versionFormat
    case portFormat
    case addressPortFormat
    case pidFormat
    case rpmFormat
    case tempFormat
    case coreFormat
    case thresholdFormat
    
    // Final batch - truly unique keys
    case gpuSharesMemoryDesc
    case ofHundred
    case itemsCountShort
    case appMovedToTrash
    case errorsOccurred
    case versionPrefix
    case scanningDots
    case filesCount
    case noRelatedFiles
    case willBeMovedToTrash
    case currentFormat
    case thresholdLabel
    case noMatchingCommands
    case tryCommands
    case recent
    case coresUnit
    
    // Final strings for 100% coverage
    case securitySettingsGood
    case securitySettingsNeedsWork
    case cellCountFormat
    case valueWithUnit
    
    // Pure number format strings
    case numberOnly
    case decimalValue
    
    // CoreML Info Sheet
    case mlStatus
    case mlDependencies
    case mlPrivacy
    case mlStatusLearning
    case mlNoneBuiltIn
    case ml100OnDevice
    case mlCollectsBaseline
    case mlCalculatesThresholds
    case mlDetectsAnomalies
    case mlLearnssContinuously
    
    // Battery Health Tab - Detailed Stats
    case batTemperature
    case batVoltage
    case batPowerDraw
    case batAmperage
    case batAdapter
    case batFull
    case batOnBattery
    case batExcellent
    case batGoodCondition
    case batFairCondition
    case batConsiderReplacement
    case batNone
    
    // Battery Tips
    case tipKeepTemp
    case tipKeepCharge
    case tipRemoveCharger
    case tipAppleRates
    
    // Widget Labels
    case widgetUsageHistory
    case widgetTopProcesses
    case widgetActivity
    case selectWidgets
    
    // xInsight Widget
    case openDashboard
    case optimizeNow
    case quickActions
    case excellent
    case good
    case fair
    case poor
    
    // AI Dashboard
    case aiDashboard
    case aiDashboardDesc
    case aiSummary
    case smartSuggestions
    case predictedIssues
    case learningProgress
    case modelAccuracy
    case speakInsights
    case stopSpeaking
    case voiceSettings
    case voiceSettingsDesc
    case selectVoice
    case speechRate
    case slower
    case faster
    case testVoice
    case testEnglish
    case testVietnamese
    case verySlow
    case slow
    case fast
    case veryFast
    case learning
    case ready
    case privacy
    case allOnDevice
    case predictions
    case noPredictedIssues
    case noSuggestionsNeeded
    case speakSuggestion
    case apply
    case probability
    case analyzingSystem
    
    // Trends Tab
    case trends
    case trendsAnalysis
    case totalSnapshots
    case usageOverTime
    case noHistoricalData
    case dataWillAppear
    case dailyPatterns
    case peakHours
    case notEnoughData
    case weeklyPatterns
    case detectedAnomalies
    case memoryLeakSuspects
    
    // Health Score
    case healthScore
    case healthScoreDesc
    case componentScores
    
    // Process Timeline
    case processTimeline
    case processTimelineDesc
    case processStarted
    case processStopped
    case todayOnly
    case topByDuration
    case noProcessEvents
    case ranFor
    
    // Custom Alerts
    case customAlerts
    case customAlertsDesc
    case addAlert
    case editAlert
    case alertName
    case metric
    case alertCondition
    case above
    case below
    case equals
    case recentTriggers
    case noCustomAlerts
    case alertEnabled
    case alertDisabled
    
    // Benchmarks
    case benchmark
    case benchmarkDesc
    case runBenchmarks
    case cpuSingleCore
    case cpuMultiCore
    case memoryBandwidth
    case benchDiskIO
    case graphics
    case totalScore
    case benchmarkHistory
    case baselineComparison
    case runningBenchmark
    
    // Comparison Mode
    case comparison
    case comparisonDesc
    case period1
    case period2
    case baseline
    case comparePeriods
    case analysisSummary
    case noComparisonData
    case percentChange
    
    // Theme & Appearance
    case appearance
    case lightMode
    case darkMode
    case systemMode
    case accentColor
    case useDynamicColors
    
    // iCloud Sync
    case iCloudSync
    case syncEnabled
    case syncDisabled
    case lastSynced
    case syncing
    case syncNow
    case syncSettings
    
    // Shortcuts Integration
    case shortcuts
    case shortcutsDesc
    case availableShortcuts
    case getHealthScore
    case getCPUUsage
    case getTemperature
    
    // Scheduled Reports
    case scheduledReports
    case dailyReport
    case weeklyReport
    case reportGenerated
    case reportTime
    case enableReports
    case lastReport
    
    // Scheduled Exports
    case scheduledExports
    case exportFormat
    case exportFrequency
    case daily
    case weekly
    case monthly
    case exportPath
    case exportHistory
    case lastExport
    
    // AppleScript
    case appleScript
    case automation
    case exampleScripts
    case executeScript
    
    // Network Traffic Monitor
    case networkMonitor
    case activeApps
    case bytesIn
    case bytesOut
    case connectionCount
    
    // AI Tab - Progressive Loading
    case smartCleanup
    case usagePatterns
    case loading
}

// MARK: - String Extension

extension String {
    static func localized(_ key: LocalizedKey) -> String {
        L10n.string(key)
    }
}
