import SwiftUI

/// Timeline Tab showing event history
struct TimelineTab: View {
    @EnvironmentObject var insightEngine: InsightEngine
    @State private var selectedDate: Date = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with date picker
            headerView
            
            Divider()
            
            // Timeline content
            if insightEngine.insightHistory.isEmpty {
                emptyView
            } else {
                timelineList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Text(L10n.string(.timeline))
                .font(.headline)
            
            Spacer()
            
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
        }
        .padding()
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L10n.string(.noEvents))
                .font(.headline)
            
            Text(L10n.string(.insightsWillBeRecorded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedByHour.keys.sorted().reversed(), id: \.self) { hour in
                    if let insights = groupedByHour[hour] {
                        // Hour header
                        Text(hourFormatter.string(from: hour))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        
                        // Events for this hour
                        ForEach(insights) { insight in
                            TimelineEventRow(insight: insight)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    private var groupedByHour: [Date: [Insight]] {
        Dictionary(grouping: insightEngine.insightHistory) { insight in
            Calendar.current.dateInterval(of: .hour, for: insight.timestamp)?.start ?? insight.timestamp
        }
    }
    
    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

// MARK: - Timeline Event Row

struct TimelineEventRow: View {
    let insight: Insight
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line and dot
            VStack(spacing: 0) {
                Circle()
                    .fill(severityColor)
                    .frame(width: 10, height: 10)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            .frame(width: 20)
            
            // Event content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: insight.type.iconName)
                        .foregroundColor(severityColor)
                    
                    Text(insight.title)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(timeFormatter.string(from: insight.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }
}

#Preview {
    TimelineTab()
        .environmentObject(InsightEngine())
        .frame(width: 800, height: 600)
}
