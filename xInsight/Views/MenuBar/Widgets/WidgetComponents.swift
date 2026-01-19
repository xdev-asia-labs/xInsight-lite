import SwiftUI

/// Reusable mini chart view for menu bar widgets
struct MiniChartView: View {
    let data: [Double]
    let maxValue: Double
    let color: Color
    var height: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            let barWidth = geometry.size.width / CGFloat(max(data.count, 1))
            
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                    let normalizedHeight = min(value / maxValue, 1.0) * geometry.size.height
                    
                    Rectangle()
                        .fill(color.opacity(0.8))
                        .frame(width: max(barWidth - 1, 2), height: max(normalizedHeight, 1))
                }
            }
        }
        .frame(height: height)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
        .accessibilityIdentifier("mini_chart")
    }
}

/// Circular progress gauge for widgets
struct MiniGaugeView: View {
    let value: Double
    let maxValue: Double
    let color: Color
    var size: CGFloat = 60
    var showPercentage: Bool = true
    
    private var progress: Double {
        min(value / maxValue, 1.0)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            if showPercentage {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: size / 4, weight: .bold, design: .monospaced))
            }
        }
        .frame(width: size, height: size)
        .accessibilityIdentifier("mini_gauge_\(Int(progress * 100))")
    }
}

/// Process row for top processes list
struct TopProcessRow: View {
    let name: String
    let value: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        MiniChartView(
            data: [20, 35, 50, 45, 60, 55, 70, 65, 80, 75],
            maxValue: 100,
            color: .blue
        )
        .frame(width: 150, height: 40)
        
        MiniGaugeView(value: 65, maxValue: 100, color: .green)
    }
    .padding()
}
