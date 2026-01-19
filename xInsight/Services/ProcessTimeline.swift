import Foundation

/// ProcessTimeline - Tracks process start/stop events over time
@MainActor
final class ProcessTimeline: ObservableObject {
    static let shared = ProcessTimeline()
    
    // MARK: - Published Properties
    @Published var events: [ProcessEvent] = []
    @Published var activeProcesses: Set<Int32> = []
    
    // Configuration
    private let maxEvents = 500
    
    private init() {
        loadEvents()
    }
    
    // MARK: - Track Processes
    
    func updateProcesses(_ currentProcesses: [ProcessInfo]) {
        let currentPIDs = Set(currentProcesses.map { $0.pid })
        
        // Find new processes (started)
        let started = currentPIDs.subtracting(activeProcesses)
        for pid in started {
            if let process = currentProcesses.first(where: { $0.pid == pid }) {
                let event = ProcessEvent(
                    type: .started,
                    pid: pid,
                    name: process.name,
                    category: process.category,
                    timestamp: Date()
                )
                events.insert(event, at: 0)
            }
        }
        
        // Find stopped processes
        let stopped = activeProcesses.subtracting(currentPIDs)
        for pid in stopped {
            // Find the last started event for this PID
            if let startEvent = events.first(where: { $0.pid == pid && $0.type == .started }) {
                let event = ProcessEvent(
                    type: .stopped,
                    pid: pid,
                    name: startEvent.name,
                    category: startEvent.category,
                    timestamp: Date(),
                    duration: Date().timeIntervalSince(startEvent.timestamp)
                )
                events.insert(event, at: 0)
            }
        }
        
        activeProcesses = currentPIDs
        
        // Trim old events
        if events.count > maxEvents {
            events = Array(events.prefix(maxEvents))
        }
        
        saveEvents()
    }
    
    // MARK: - Queries
    
    func eventsForToday() -> [ProcessEvent] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return events.filter { $0.timestamp >= startOfDay }
    }
    
    func eventsForProcess(_ name: String) -> [ProcessEvent] {
        return events.filter { $0.name.lowercased().contains(name.lowercased()) }
    }
    
    func topProcessesByDuration(days: Int = 7) -> [(String, TimeInterval)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let recentEvents = events.filter { $0.timestamp >= cutoff && $0.type == .stopped }
        
        var durations: [String: TimeInterval] = [:]
        for event in recentEvents {
            durations[event.name, default: 0] += event.duration ?? 0
        }
        
        return durations.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
    
    // MARK: - Persistence
    
    private func saveEvents() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: "process_timeline")
        }
    }
    
    private func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: "process_timeline"),
           let decoded = try? JSONDecoder().decode([ProcessEvent].self, from: data) {
            events = decoded
        }
    }
}

// MARK: - Models

struct ProcessEvent: Identifiable, Codable {
    let id: UUID
    let type: EventType
    let pid: Int32
    let name: String
    let categoryRaw: String
    let timestamp: Date
    var duration: TimeInterval?
    
    var category: ProcessCategory {
        ProcessCategory(rawValue: categoryRaw) ?? .system
    }
    
    init(type: EventType, pid: Int32, name: String, category: ProcessCategory, timestamp: Date, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.type = type
        self.pid = pid
        self.name = name
        self.categoryRaw = category.rawValue
        self.timestamp = timestamp
        self.duration = duration
    }
    
    enum EventType: String, Codable {
        case started = "Started"
        case stopped = "Stopped"
        
        var icon: String {
            switch self {
            case .started: return "play.circle.fill"
            case .stopped: return "stop.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .started: return "green"
            case .stopped: return "red"
            }
        }
    }
}
