import SwiftUI

/// Command Bar - Natural Language Query Interface
struct CommandBar: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: DashboardTab
    @State private var query: String = ""
    @State private var suggestions: [QueryParser.QueryResult] = []
    @State private var selectedIndex: Int = 0
    @State private var recentQueries: [String] = []
    
    private let parser = QueryParser()
    private let maxRecentQueries = 5
    
    var body: some View {
        ZStack {
            // Backdrop
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }
                
                // Command bar
                VStack(spacing: 0) {
                    commandInput
                    
                    if !suggestions.isEmpty || (!query.isEmpty && suggestions.isEmpty) {
                        suggestionsList
                    } else if query.isEmpty && !recentQueries.isEmpty {
                        recentQueriesList
                    }
                }
                .frame(width: 600)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.top, 100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isPresented)
        .onAppear {
            loadRecentQueries()
        }
    }
    
    // MARK: - Command Input
    
    private var commandInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "command")
                .font(.title2)
                .foregroundColor(.secondary)
            
            TextField("Type a command...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .onSubmit {
                    executeQuery()
                }
                .onChange(of: query) { _, newValue in
                    updateSuggestions(newValue)
                }
            
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Suggestions List
    
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            Divider()
            
            ScrollView {
                VStack(spacing: 0) {
                    if suggestions.isEmpty {
                        noResultsView
                    } else {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, result in
                            SuggestionRow(
                                result: result,
                                isSelected: index == selectedIndex
                            )
                            .onTapGesture {
                                executeResult(result)
                            }
                            
                            if index < suggestions.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundColor(.secondary)
            
            Text(L10n.string(.noMatchingCommands))
                .foregroundColor(.secondary)
            
            Text(L10n.string(.tryCommands))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Recent Queries
    
    private var recentQueriesList: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Text(L10n.string(.recent))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            
            ForEach(recentQueries, id: \.self) { recentQuery in
                Button(action: {
                    query = recentQuery
                    updateSuggestions(recentQuery)
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.secondary)
                        Text(recentQuery)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Divider()
            }
        }
    }
    
    // MARK: - Actions
    
    private func updateSuggestions(_ query: String) {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        
        let result = parser.parse(query)
        suggestions = [result]
        selectedIndex = 0
    }
    
    private func executeQuery() {
        guard !query.isEmpty else { return }
        
        let result = parser.parse(query)
        executeResult(result)
    }
    
    private func executeResult(_ result: QueryParser.QueryResult) {
        // Save to recent queries
        saveRecentQuery(result.originalQuery)
        
        // Execute action
        switch result.action {
        case .navigate(let tab):
            selectedTab = tab
            isPresented = false
            
        case .showProcesses(_):
            selectedTab = .processes
            // TODO: Set sort order
            isPresented = false
            
        case .killProcess(_):
            // Navigate to processes tab
            selectedTab = .processes
            // TODO: Filter by process name
            isPresented = false
            
        case .showInsights(_):
            selectedTab = .insights
            // TODO: Filter by severity
            isPresented = false
            
        case .executeCommand(let command):
            executeCommand(command)
            isPresented = false
            
        case .unknown:
            // Show error or keep bar open
            break
        }
        
        query = ""
        suggestions = []
    }
    
    private func executeCommand(_ command: QueryParser.QueryResult.Command) {
        switch command {
        case .cleanDisk:
            selectedTab = .cleanup
        case .scanSecurity:
            selectedTab = .security
        case .checkBattery:
            selectedTab = .batteryHealth
        case .uninstallApp:
            selectedTab = .uninstaller
        case .manageStartup:
            selectedTab = .startupManager
        }
    }
    
    // MARK: - Recent Queries Storage
    
    private func loadRecentQueries() {
        if let saved = UserDefaults.standard.stringArray(forKey: "RecentQueries") {
            recentQueries = saved
        }
    }
    
    private func saveRecentQuery(_ query: String) {
        // Remove if already exists
        recentQueries.removeAll { $0 == query }
        
        // Add to front
        recentQueries.insert(query, at: 0)
        
        // Limit size
        if recentQueries.count > maxRecentQueries {
            recentQueries = Array(recentQueries.prefix(maxRecentQueries))
        }
        
        // Save
        UserDefaults.standard.set(recentQueries, forKey: "RecentQueries")
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let result: QueryParser.QueryResult
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(actionDescription)
                    .fontWeight(.medium)
                
                if let suggestion = result.suggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Confidence indicator
            if result.confidence > 0.7 {
                HStack(spacing: 4) {
                    ForEach(0..<Int(result.confidence * 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            
            // Keyboard hint
            Image(systemName: "return")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
    
    private var iconName: String {
        switch result.action {
        case .navigate: return "arrow.right.circle"
        case .showProcesses: return "list.bullet"
        case .killProcess: return "xmark.circle"
        case .showInsights: return "lightbulb"
        case .executeCommand: return "play.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch result.action {
        case .navigate: return .blue
        case .showProcesses: return .purple
        case .killProcess: return .red
        case .showInsights: return .yellow
        case .executeCommand: return .green
        case .unknown: return .gray
        }
    }
    
    private var actionDescription: String {
        switch result.action {
        case .navigate(let tab):
            return "Navigate to \(tab.displayName)"
        case .showProcesses(let sortBy):
            return "Show top \(sortBy) processes"
        case .killProcess(let name):
            return "Kill process: \(name)"
        case .showInsights(let severity):
            if let severity = severity {
                return "Show \(severity.rawValue) insights"
            }
            return "Show all insights"
        case .executeCommand(let command):
            return commandDescription(command)
        case .unknown:
            return "No matching command"
        }
    }
    
    private func commandDescription(_ command: QueryParser.QueryResult.Command) -> String {
        switch command {
        case .cleanDisk: return "Clean disk space"
        case .scanSecurity: return "Scan security settings"
        case .checkBattery: return "Check battery health"
        case .uninstallApp: return "Uninstall applications"
        case .manageStartup: return "Manage startup items"
        }
    }
}

#Preview {
    CommandBar(
        isPresented: .constant(true),
        selectedTab: .constant(.overview)
    )
}
