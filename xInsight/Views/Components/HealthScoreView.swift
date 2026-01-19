import SwiftUI

/// HealthScoreView - Visual display of system health score
struct HealthScoreView: View {
    @StateObject private var healthScore = SystemHealthScore.shared
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    var body: some View {
        VStack(spacing: 20) {
            // Main Score Circle
            scoreCircle
            
            // Status Badge
            statusBadge
            
            // Component Scores
            componentScores
            
            // Recommendations
            if !healthScore.recommendations.isEmpty {
                recommendationsSection
            }
        }
        .padding()
        .onReceive(metricsCollector.$currentMetrics) { metrics in
            healthScore.calculate(from: metrics)
        }
    }
    
    // MARK: - Score Circle
    
    private var scoreCircle: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .frame(width: 180, height: 180)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(healthScore.overallScore) / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                .frame(width: 180, height: 180)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: healthScore.overallScore)
            
            // Score text
            VStack(spacing: 4) {
                Text("\(healthScore.overallScore)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text("Health Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var scoreColor: Color {
        switch healthScore.overallScore {
        case 90...100: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        case 30..<50: return .orange
        default: return .red
        }
    }
    
    // MARK: - Status Badge
    
    private var statusBadge: some View {
        HStack {
            Text(healthScore.healthStatus.emoji)
            Text(healthScore.healthStatus.rawValue)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(scoreColor.opacity(0.15))
        .cornerRadius(20)
    }
    
    // MARK: - Component Scores
    
    private var componentScores: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            componentScore(title: "CPU", score: healthScore.cpuScore, icon: "cpu")
            componentScore(title: "Memory", score: healthScore.memoryScore, icon: "memorychip")
            componentScore(title: "Thermal", score: healthScore.thermalScore, icon: "thermometer")
            componentScore(title: "Disk", score: healthScore.diskScore, icon: "internaldrive")
            componentScore(title: "Battery", score: healthScore.batteryScore, icon: "battery.100")
        }
    }
    
    private func componentScore(title: String, score: Int, icon: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundColor(.secondary)
            
            Text("\(score)")
                .font(.title2.bold())
                .foregroundColor(colorForScore(score))
            
            ProgressView(value: Double(score), total: 100)
                .progressViewStyle(.linear)
                .tint(colorForScore(score))
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        case 20..<40: return .orange
        default: return .red
        }
    }
    
    // MARK: - Recommendations
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            ForEach(healthScore.recommendations) { rec in
                HStack {
                    Image(systemName: rec.category.icon)
                        .foregroundColor(impactColor(rec.impact))
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(rec.title)
                            .font(.subheadline.bold())
                        Text(rec.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if rec.action != nil {
                        Button("Fix") {
                            executeAction(rec.action!)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(impactColor(rec.impact).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func impactColor(_ impact: HealthRecommendation.Impact) -> Color {
        switch impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        }
    }
    
    private func executeAction(_ action: HealthRecommendation.RecommendationAction) {
        switch action {
        case .killProcess(let pid):
            kill(pid, SIGTERM)
        case .reduceLoad:
            // Show suggestion
            break
        case .openSettings:
            // Open settings
            break
        case .cleanup:
            // Go to cleanup tab
            break
        }
    }
}

/// Compact health score for Overview/Status Bar
struct CompactHealthScore: View {
    @StateObject private var healthScore = SystemHealthScore.shared
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: CGFloat(healthScore.overallScore) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                
                Text("\(healthScore.overallScore)")
                    .font(.caption2.bold())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Health")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(healthScore.healthStatus.rawValue)
                    .font(.caption.bold())
            }
        }
    }
    
    private var scoreColor: Color {
        switch healthScore.overallScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }
}
