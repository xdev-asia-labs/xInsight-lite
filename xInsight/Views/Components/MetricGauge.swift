import SwiftUI

/// Circular gauge for displaying metrics
struct MetricGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    
    private var progress: Double {
        min(value / maxValue, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Center content
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Text(formattedValue)
                        .font(.title)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 120, height: 120)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var formattedValue: String {
        if unit == "%" || unit == "°C" {
            return String(format: "%.0f%@", value, unit)
        }
        return String(format: "%.0f", value)
    }
}

#Preview {
    HStack {
        MetricGauge(
            title: "CPU",
            value: 65,
            maxValue: 100,
            unit: "%",
            icon: "cpu",
            color: .orange
        )
        
        MetricGauge(
            title: "Memory",
            value: 12.5,
            maxValue: 16,
            unit: "GB",
            icon: "memorychip",
            color: .blue,
            subtitle: "12.5/16 GB"
        )
    }
    .padding()
    .frame(height: 200)
}
