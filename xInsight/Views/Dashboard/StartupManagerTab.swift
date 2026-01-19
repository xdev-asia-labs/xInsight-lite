import SwiftUI

/// Startup Manager Tab - Manage login items and launch agents
struct StartupManagerTab: View {
    @StateObject private var startupManager = StartupManager.shared
    @State private var selectedAgent: LaunchAgent?
    @State private var showRemoveConfirmation = false
    @State private var filter: LaunchAgent.Category? = nil
    
    var filteredAgents: [LaunchAgent] {
        if let filter = filter {
            return startupManager.launchAgents.filter { $0.category == filter }
        }
        return startupManager.launchAgents
    }
    
    var body: some View {
        HSplitView {
            // Agent List
            agentListView
                .frame(minWidth: 350)
            
            // Details
            detailView
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await startupManager.scan()
        }
    }
    
    // MARK: - Agent List
    
    private var agentListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.string(.startupManager))
                    .font(.headline)
                
                Spacer()
                
                if startupManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(String(format: L10n.string(.itemsCount), startupManager.launchAgents.count))
                        .foregroundColor(.secondary)
                }
                
                Button(action: { Task { await startupManager.scan() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            // Filter
            HStack {
                Text(L10n.string(.filter))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $filter) {
                    Text(L10n.string(.all)).tag(nil as LaunchAgent.Category?)
                    ForEach([LaunchAgent.Category.system, .microsoft, .adobe, .google, .thirdParty], id: \.self) { cat in
                        Text(cat.rawValue).tag(cat as LaunchAgent.Category?)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            Divider()
            
            // List
            if filteredAgents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(L10n.string(.noStartupItems))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedAgent) {
                    ForEach(filteredAgents) { agent in
                        AgentRow(agent: agent)
                            .tag(agent)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        VStack(spacing: 0) {
            if let agent = selectedAgent {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(agent.label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Category badge
                    Text(agent.category.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor(agent.category).opacity(0.2))
                        .foregroundColor(categoryColor(agent.category))
                        .cornerRadius(8)
                }
                .padding()
                
                Divider()
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    // Status indicators
                    HStack(spacing: 20) {
                        StatusBadge(
                            title: "Run at Load",
                            isActive: agent.runAtLoad,
                            activeColor: .green
                        )
                        
                        StatusBadge(
                            title: "Keep Alive",
                            isActive: agent.keepAlive,
                            activeColor: .blue
                        )
                        
                        StatusBadge(
                            title: "Status",
                            isActive: !agent.isDisabled,
                            activeText: "Enabled",
                            inactiveText: "Disabled",
                            activeColor: .green
                        )
                        
                        StatusBadge(
                            title: "Level",
                            isActive: agent.isUserLevel,
                            activeText: "User",
                            inactiveText: "System",
                            activeColor: .purple
                        )
                    }
                    
                    Divider()
                    
                    // Program
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string(.program))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(agent.program.isEmpty ? "Not specified" : agent.program)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                    }
                    
                    // Path
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string(.plistLocation))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(agent.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
                
                Spacer()
                
                // Actions
                HStack {
                    Button(action: { startupManager.revealInFinder(agent) }) {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { startupManager.openInEditor(agent) }) {
                        Label("Open Plist", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    if agent.isUserLevel {
                        Button(role: .destructive, action: { showRemoveConfirmation = true }) {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .confirmationDialog("Remove \(agent.displayName)?", isPresented: $showRemoveConfirmation) {
                    Button("Move to Trash", role: .destructive) {
                        Task {
                            _ = await startupManager.removeLaunchAgent(agent)
                            selectedAgent = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(L10n.string(.removeLaunchAgentWarning))
                }
                
            } else {
                // No selection
                VStack(spacing: 16) {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(L10n.string(.selectStartupItem))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.string(.viewDetailsManage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 250)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func categoryColor(_ category: LaunchAgent.Category) -> Color {
        switch category {
        case .system: return .gray
        case .microsoft: return .blue
        case .adobe: return .red
        case .google: return .green
        case .thirdParty: return .purple
        }
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    let agent: LaunchAgent
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(agent.isDisabled ? Color.gray : Color.green)
                .frame(width: 8, height: 8)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .lineLimit(1)
                
                HStack {
                    Text(agent.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if agent.runAtLoad {
                        Text(L10n.string(.autoStart))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // User/System badge
            Text(agent.isUserLevel ? "User" : "System")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(agent.isUserLevel ? Color.purple.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(agent.isUserLevel ? .purple : .gray)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let title: String
    let isActive: Bool
    var activeText: String = "Yes"
    var inactiveText: String = "No"
    var activeColor: Color = .green
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(isActive ? activeText : inactiveText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isActive ? activeColor : .gray)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    StartupManagerTab()
        .frame(width: 800, height: 600)
}
