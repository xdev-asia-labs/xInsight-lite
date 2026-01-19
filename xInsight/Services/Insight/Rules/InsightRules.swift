import Foundation

/// Protocol for insight rules
protocol InsightRule {
    /// Evaluate the rule and return an insight if conditions are met
    func evaluate(
        metrics: SystemMetrics,
        processes: [ProcessInfo],
        correlations: [Correlation],
        anomalies: [Anomaly]
    ) -> Insight?
}

// MARK: - CPU Saturation Rule

struct CPUSaturationRule: InsightRule {
    func evaluate(
        metrics: SystemMetrics,
        processes: [ProcessInfo],
        correlations: [Correlation],
        anomalies: [Anomaly]
    ) -> Insight? {
        // Trigger when CPU usage > 80%
        guard metrics.cpuUsage > 80 else { return nil }
        
        // Find top CPU consumers
        let topProcesses = processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(5)
        
        guard let topProcess = topProcesses.first else { return nil }
        
        // Generate human-readable description
        let description = generateDescription(
            topProcess: topProcess,
            totalCPU: metrics.cpuUsage,
            thermalState: metrics.thermalState
        )
        
        let severity: Severity = metrics.cpuUsage > 95 ? .critical : .warning
        
        // Generate suggested actions
        var actions: [InsightAction] = []
        
        if topProcess.cpuUsage > 50 {
            actions.append(InsightAction(
                title: "Đóng \(topProcess.displayName)",
                description: "App này đang sử dụng nhiều CPU nhất",
                actionType: .quitApp(pid: topProcess.pid),
                impact: "Giải phóng ~\(Int(topProcess.cpuUsage))% CPU"
            ))
        }
        
        actions.append(InsightAction(
            title: "Mở Activity Monitor",
            description: "Xem chi tiết tất cả processes",
            actionType: .openActivityMonitor,
            impact: ""
        ))
        
        return Insight(
            type: .cpuSaturation,
            severity: severity,
            title: "CPU đang quá tải (\(Int(metrics.cpuUsage))%)",
            description: description,
            cause: "\(topProcess.displayName) đang sử dụng \(Int(topProcess.cpuUsage))% CPU",
            affectedProcesses: Array(topProcesses),
            suggestedActions: actions,
            metrics: InsightMetrics(
                currentValue: metrics.cpuUsage,
                thresholdValue: 80,
                unit: "%",
                trend: .stable
            )
        )
    }
    
    private func generateDescription(
        topProcess: ProcessInfo,
        totalCPU: Double,
        thermalState: ThermalState
    ) -> String {
        let name = topProcess.displayName
        let cpu = Int(topProcess.cpuUsage)
        
        // Special case: kernel_task indicates thermal throttling
        if name == "kernel_task" && cpu > 30 {
            return "Hệ thống đang thermal throttling để làm mát. CPU cần giảm tải để tránh quá nhiệt."
        }
        
        // Browser with high CPU
        if topProcess.category == .browser {
            return "\(name) đang ngốn \(cpu)% CPU. Có thể do nhiều tabs đang mở hoặc có extension nặng."
        }
        
        // Xcode building
        if name.lowercased().contains("xcode") || name.contains("clang") || name.contains("swift") {
            return "Xcode đang compile code, sử dụng \(cpu)% CPU. Build sẽ hoàn thành sớm."
        }
        
        // Docker
        if name.lowercased().contains("docker") || name.contains("com.docker") {
            return "Docker containers đang hoạt động mạnh, sử dụng \(cpu)% CPU."
        }
        
        // Generic description
        return "\(name) đang sử dụng \(cpu)% CPU, chiếm phần lớn tài nguyên xử lý."
    }
}

// MARK: - Memory Pressure Rule

struct MemoryPressureRule: InsightRule {
    func evaluate(
        metrics: SystemMetrics,
        processes: [ProcessInfo],
        correlations: [Correlation],
        anomalies: [Anomaly]
    ) -> Insight? {
        // Trigger on warning or critical memory pressure
        guard metrics.memoryPressure != .normal else { return nil }
        
        // Find top memory consumers
        let topProcesses = processes
            .sorted { $0.memoryUsage > $1.memoryUsage }
            .prefix(5)
        
        guard let topProcess = topProcesses.first else { return nil }
        
        let description = generateDescription(
            topProcess: topProcess,
            metrics: metrics
        )
        
        let severity: Severity = metrics.memoryPressure == .critical ? .critical : .warning
        
        var actions: [InsightAction] = []
        
        let memoryGB = Double(topProcess.memoryUsage) / 1_073_741_824
        if memoryGB > 1 {
            actions.append(InsightAction(
                title: "Đóng \(topProcess.displayName)",
                description: "App này đang chiếm nhiều RAM nhất",
                actionType: .quitApp(pid: topProcess.pid),
                impact: "Giải phóng ~\(String(format: "%.1f", memoryGB))GB RAM"
            ))
        }
        
        return Insight(
            type: .memoryPressure,
            severity: severity,
            title: "Bộ nhớ đang chịu áp lực \(metrics.memoryPressure.rawValue)",
            description: description,
            cause: "\(topProcess.displayName) đang chiếm \(topProcess.formattedMemory)",
            affectedProcesses: Array(topProcesses),
            suggestedActions: actions,
            metrics: InsightMetrics(
                currentValue: metrics.memoryUsagePercent,
                thresholdValue: 75,
                unit: "%",
                trend: .stable
            )
        )
    }
    
    private func generateDescription(topProcess: ProcessInfo, metrics: SystemMetrics) -> String {
        let totalMemGB = Double(metrics.memoryTotal) / 1_073_741_824
        let usedMemGB = Double(metrics.memoryUsed) / 1_073_741_824
        let swapMB = Double(metrics.swapUsed) / 1_048_576
        
        var desc = "Đang sử dụng \(String(format: "%.1f", usedMemGB))GB / \(String(format: "%.0f", totalMemGB))GB RAM. "
        
        if swapMB > 100 {
            desc += "Hệ thống đang dùng \(String(format: "%.0f", swapMB))MB swap, có thể gây chậm. "
        }
        
        let topMemGB = Double(topProcess.memoryUsage) / 1_073_741_824
        if topMemGB > 2 {
            desc += "\(topProcess.displayName) đang chiếm \(String(format: "%.1f", topMemGB))GB."
        }
        
        return desc
    }
}

// MARK: - I/O Bottleneck Rule

struct IOBottleneckRule: InsightRule {
    func evaluate(
        metrics: SystemMetrics,
        processes: [ProcessInfo],
        correlations: [Correlation],
        anomalies: [Anomaly]
    ) -> Insight? {
        // Trigger when disk I/O is very high
        let totalIO = metrics.diskReadRate + metrics.diskWriteRate
        guard totalIO > 100 else { return nil }  // > 100 MB/s
        
        let description = generateDescription(metrics: metrics, correlations: correlations)
        
        let severity: Severity = totalIO > 200 ? .critical : .warning
        
        return Insight(
            type: .ioBottleneck,
            severity: severity,
            title: "Disk I/O cao (\(String(format: "%.0f", totalIO)) MB/s)",
            description: description,
            cause: "Đọc: \(metrics.formattedDiskRead), Ghi: \(metrics.formattedDiskWrite)",
            affectedProcesses: [],
            suggestedActions: [
                InsightAction(
                    title: "Đợi hoàn thành",
                    description: "I/O thường giảm sau vài phút",
                    actionType: .reduceLoad(suggestions: ["Tránh copy files lớn khác", "Đợi Spotlight index xong"]),
                    impact: ""
                )
            ],
            metrics: InsightMetrics(
                currentValue: totalIO,
                thresholdValue: 100,
                unit: "MB/s",
                trend: .stable
            )
        )
    }
    
    private func generateDescription(metrics: SystemMetrics, correlations: [Correlation]) -> String {
        let diskCorrelations = correlations.filter { $0.sourceMetric == "Disk I/O" }
        
        if let topCorrelation = diskCorrelations.first {
            return topCorrelation.description
        }
        
        if metrics.diskWriteRate > metrics.diskReadRate * 2 {
            return "Đang ghi nhiều dữ liệu. Có thể là backup, download, hoặc app đang save files lớn."
        }
        
        if metrics.diskReadRate > metrics.diskWriteRate * 2 {
            return "Đang đọc nhiều dữ liệu. Có thể là app đang load files hoặc Spotlight đang index."
        }
        
        return "Disk đang hoạt động nặng với cả đọc và ghi. Hệ thống có thể chậm lại."
    }
}

// MARK: - Thermal Throttling Rule

struct ThermalThrottlingRule: InsightRule {
    func evaluate(
        metrics: SystemMetrics,
        processes: [ProcessInfo],
        correlations: [Correlation],
        anomalies: [Anomaly]
    ) -> Insight? {
        // Trigger on serious or critical thermal state
        guard metrics.thermalState == .serious || metrics.thermalState == .critical else {
            return nil
        }
        
        let severity: Severity = metrics.thermalState == .critical ? .critical : .warning
        
        let description = generateDescription(metrics: metrics)
        
        var actions: [InsightAction] = []
        
        actions.append(InsightAction(
            title: "Giảm tải CPU",
            description: "Đóng các app không cần thiết",
            actionType: .reduceLoad(suggestions: [
                "Đóng browser tabs không dùng",
                "Pause downloads/uploads",
                "Quit heavy apps"
            ]),
            impact: "Giúp CPU mát hơn"
        ))
        
        actions.append(InsightAction(
            title: "Cải thiện thông gió",
            description: "Đảm bảo Mac có không gian thoáng",
            actionType: .reduceLoad(suggestions: [
                "Không đặt Mac trên chăn/gối",
                "Dùng laptop stand",
                "Tránh ánh nắng trực tiếp"
            ]),
            impact: "Cải thiện tản nhiệt"
        ))
        
        return Insight(
            type: .thermalThrottling,
            severity: severity,
            title: "Mac đang quá nóng - CPU throttling",
            description: description,
            cause: "Nhiệt độ CPU: \(metrics.formattedCPUTemp)",
            affectedProcesses: [],
            suggestedActions: actions,
            metrics: InsightMetrics(
                currentValue: metrics.cpuTemperature,
                thresholdValue: 80,
                unit: "°C",
                trend: .increasing
            )
        )
    }
    
    private func generateDescription(metrics: SystemMetrics) -> String {
        var desc = "Mac đang \(metrics.thermalState.description.lowercased()). "
        
        if metrics.thermalState == .critical {
            desc += "CPU đang bị giảm tốc độ mạnh để làm mát. Hiệu năng sẽ giảm đáng kể."
        } else {
            desc += "CPU có thể bị giảm hiệu năng để tránh quá nhiệt."
        }
        
        if metrics.fanSpeed > 0 {
            desc += " Fan đang chạy ở \(metrics.fanSpeed) RPM."
        }
        
        return desc
    }
}
