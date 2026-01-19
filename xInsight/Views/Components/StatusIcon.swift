import SwiftUI

/// Status icon for menu bar
struct StatusIcon: View {
    let status: SystemStatus
    
    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundColor(iconColor)
    }
    
    private var iconName: String {
        switch status {
        case .normal:
            return "gauge.with.dots.needle.bottom.50percent"
        case .warning:
            return "gauge.with.dots.needle.bottom.50percent.badge.plus"
        case .critical:
            return "gauge.with.dots.needle.bottom.100percent"
        }
    }
    
    private var iconColor: Color {
        switch status {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        StatusIcon(status: .normal)
        StatusIcon(status: .warning)
        StatusIcon(status: .critical)
    }
    .font(.title)
    .padding()
}
