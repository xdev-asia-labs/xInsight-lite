import SwiftUI

/// Processes Tab with grouped process list
struct ProcessesTab: View {
    @StateObject private var processMonitor = ProcessMonitor()
    @State private var sortOrder: ProcessSortOrder = .cpu
    @State private var searchText: String = ""
    @State private var showGrouped: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            
            if showGrouped {
                groupedProcessList
            } else {
                flatProcessList
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField(L10n.string(.processes) + "...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(minWidth: 200, maxWidth: 350)
            
            Spacer()
            
            // Sort label and picker
            HStack(spacing: 8) {
                Text(L10n.string(.sort))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $sortOrder) {
                    ForEach(ProcessSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            
            // Group toggle
            Button(action: { showGrouped.toggle() }) {
                Image(systemName: showGrouped ? "rectangle.3.group" : "list.bullet")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .help(showGrouped ? "Show flat list" : "Show grouped")
        }
        .padding()
    }
    
    // MARK: - Grouped Process List
    
    private var groupedProcessList: some View {
        List {
            ForEach(ProcessCategory.allCases, id: \.self) { category in
                let processes = filteredProcesses(for: category)
                if !processes.isEmpty {
                    Section(header: categoryHeader(category, count: processes.count)) {
                        ForEach(sortedProcesses(processes)) { process in
                            ProcessRowImproved(process: process)
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
    
    private func categoryHeader(_ category: ProcessCategory, count: Int) -> some View {
        HStack {
            Image(systemName: category.iconName)
                .foregroundColor(.accentColor)
            Text(category.rawValue)
                .fontWeight(.medium)
            Spacer()
            Text(String(format: L10n.string(.numberOnly), count))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Flat Process List
    
    private var flatProcessList: some View {
        List {
            ForEach(sortedProcesses(filteredProcesses)) { process in
                ProcessRowImproved(process: process)
            }
        }
        .listStyle(.inset)
    }
    
    // MARK: - Filtering & Sorting
    
    private var filteredProcesses: [ProcessInfo] {
        if searchText.isEmpty {
            return processMonitor.processes
        }
        return processMonitor.processes.filter { process in
            process.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func filteredProcesses(for category: ProcessCategory) -> [ProcessInfo] {
        let categoryProcesses = processMonitor.groupedProcesses[category] ?? []
        if searchText.isEmpty {
            return categoryProcesses
        }
        return categoryProcesses.filter { process in
            process.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func sortedProcesses(_ processes: [ProcessInfo]) -> [ProcessInfo] {
        switch sortOrder {
        case .cpu:
            return processes.sorted { $0.cpuUsage > $1.cpuUsage }
        case .memory:
            return processes.sorted { $0.memoryUsage > $1.memoryUsage }
        case .name:
            return processes.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }
}

// MARK: - Sort Order

enum ProcessSortOrder: String, CaseIterable {
    case cpu = "CPU"
    case memory = "Memory"
    case name = "Name"
}

// MARK: - Improved Process Row

struct ProcessRowImproved: View {
    let process: ProcessInfo
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // App icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text(String(process.name.prefix(1)).uppercased())
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor)
            }
            
            // Process name and PID
            VStack(alignment: .leading, spacing: 3) {
                Text(process.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(String(format: L10n.string(.pidFormat), process.pid))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 150, alignment: .leading)
            
            Spacer()
            
            // CPU usage with bar
            HStack(spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(process.formattedCPU)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(cpuColor)
                    
                    Text(L10n.string(.cpu))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cpuColor)
                            .frame(width: geo.size.width * min(process.cpuUsage, 100) / 100)
                    }
                }
                .frame(width: 40, height: 6)
            }
            .frame(width: 100)
            
            // Memory usage
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                
                Text(L10n.string(.memory))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
            
            // Action button (visible on hover)
            Group {
                if isHovering {
                    Button(action: { terminateProcess() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help("Terminate process")
                } else {
                    Color.clear.frame(width: 24)
                }
            }
            .frame(width: 24)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
    
    private var cpuColor: Color {
        if process.cpuUsage > 80 { return .red }
        if process.cpuUsage > 50 { return .orange }
        if process.cpuUsage > 20 { return .yellow }
        return .green
    }
    
    private var categoryColor: Color {
        switch process.category {
        case .browser: return .blue
        case .developer: return .purple
        case .media: return .pink
        case .productivity: return .green
        case .communication: return .cyan
        case .system: return .gray
        case .background: return .orange
        case .other: return .secondary
        }
    }
    
    private func terminateProcess() {
        kill(process.pid, SIGTERM)
    }
}

#Preview {
    ProcessesTab()
        .frame(width: 900, height: 600)
}
