import SwiftUI

/// Card component for displaying insights
struct InsightCard: View {
    let insight: Insight
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: insight.severity.iconName)
                    .foregroundColor(severityColor)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)
                    
                    Text(insight.cause)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Type badge
                Text(insight.type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                    
                    Text(insight.description)
                        .font(.callout)
                        .foregroundColor(.secondary)
                    
                    // Metrics bar
                    if let metrics = insight.metrics {
                        MetricsBar(
                            current: metrics.currentValue,
                            threshold: metrics.thresholdValue,
                            unit: metrics.unit,
                            color: severityColor
                        )
                    }
                    
                    // Actions
                    if !insight.suggestedActions.isEmpty {
                        HStack {
                            ForEach(insight.suggestedActions.prefix(2)) { action in
                                Button(action.title) {
                                    // Execute action
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? severityColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
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
}

// MARK: - Metrics Bar

struct MetricsBar: View {
    let current: Double
    let threshold: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        min(current / threshold, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(format: L10n.string(.currentFormat), String(format: "%.0f", current), unit))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: L10n.string(.thresholdLabel), String(format: "%.0f", threshold), unit))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * progress)
                    
                    // Threshold marker
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: geometry.size.width - 2)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    VStack {
        InsightCard(insight: Insight(
            type: .cpuSaturation,
            severity: .warning,
            title: "CPU đang quá tải (85%)",
            description: "Chrome đang sử dụng nhiều CPU do có 20 tabs đang mở",
            cause: "Google Chrome Helper: 65% CPU",
            suggestedActions: [
                InsightAction(
                    title: "Đóng Chrome",
                    description: "Giải phóng CPU",
                    actionType: .quitApp(pid: 123),
                    impact: "Giải phóng ~65% CPU"
                )
            ],
            metrics: InsightMetrics(
                currentValue: 85,
                thresholdValue: 80,
                unit: "%",
                trend: .increasing
            )
        ))
    }
    .padding()
    .frame(width: 500)
}
