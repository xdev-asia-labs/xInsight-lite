import SwiftUI

/// Insights Tab showing AI-generated insights
struct InsightsTab: View {
    @EnvironmentObject var insightEngine: InsightEngine
    @State private var selectedInsightId: UUID?
    @State private var filterSeverity: Severity?
    
    private var selectedInsight: Insight? {
        let all = insightEngine.currentInsights + insightEngine.insightHistory
        return all.first { $0.id == selectedInsightId }
    }
    
    var body: some View {
        HSplitView {
            // Insights list
            insightsList
                .frame(minWidth: 350)
            
            // Detail view
            if let insight = selectedInsight {
                InsightDetailView(insight: insight)
            } else {
                emptyDetailView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Insights List
    
    private var insightsList: some View {
        VStack(spacing: 0) {
            // Header with filter
            HStack {
                Text(L10n.string(.insights))
                    .font(.headline)
                
                Spacer()
                
                // Severity filter
                Menu {
                    Button("All") { filterSeverity = nil }
                    Divider()
                    ForEach(Severity.allCases, id: \.self) { severity in
                        Button(severity.rawValue) { filterSeverity = severity }
                    }
                } label: {
                    HStack {
                        Text(filterSeverity?.rawValue ?? "All")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                }
            }
            .padding()
            
            Divider()
            
            // List
            if filteredInsights.isEmpty {
                emptyListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Current insights
                        if !currentFilteredInsights.isEmpty {
                            sectionHeader("Active")
                            ForEach(currentFilteredInsights) { insight in
                                InsightListRow(insight: insight, isSelected: selectedInsightId == insight.id)
                                    .onTapGesture {
                                        selectedInsightId = insight.id
                                    }
                            }
                        }
                        
                        // History
                        if !historyFilteredInsights.isEmpty {
                            sectionHeader("History")
                            ForEach(historyFilteredInsights) { insight in
                                InsightListRow(insight: insight, isSelected: selectedInsightId == insight.id)
                                    .onTapGesture {
                                        selectedInsightId = insight.id
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var filteredInsights: [Insight] {
        let all = insightEngine.currentInsights + insightEngine.insightHistory
        if let severity = filterSeverity {
            return all.filter { $0.severity == severity }
        }
        return all
    }
    
    private var currentFilteredInsights: [Insight] {
        if let severity = filterSeverity {
            return insightEngine.currentInsights.filter { $0.severity == severity }
        }
        return insightEngine.currentInsights
    }
    
    private var historyFilteredInsights: [Insight] {
        if let severity = filterSeverity {
            return insightEngine.insightHistory.filter { $0.severity == severity }
        }
        return insightEngine.insightHistory
    }
    
    private var emptyListView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text(L10n.string(.noIssues))
                .font(.headline)
            
            Text(L10n.string(.systemNormalDesc))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.left.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L10n.string(.selectInsightDetail))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Insight List Row

struct InsightListRow: View {
    let insight: Insight
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Severity icon
            Image(systemName: insight.severity.iconName)
                .foregroundColor(severityColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(insight.cause)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Time
            Text(timeAgo(insight.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        return "\(Int(seconds / 86400))d ago"
    }
}

// MARK: - Insight Detail View

struct InsightDetailView: View {
    let insight: Insight
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                Divider()
                
                // Description
                descriptionSection
                
                // Affected processes
                if !insight.affectedProcesses.isEmpty {
                    processesSection
                }
                
                // Suggested actions
                if !insight.suggestedActions.isEmpty {
                    actionsSection
                }
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.type.iconName)
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text(insight.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(insight.timestamp.formatted())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Severity badge
                Text(insight.severity.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(severityColor.opacity(0.2))
                    .foregroundColor(severityColor)
                    .cornerRadius(12)
            }
        }
    }
    
    private var severityColor: Color {
        switch insight.severity {
        case .info: return .blue
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(.description))
                .font(.headline)
            
            Text(insight.description)
                .foregroundColor(.secondary)
            
            if let metrics = insight.metrics {
                HStack {
                    Text(L10n.string(.current))
                    Text(String(format: L10n.string(.decimalValue), metrics.currentValue, metrics.unit))
                        .fontWeight(.medium)
                    Text(String(format: L10n.string(.thresholdFormat), String(format: "%.0f", metrics.thresholdValue), metrics.unit))
                        .foregroundColor(.secondary)
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
    }
    
    private var processesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(.relatedProcesses))
                .font(.headline)
            
            ForEach(insight.affectedProcesses) { process in
                HStack {
                    Text(process.displayName)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(process.formattedCPU)
                        .font(.system(.caption, design: .monospaced))
                    
                    Text(process.formattedMemory)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.suggestions))
                .font(.headline)
            
            ForEach(insight.suggestedActions) { action in
                ActionCard(action: action)
            }
        }
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let action: InsightAction
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .fontWeight(.medium)
                
                Text(action.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !action.impact.isEmpty {
                    Text(action.impact)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button("Execute") {
                // Execute action
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovering ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    InsightsTab()
        .environmentObject(InsightEngine())
        .frame(width: 800, height: 600)
}
