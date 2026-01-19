import SwiftUI

/// Battery Widget - Shows battery level, health, and details
struct BatteryWidgetView: View {
    @StateObject private var batteryService = BatteryService.shared
    @EnvironmentObject var processMonitor: ProcessMonitor
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "battery.100")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Battery")
                    .font(.headline)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if batteryService.isAvailable {
                VStack(spacing: 16) {
                    // Battery visual
                    HStack(spacing: 20) {
                        BatteryVisual(
                            percentage: batteryService.batteryInfo.chargePercent,
                            isCharging: batteryService.batteryInfo.isCharging
                        )
                        
                        // Details
                        VStack(alignment: .leading, spacing: 6) {
                            DetailRowFull(label: "Level:", value: String(format: "%.0f%%", batteryService.batteryInfo.chargePercent))
                            DetailRowFull(label: "Source:", value: batteryService.batteryInfo.powerSource)
                            DetailRowFull(label: "Time:", value: batteryService.batteryInfo.timeRemaining)
                            DetailRowFull(label: "Health:", value: String(format: "%.0f%%", batteryService.batteryInfo.healthPercent))
                        }
                    }
                    
                    Divider()
                    
                    // Battery details
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            BatteryStatCard(label: "Amperage", value: "\(batteryService.batteryInfo.amperage) mA")
                            BatteryStatCard(label: "Voltage", value: String(format: "%.2f V", batteryService.batteryInfo.voltage))
                        }
                        HStack {
                            BatteryStatCard(label: "Temperature", value: String(format: "%.1f°C", batteryService.batteryInfo.temperature))
                            BatteryStatCard(label: "Cycles", value: "\(batteryService.batteryInfo.cycleCount)")
                        }
                    }
                    
                    // Adapter info
                    if batteryService.batteryInfo.isPluggedIn {
                        HStack {
                            Image(systemName: "powerplug.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Power adapter")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if batteryService.batteryInfo.adapterWatts > 0 {
                                    Text("\(batteryService.batteryInfo.adapterWatts)W connected")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Connected")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if batteryService.batteryInfo.isCharging {
                                Text("Charging")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                    } else {
                        HStack {
                            Image(systemName: "powerplug")
                                .foregroundColor(.secondary)
                            Text("Power")
                                .font(.caption)
                            Spacer()
                            Text("Not connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    // Top processes by power
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Top processes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        ForEach(topPowerProcesses.prefix(4), id: \.name) { process in
                            TopProcessRow(
                                name: process.name,
                                value: String(format: "%.1f%%", process.cpuUsage),
                                percentage: process.cpuUsage,
                                color: .orange
                            )
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "battery.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(L10n.string(.noBatteryDetected))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var topPowerProcesses: [ProcessInfo] {
        // CPU usage correlates with power consumption
        processMonitor.processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
    }
}

struct BatteryVisual: View {
    let percentage: Double
    let isCharging: Bool
    
    var body: some View {
        ZStack {
            // Battery body
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                .frame(width: 60, height: 30)
            
            // Battery tip
            Rectangle()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 4, height: 12)
                .offset(x: 32)
            
            // Fill
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(batteryColor)
                    .frame(width: max(4, 52 * percentage / 100), height: 22)
                Spacer()
            }
            .frame(width: 52)
            
            // Charging bolt
            if isCharging {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
    }
    
    private var batteryColor: Color {
        if percentage > 50 { return .green }
        if percentage > 20 { return .yellow }
        return .red
    }
}

struct BatteryStatCard: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }
}
