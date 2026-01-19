import SwiftUI

/// ProcessTimelineTab - Visual timeline of process events
struct ProcessTimelineTab: View {
    @StateObject private var timeline = ProcessTimeline.shared
    @State private var filterText = ""
    @State private var showOnlyToday = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Timeline
            if filteredEvents.isEmpty {
                emptyState
            } else {
                timelineList
            }
        }
    }
    
    private var filteredEvents: [ProcessEvent] {
        var events = showOnlyToday ? timeline.eventsForToday() : timeline.events
        
        if !filterText.isEmpty {
            events = events.filter { $0.name.lowercased().contains(filterText.lowercased()) }
        }
        
        return events
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Process Timeline")
                        .font(.title.bold())
                    Text("\(filteredEvents.count) events")
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Toggle("Today only", isOn: $showOnlyToday)
                    .toggleStyle(.switch)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter processes...", text: $filterText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Top Processes
            topProcessesSection
        }
        .padding()
    }
    
    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top by Duration (7 days)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(timeline.topProcessesByDuration().prefix(5), id: \.0) { name, duration in
                        VStack(spacing: 4) {
                            Text(name.prefix(12) + (name.count > 12 ? "..." : ""))
                                .font(.caption.bold())
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Timeline List
    
    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredEvents) { event in
                    timelineRow(event)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func timelineRow(_ event: ProcessEvent) -> some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(event.type == .started ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(width: 20)
            
            // Event info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: event.type.icon)
                        .foregroundColor(event.type == .started ? .green : .red)
                    Text(event.name)
                        .font(.headline)
                    Spacer()
                    Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(event.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let duration = event.duration {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Ran for \(formatDuration(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(event.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No process events recorded")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            return "\(Int(seconds / 60))m"
        } else {
            let hours = Int(seconds / 3600)
            let mins = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(mins)m"
        }
    }
}
