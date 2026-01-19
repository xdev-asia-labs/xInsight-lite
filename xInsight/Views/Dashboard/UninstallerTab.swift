import SwiftUI

/// Uninstaller Tab - Clean uninstall applications with all related files
struct UninstallerTab: View {
    @StateObject private var uninstaller = AppUninstaller.shared
    @State private var searchText = ""
    @State private var showConfirmation = false
    @State private var uninstallResult: (success: Bool, errors: [String])?
    
    var filteredApps: [InstalledApp] {
        if searchText.isEmpty {
            return uninstaller.installedApps
        }
        return uninstaller.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        HSplitView {
            // Left: App List
            appListView
                .frame(minWidth: 280, maxWidth: 350)
            
            // Right: App Details & Files
            detailView
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await uninstaller.scanInstalledApps()
        }
        .alert("Uninstall Complete", isPresented: .init(
            get: { uninstallResult != nil },
            set: { if !$0 { uninstallResult = nil } }
        )) {
            Button("OK") { uninstallResult = nil }
        } message: {
            if let result = uninstallResult {
                if result.success {
                    Text(L10n.string(.appMovedToTrash))
                } else {
                    Text(L10n.string(.errorsOccurred) + "\n" + result.errors.joined(separator: "\n"))
                }
            }
        }
    }
    
    // MARK: - App List
    
    private var appListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.string(.installedApps))
                    .font(.headline)
                Spacer()
                if uninstaller.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(String(format: L10n.string(.numberOnly), uninstaller.installedApps.count))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredApps) { app in
                        AppRow(
                            app: app,
                            isSelected: uninstaller.selectedApp?.id == app.id
                        ) {
                            Task {
                                await uninstaller.findRelatedFiles(for: app)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        VStack(spacing: 0) {
            if let app = uninstaller.selectedApp {
                // App Header
                HStack(spacing: 16) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name.replacingOccurrences(of: ".app", with: ""))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let version = app.version {
                            Text(String(format: L10n.string(.versionPrefix), version))
                                .foregroundColor(.secondary)
                        }
                        
                        if let bundleId = app.bundleIdentifier {
                            Text(bundleId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(formatBytes(app.size))
                            .font(.headline)
                        Text(L10n.string(.appSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                
                Divider()
                
                // Related Files
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L10n.string(.relatedFiles))
                            .font(.headline)
                        
                        Spacer()
                        
                        if uninstaller.isFindingFiles {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(L10n.string(.scanningDots))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(String(format: L10n.string(.filesCount), uninstaller.relatedFiles.count))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if uninstaller.relatedFiles.isEmpty && !uninstaller.isFindingFiles {
                        Text(L10n.string(.noRelatedFiles))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(uninstaller.relatedFiles) { file in
                                    FileRow(file: file) {
                                        uninstaller.toggleFile(file)
                                    } reveal: {
                                        uninstaller.revealInFinder(file.path)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Footer
                HStack {
                    VStack(alignment: .leading) {
                        Text(L10n.string(.totalToRemove))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatBytes(app.size + uninstaller.totalSelectedSize))
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button(action: { uninstaller.revealInFinder(app.path) }) {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showConfirmation = true }) {
                        Label("Uninstall", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .confirmationDialog(
                    "Uninstall \(app.name)?",
                    isPresented: $showConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Move to Trash", role: .destructive) {
                        Task {
                            uninstallResult = await uninstaller.uninstall()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(String(format: L10n.string(.willBeMovedToTrash), uninstaller.relatedFiles.filter { $0.isSelected }.count))
                }
                
            } else {
                // No selection
                VStack(spacing: 16) {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text(L10n.string(.selectAnApp))
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.string(.findAllRelatedFiles))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - App Row

struct AppRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name.replacingOccurrences(of: ".app", with: ""))
                        .lineLimit(1)
                    Text(formatBytes(app.size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

// MARK: - File Row

struct FileRow: View {
    let file: RelatedFile
    let toggle: () -> Void
    let reveal: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: file.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(file.isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            Image(systemName: file.type.icon)
                .foregroundColor(colorFromString(file.type.color))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .lineLimit(1)
                Text(file.location)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatBytes(file.size))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            Button(action: reveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
    
    private func colorFromString(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "green": return .green
        case "gray": return .gray
        case "cyan": return .cyan
        default: return .secondary
        }
    }
}

#Preview {
    UninstallerTab()
        .frame(width: 800, height: 600)
}
