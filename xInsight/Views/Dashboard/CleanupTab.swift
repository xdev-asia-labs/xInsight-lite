import SwiftUI

/// Disk Cleanup Tab - Quét và dọn dẹp disk
struct CleanupTab: View {
    @StateObject private var cleanup = DiskCleanup()
    @StateObject private var largeFiles = LargeFilesScanner.shared
    @State private var showCleanConfirmation = false
    @State private var cleaningResult: (cleaned: UInt64, errors: [String])?
    @State private var showResult = false
    @State private var selectedMode: CleanupMode = .diskCleanup
    @State private var showLargeFilesDeleteConfirm = false
    @State private var largeFilesDeleteResult: (deleted: Int, errors: [String])?
    
    enum CleanupMode: String, CaseIterable {
        case diskCleanup = "Disk Cleanup"
        case largeFiles = "Large Files"
        
        var localizedName: String {
            switch self {
            case .diskCleanup: return L10n.rawString("cleanup")
            case .largeFiles: return L10n.rawString("largeFiles")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Picker
            Picker("Mode", selection: $selectedMode) {
                ForEach(CleanupMode.allCases, id: \.self) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            Divider()
            
            switch selectedMode {
            case .diskCleanup:
                diskCleanupView
            case .largeFiles:
                largeFilesView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await cleanup.scan()
        }
        .alert("Clean Disk", isPresented: $showCleanConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    let selected = cleanup.scanResults.filter { $0.isSelected }
                    cleaningResult = await cleanup.clean(categories: selected)
                    showResult = true
                }
            }
        } message: {
            Text(String(format: L10n.string(.deleteConfirm), cleanup.totalCleanableSize.formattedSize))
        }
        .alert("Cleanup Complete", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            if let result = cleaningResult {
                if result.errors.isEmpty {
                    Text(String(format: L10n.string(.successfullyFreed), result.cleaned.formattedSize))
                } else {
                    Text(String(format: L10n.string(.freedWithErrors), result.cleaned.formattedSize, result.errors.count))
                }
            }
        }
        .alert("Delete Large Files", isPresented: $showLargeFilesDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    largeFilesDeleteResult = await largeFiles.deleteSelected()
                }
            }
        } message: {
            Text(String(format: L10n.string(.deleteConfirm), largeFiles.totalSelectedSize.formattedSize))
        }
    }
    
    // MARK: - Disk Cleanup View
    
    private var diskCleanupView: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            if cleanup.isScanning {
                scanningView
            } else if cleanup.scanResults.isEmpty {
                emptyView
            } else {
                resultsView
            }
        }
    }
    
    // MARK: - Large Files View
    
    private var largeFilesView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(L10n.rawString("largeFilesScanner"))
                        .font(.headline)
                    
                    Text(L10n.rawString("findLargeFiles"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if largeFiles.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(action: { Task { await largeFiles.scan() }}) {
                    Label(L10n.string(.rescan), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(largeFiles.isScanning)
                
                if !largeFiles.selectedFiles.isEmpty {
                    Button(action: { showLargeFilesDeleteConfirm = true }) {
                        Label(L10n.string(.clean), systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
            
            Divider()
            
            if largeFiles.isScanning {
                VStack(spacing: 16) {
                    ProgressView(value: largeFiles.scanProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                    
                    Text(L10n.string(.scanning))
                        .font(.headline)
                    
                    Text(largeFiles.currentPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if largeFiles.scanResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text(L10n.rawString("noLargeFiles"))
                        .font(.headline)
                    
                    Button(L10n.string(.rescan)) {
                        Task { await largeFiles.scan() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Results
                VStack(spacing: 0) {
                    // Selection bar
                    HStack {
                        Text("\(largeFiles.scanResults.count) \(L10n.string(.filesFound))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Select All") { largeFiles.selectAll() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        
                        Button("Deselect All") { largeFiles.deselectAll() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        
                        if largeFiles.totalSelectedSize > 0 {
                            Text(largeFiles.totalSelectedSize.formattedSize)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    
                    // File list
                    List {
                        ForEach(largeFiles.scanResults) { file in
                            LargeFileRow(file: file) {
                                largeFiles.toggleSelection(file)
                            } onReveal: {
                                largeFiles.revealInFinder(file)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(L10n.string(.cleanup))
                    .font(.headline)
                
                if !cleanup.scanResults.isEmpty {
                    Text(String(format: L10n.string(.canBeFreed), cleanup.totalCleanableSize.formattedSize))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { Task { await cleanup.scan() }}) {
                Label(L10n.string(.rescan), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            
            if !cleanup.scanResults.isEmpty && cleanup.totalCleanableSize > 0 {
                Button(action: { showCleanConfirmation = true }) {
                    Label(L10n.string(.clean), systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(L10n.string(.scanning))
                .font(.headline)
            
            Text(L10n.string(.thisMayTakeAMoment))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text(L10n.string(.diskIsClean))
                .font(.headline)
            
            Text(L10n.string(.noSignificantJunkFiles))
                .foregroundColor(.secondary)
            
            Button("Scan Again") {
                Task { await cleanup.scan() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        List {
            ForEach(cleanup.scanResults) { category in
                CleanupCategoryRow(
                    category: category,
                    onToggle: { cleanup.toggleCategory(category) }
                )
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Category Row

struct CleanupCategoryRow: View {
    let category: DiskCleanup.CleanupCategory
    let onToggle: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Checkbox
                Toggle("", isOn: Binding(
                    get: { category.isSelected },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.checkbox)
                
                // Icon
                Image(systemName: category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                // Name and size
                VStack(alignment: .leading) {
                    Text(L10n.rawString(category.localizedKey))
                        .fontWeight(.medium)
                    
                    Text(category.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Size
                Text(category.size.formattedSize)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(sizeColor(for: category.size))
                
                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            
            // Expanded file list
            if isExpanded && !category.files.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(category.files.prefix(20)) { file in
                        HStack {
                            Text(file.name)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(file.size.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 32)
                    }
                    
                    if category.files.count > 20 {
                        Text(String(format: L10n.string(.andMoreFilesCategory), category.files.count - 20))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func sizeColor(for size: UInt64) -> Color {
        if size > 1_000_000_000 { // > 1GB
            return .red
        } else if size > 100_000_000 { // > 100MB
            return .orange
        }
        return .primary
    }
}

// MARK: - Large File Row

struct LargeFileRow: View {
    let file: LargeFilesScanner.LargeFile
    let onToggle: () -> Void
    let onReveal: () -> Void
    
    var body: some View {
        HStack {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { file.isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            
            // Icon
            Image(systemName: file.fileType.icon)
                .foregroundColor(fileTypeColor)
                .frame(width: 24)
            
            // Name
            VStack(alignment: .leading) {
                Text(file.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(file.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Date
            Text(file.modifiedDate, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Size
            Text(file.size.formattedSize)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(sizeColor)
            
            // Reveal button
            Button(action: onReveal) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    private var fileTypeColor: Color {
        switch file.fileType {
        case .video: return .purple
        case .archive: return .orange
        case .diskImage: return .blue
        case .application: return .green
        case .other: return .gray
        }
    }
    
    private var sizeColor: Color {
        if file.size > 1_000_000_000 { // > 1GB
            return .red
        } else if file.size > 500_000_000 { // > 500MB
            return .orange
        }
        return .primary
    }
}

#Preview {
    CleanupTab()
        .frame(width: 600, height: 500)
}
