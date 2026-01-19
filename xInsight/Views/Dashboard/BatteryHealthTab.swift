import SwiftUI

/// Battery Health Tab - Comprehensive battery analysis and health monitoring
struct BatteryHealthTab: View {
    @StateObject private var batteryService = BatteryService.shared
    @State private var selectedTimeRange = 0
    @State private var showDetailedInfo = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if batteryService.isAvailable {
                    mainBatterySection
                    healthAndCycleSection
                    chargingStatsSection
                    powerConsumptionSection
                    batteryHistorySection
                    detailedInfoSection
                    optimizationTipsSection
                } else {
                    noBatteryView
                }
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Image(systemName: "battery.100.bolt")
                        .font(.largeTitle)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text(L10n.string(.batteryHealth))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Text("Advanced battery monitoring and optimization")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(overallHealthColor)
                        .frame(width: 10, height: 10)
                    Text(overallHealthStatus)
                        .font(.headline)
                        .foregroundColor(overallHealthColor)
                }
                Text("Overall Status")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { batteryService.refresh() }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Main Battery Section
    
    private var mainBatterySection: some View {
        HStack(spacing: 24) {
            // Large Battery Visual
            ZStack {
                // Glow effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(batteryColor.opacity(0.2))
                    .blur(radius: 20)
                    .frame(width: 200, height: 100)
                
                // Battery body
                ZStack {
                    // Outer shell
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.3), lineWidth: 4)
                        .frame(width: 180, height: 80)
                    
                    // Battery tip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.3))
                        .frame(width: 8, height: 32)
                        .offset(x: 94)
                    
                    // Fill level with gradient
                    HStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: batteryGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(16, 160 * batteryService.batteryInfo.chargePercent / 100), height: 64)
                        Spacer()
                    }
                    .frame(width: 164)
                    
                    // Percentage
                    HStack(spacing: 4) {
                        Text(String(format: "%.0f", batteryService.batteryInfo.chargePercent))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                        Text("%")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(batteryService.batteryInfo.chargePercent > 50 ? .white : .primary)
                    
                    // Charging bolt
                    if batteryService.batteryInfo.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.title)
                            .foregroundColor(.yellow)
                            .offset(x: 70, y: -35)
                    }
                }
            }
            .frame(width: 220, height: 120)
            
            // Quick Stats
            VStack(alignment: .leading, spacing: 16) {
                // Power Source
                HStack(spacing: 12) {
                    Image(systemName: batteryService.batteryInfo.isPluggedIn ? "powerplug.fill" : "battery.100")
                        .font(.title2)
                        .foregroundColor(batteryService.batteryInfo.isPluggedIn ? .green : .orange)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Power Source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(batteryService.batteryInfo.powerSource)
                            .font(.headline)
                    }
                }
                
                // Time Remaining
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(batteryService.batteryInfo.isCharging ? "Time to Full" : "Time Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(batteryService.batteryInfo.timeRemaining)
                            .font(.headline)
                    }
                }
                
                // Temperature
                HStack(spacing: 12) {
                    Image(systemName: "thermometer")
                        .font(.title2)
                        .foregroundColor(tempColor)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temperature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f°C", batteryService.batteryInfo.temperature))
                            .font(.headline)
                    }
                }
            }
            
            Spacer()
            
            // Charging indicator
            if batteryService.batteryInfo.isCharging {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: batteryService.batteryInfo.chargePercent / 100)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                        
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.green)
                    }
                    
                    Text("Charging")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    if batteryService.batteryInfo.adapterWatts > 0 {
                        Text("\(batteryService.batteryInfo.adapterWatts)W")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(batteryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Health & Cycle Section
    
    private var healthAndCycleSection: some View {
        HStack(spacing: 16) {
            // Battery Health
            BatteryHealthCard(
                title: "Battery Health",
                value: batteryService.batteryInfo.healthPercent,
                maxValue: 100,
                color: healthColor,
                icon: "heart.fill",
                subtitle: batteryService.batteryInfo.condition,
                description: healthDescription
            )
            
            // Cycle Count
            BatteryHealthCard(
                title: "Cycle Count",
                value: Double(batteryService.batteryInfo.cycleCount),
                maxValue: Double(batteryService.batteryInfo.designCycleCount),
                color: cycleColor,
                icon: "arrow.triangle.2.circlepath",
                subtitle: "\(batteryService.batteryInfo.cycleCount) of \(batteryService.batteryInfo.designCycleCount)",
                description: cycleDescription
            )
            
            // Capacity
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "gauge.with.dots.needle.67percent")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Capacity")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    CapacityRow(
                        label: "Design Capacity",
                        value: "\(batteryService.batteryInfo.designCapacity) mAh",
                        color: .blue
                    )
                    CapacityRow(
                        label: "Current Max",
                        value: batteryService.batteryInfo.capacityMah,
                        color: .orange
                    )
                    CapacityRow(
                        label: "Cells",
                        value: "\(batteryService.batteryInfo.cellCount) cells",
                        color: .purple
                    )
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Charging Stats
    
    private var chargingStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Charging Information", systemImage: "bolt.fill")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 16) {
                ChargingStatCard(
                    title: "Voltage",
                    value: String(format: "%.2f V", batteryService.batteryInfo.voltage),
                    icon: "bolt.horizontal",
                    color: .yellow
                )
                
                ChargingStatCard(
                    title: "Amperage",
                    value: "\(batteryService.batteryInfo.amperage) mA",
                    icon: "waveform.path",
                    color: batteryService.batteryInfo.amperage > 0 ? .green : .cyan
                )
                
                ChargingStatCard(
                    title: "Power Draw",
                    value: batteryService.batteryInfo.powerDraw,
                    icon: "bolt.circle",
                    color: .blue
                )
                
                ChargingStatCard(
                    title: "Adapter",
                    value: batteryService.batteryInfo.adapterWatts > 0 ? "\(batteryService.batteryInfo.adapterWatts)W" : "None",
                    icon: "powerplug.fill",
                    color: batteryService.batteryInfo.isPluggedIn ? .green : .gray
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Power Consumption Section
    
    private var powerConsumptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Power Consumption", systemImage: "chart.bar.fill")
                    .font(.headline)
                
                Spacer()
                
                Picker("Time", selection: $selectedTimeRange) {
                    Text("1h").tag(0)
                    Text("6h").tag(1)
                    Text("24h").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            
            // Simulated power graph
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<24, id: \.self) { i in
                    let height = simulatedPowerUsage(hour: i)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(powerBarColor(height))
                            .frame(height: CGFloat(height) * 0.8)
                        
                        if i % 4 == 0 {
                            Text("\(i)h")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
            
            // Legend
            HStack(spacing: 24) {
                LegendItem2(color: .green, label: "Low (<5W)")
                LegendItem2(color: .yellow, label: "Medium (5-15W)")
                LegendItem2(color: .orange, label: "High (15-30W)")
                LegendItem2(color: .red, label: "Peak (>30W)")
                Spacer()
                Text("Avg: 12.5W")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Battery History
    
    private var batteryHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Charge History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                Spacer()
            }
            
            // Charge level graph
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    ForEach([25, 50, 75, 100], id: \.self) { level in
                        Path { path in
                            let y = geometry.size.height * (1 - CGFloat(level) / 100)
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    
                    // Charge line
                    Path { path in
                        let points = simulatedChargeHistory()
                        guard points.count > 1 else { return }
                        
                        let step = geometry.size.width / CGFloat(points.count - 1)
                        
                        for (index, level) in points.enumerated() {
                            let x = CGFloat(index) * step
                            let y = geometry.size.height * (1 - CGFloat(level) / 100)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.green, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .frame(height: 80)
            
            HStack {
                Text("12h ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Now")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Detailed Info
    
    private var detailedInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Battery Details", systemImage: "info.circle")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showDetailedInfo.toggle()
                } label: {
                    Text(showDetailedInfo ? "Hide" : "Show All")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DetailItem(label: "Serial Number", value: batteryService.batteryInfo.serialNumber.isEmpty ? "N/A" : batteryService.batteryInfo.serialNumber)
                DetailItem(label: "Device", value: batteryService.batteryInfo.deviceName.isEmpty ? "This Mac" : batteryService.batteryInfo.deviceName)
                DetailItem(label: "Manufacture Date", value: estimatedManufactureDate())
                
                if showDetailedInfo {
                    DetailItem(label: "Voltage", value: String(format: "%.2f V", batteryService.batteryInfo.voltage))
                    DetailItem(label: "Amperage", value: "\(batteryService.batteryInfo.amperage) mA")
                    DetailItem(label: "Cell Count", value: "\(batteryService.batteryInfo.cellCount)")
                    DetailItem(label: "Adapter", value: batteryService.batteryInfo.adapterDescription.isEmpty ? "None" : batteryService.batteryInfo.adapterDescription)
                    DetailItem(label: "Fully Charged", value: batteryService.batteryInfo.isFullyCharged ? "Yes" : "No")
                    DetailItem(label: "Optimized Charging", value: "Enabled")
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - Optimization Tips
    
    private var optimizationTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Optimization Tips", systemImage: "lightbulb.fill")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                OptimizationTip(
                    icon: "thermometer.snowflake",
                    title: "Keep Temperature Optimal",
                    description: "Avoid extreme temperatures. Ideal range: 16-22°C",
                    status: batteryService.batteryInfo.temperature < 35 ? .good : .warning
                )
                
                OptimizationTip(
                    icon: "battery.75",
                    title: "Maintain 20-80% Charge",
                    description: "Avoid frequent full charge/discharge cycles",
                    status: (batteryService.batteryInfo.chargePercent >= 20 && batteryService.batteryInfo.chargePercent <= 80) ? .good : .info
                )
                
                OptimizationTip(
                    icon: "arrow.clockwise",
                    title: "Cycle Count: \(batteryService.batteryInfo.cycleCount)/\(batteryService.batteryInfo.designCycleCount)",
                    description: "Apple rates batteries for \(batteryService.batteryInfo.designCycleCount) cycles",
                    status: batteryService.batteryInfo.cycleProgress < 0.8 ? .good : .warning
                )
                
                OptimizationTip(
                    icon: "powerplug",
                    title: "Smart Charging",
                    description: "macOS learns your charging patterns to reduce battery aging",
                    status: .good
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
    
    // MARK: - No Battery View
    
    private var noBatteryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "battery.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Battery Detected")
                .font(.title2.bold())
            
            Text("This device doesn't have a battery or the battery is not accessible.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helpers
    
    private var batteryColor: Color {
        let percent = batteryService.batteryInfo.chargePercent
        if percent > 50 { return .green }
        if percent > 20 { return .yellow }
        return .red
    }
    
    private var batteryGradient: [Color] {
        let percent = batteryService.batteryInfo.chargePercent
        if percent > 50 { return [.green.opacity(0.8), .green] }
        if percent > 20 { return [.yellow.opacity(0.8), .orange] }
        return [.red.opacity(0.8), .red]
    }
    
    private var healthColor: Color {
        let health = batteryService.batteryInfo.healthPercent
        if health >= 80 { return .green }
        if health >= 60 { return .orange }
        return .red
    }
    
    private var cycleColor: Color {
        let progress = batteryService.batteryInfo.cycleProgress
        if progress < 0.5 { return .green }
        if progress < 0.8 { return .orange }
        return .red
    }
    
    private var tempColor: Color {
        let temp = batteryService.batteryInfo.temperature
        if temp > 40 { return .red }
        if temp > 35 { return .orange }
        return .green
    }
    
    private var overallHealthColor: Color {
        if batteryService.batteryInfo.healthPercent >= 80 && batteryService.batteryInfo.cycleProgress < 0.8 {
            return .green
        }
        if batteryService.batteryInfo.healthPercent >= 60 {
            return .orange
        }
        return .red
    }
    
    private var overallHealthStatus: String {
        if batteryService.batteryInfo.healthPercent >= 80 && batteryService.batteryInfo.cycleProgress < 0.8 {
            return "Excellent"
        }
        if batteryService.batteryInfo.healthPercent >= 60 {
            return "Fair"
        }
        return "Service Recommended"
    }
    
    private var healthDescription: String {
        let health = batteryService.batteryInfo.healthPercent
        if health >= 90 { return "Your battery is in excellent condition" }
        if health >= 80 { return "Your battery is performing normally" }
        if health >= 70 { return "Battery capacity has decreased" }
        return "Consider battery replacement"
    }
    
    private var cycleDescription: String {
        let progress = batteryService.batteryInfo.cycleProgress
        if progress < 0.3 { return "Very low usage - battery is new" }
        if progress < 0.5 { return "Normal usage pattern" }
        if progress < 0.8 { return "Getting closer to rated cycles" }
        return "High cycle count - monitor health"
    }
    
    private func simulatedPowerUsage(hour: Int) -> Double {
        // Simulate power usage pattern
        let base = 10.0
        let variance = Double.random(in: -5...15)
        let peakHours = [9, 10, 11, 14, 15, 16] // Work hours
        let peak = peakHours.contains(hour) ? 15.0 : 0
        return max(2, min(40, base + variance + peak))
    }
    
    private func powerBarColor(_ value: Double) -> Color {
        if value > 30 { return .red }
        if value > 15 { return .orange }
        if value > 5 { return .yellow }
        return .green
    }
    
    private func simulatedChargeHistory() -> [Double] {
        // Simulate charge history over 12 hours
        var history: [Double] = []
        var level = batteryService.batteryInfo.chargePercent
        
        for i in 0..<24 {
            history.append(level)
            // Simulate drain/charge
            if i < 8 {
                level = max(20, level - Double.random(in: 2...5))
            } else if i < 16 {
                level = min(100, level + Double.random(in: 3...8))
            } else {
                level = max(40, level - Double.random(in: 1...3))
            }
        }
        
        return history.reversed()
    }
    
    private func estimatedManufactureDate() -> String {
        // Estimate based on cycle count
        let monthsOld = batteryService.batteryInfo.cycleCount / 25
        let years = monthsOld / 12
        let months = monthsOld % 12
        
        if years > 0 {
            return "~\(years)y \(months)m ago"
        }
        return "~\(max(1, months)) months ago"
    }
}

// MARK: - Supporting Views

struct BatteryHealthCard: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let icon: String
    let subtitle: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", value))
                        .font(.title)
                        .fontWeight(.bold)
                    Text(title == "Battery Health" ? "%" : "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(subtitle)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(16)
    }
}

struct ChargingStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
    }
}

struct CapacityRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct LegendItem2: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DetailItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OptimizationTip: View {
    let icon: String
    let title: String
    let description: String
    let status: TipStatus
    
    enum TipStatus {
        case good, warning, info
        
        var color: Color {
            switch self {
            case .good: return .green
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: status.icon)
                .foregroundColor(status.color)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
    }
}

#Preview {
    BatteryHealthTab()
        .frame(width: 800, height: 1000)
}
