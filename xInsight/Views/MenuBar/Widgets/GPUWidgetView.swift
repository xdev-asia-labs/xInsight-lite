import SwiftUI

/// GPU Widget - Shows GPU usage, temperature, and info
struct GPUWidgetView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.3.group")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("GPU")
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
            
            VStack(spacing: 16) {
                // GPU Cards
                VStack(spacing: 12) {
                    GPUCardView(
                        name: "Apple Silicon GPU",
                        usage: metricsCollector.currentMetrics.gpuUsage,
                        temperature: metricsCollector.currentMetrics.gpuTemperature
                    )
                }
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Cores")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(getGPUCores()) cores")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Memory")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Unified")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 260)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func getGPUCores() -> Int {
        var size = 0
        sysctlbyname("hw.perflevel0.logicalcpu", nil, &size, nil, 0)
        // Approximate GPU cores for Apple Silicon
        return 10 // Default for M1/M2
    }
}

/// Individual GPU card
struct GPUCardView: View {
    let name: String
    let usage: Double
    let temperature: Double
    
    var body: some View {
        HStack(spacing: 12) {
            // Gauge
            MiniGaugeView(
                value: usage,
                maxValue: 100,
                color: gpuColor,
                size: 50
            )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "thermometer")
                            .font(.caption2)
                        Text(String(format: "%.0f°C", temperature))
                            .font(.caption)
                    }
                    .foregroundColor(temperature > 70 ? .orange : .secondary)
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var gpuColor: Color {
        if usage > 80 { return .red }
        if usage > 50 { return .orange }
        return .green
    }
}
