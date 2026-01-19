import WidgetKit
import SwiftUI

// MARK: - Shared Data Provider
struct SystemMetricsEntry: TimelineEntry {
    let date: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let batteryLevel: Double
    let isCharging: Bool
}

struct SystemMetricsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SystemMetricsEntry {
        SystemMetricsEntry(
            date: Date(),
            cpuUsage: 25,
            memoryUsage: 60,
            diskUsage: 45,
            batteryLevel: 80,
            isCharging: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SystemMetricsEntry) -> ()) {
        let entry = fetchCurrentMetrics()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SystemMetricsEntry>) -> ()) {
        let entry = fetchCurrentMetrics()
        
        // Update every 30 seconds
        let nextUpdate = Calendar.current.date(byAdding: .second, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func fetchCurrentMetrics() -> SystemMetricsEntry {
        // CPU Usage
        var cpuUsage: Double = 0
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let user = Double(cpuInfo.cpu_ticks.0)
            let system = Double(cpuInfo.cpu_ticks.1)
            let idle = Double(cpuInfo.cpu_ticks.2)
            let nice = Double(cpuInfo.cpu_ticks.3)
            let total = user + system + idle + nice
            cpuUsage = min(100, ((user + system) / total) * 100)
        }
        
        // Memory Usage
        var memoryUsage: Double = 0
        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let vmResult = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(vmStats.active_count) * pageSize
            let inactive = UInt64(vmStats.inactive_count) * pageSize
            let wired = UInt64(vmStats.wire_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize
            let used = active + wired + compressed
            let total = used + UInt64(vmStats.free_count) * pageSize + inactive
            memoryUsage = (Double(used) / Double(total)) * 100
        }
        
        // Disk Usage (simplified)
        var diskUsage: Double = 45  // Default placeholder
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            if let total = attributes[.systemSize] as? Int64,
               let free = attributes[.systemFreeSize] as? Int64 {
                let used = total - free
                diskUsage = (Double(used) / Double(total)) * 100
            }
        }
        
        // Battery
        let batteryLevel: Double = 80  // Would need IOKit in real implementation
        let isCharging = false
        
        return SystemMetricsEntry(
            date: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            batteryLevel: batteryLevel,
            isCharging: isCharging
        )
    }
}

// MARK: - CPU Widget
struct CPUWidgetEntryView: View {
    var entry: SystemMetricsProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }
    
    var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("CPU")
                    .font(.headline)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: entry.cpuUsage / 100)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(entry.cpuUsage))%")
                    .font(.title2.bold())
            }
            .frame(width: 80, height: 80)
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding()
    }
    
    var mediumView: some View {
        HStack(spacing: 20) {
            // CPU Gauge
            VStack {
                CircularGauge(value: entry.cpuUsage, color: .blue, label: "CPU")
            }
            
            // Memory Gauge
            VStack {
                CircularGauge(value: entry.memoryUsage, color: .green, label: "Memory")
            }
            
            // Disk Gauge
            VStack {
                CircularGauge(value: entry.diskUsage, color: .orange, label: "Disk")
            }
        }
        .padding()
    }
}

struct CircularGauge: View {
    let value: Double
    let color: Color
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(value / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(width: 50, height: 50)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Widget Configuration
struct CPUWidget: Widget {
    let kind: String = "CPUWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMetricsProvider()) { entry in
            CPUWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CPU Usage")
        .description("Shows current CPU usage")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Memory Widget
struct MemoryWidgetEntryView: View {
    var entry: SystemMetricsProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.green)
                Text("Memory")
                    .font(.headline)
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: entry.memoryUsage / 100)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(entry.memoryUsage))%")
                    .font(.title2.bold())
            }
            .frame(width: 80, height: 80)
            .frame(maxWidth: .infinity)
            
            Spacer()
        }
        .padding()
    }
}

struct MemoryWidget: Widget {
    let kind: String = "MemoryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMetricsProvider()) { entry in
            MemoryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Memory Usage")
        .description("Shows current memory usage")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - System Overview Widget
struct SystemOverviewWidget: Widget {
    let kind: String = "SystemOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SystemMetricsProvider()) { entry in
            SystemOverviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("System Overview")
        .description("Shows CPU, Memory, and Disk usage")
        .supportedFamilies([.systemMedium])
    }
}

struct SystemOverviewWidgetView: View {
    var entry: SystemMetricsProvider.Entry
    
    var body: some View {
        HStack(spacing: 20) {
            metricColumn(
                icon: "cpu",
                label: "CPU",
                value: entry.cpuUsage,
                color: .blue
            )
            
            metricColumn(
                icon: "memorychip",
                label: "RAM",
                value: entry.memoryUsage,
                color: .green
            )
            
            metricColumn(
                icon: "internaldrive",
                label: "Disk",
                value: entry.diskUsage,
                color: .orange
            )
        }
        .padding()
    }
    
    func metricColumn(icon: String, label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: value / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(value))%")
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(width: 45, height: 45)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CPUWidget()
} timeline: {
    SystemMetricsEntry(date: .now, cpuUsage: 35, memoryUsage: 60, diskUsage: 45, batteryLevel: 80, isCharging: false)
}
