import SwiftUI

/// Cleanup Widget - Quick disk cleanup actions from menu bar
struct CleanupWidgetView: View {
    @StateObject private var cleanup = DiskCleanup()
    @StateObject private var largeFiles = LargeFilesScanner.shared
    @State private var isScanning = false
    @State private var showCleanConfirm = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient
            ZStack {
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 8) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    
                    Text("Smart Cleanup")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if cleanup.isScanning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else if cleanup.totalCleanableSize > 0 {
                        Text(cleanup.totalCleanableSize.formattedSize)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("can be freed")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.vertical, 20)
            }
            .frame(height: 140)
            
            VStack(spacing: 12) {
                // Quick stats
                if !cleanup.scanResults.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(cleanup.scanResults.prefix(4)) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(.orange)
                                    .frame(width: 20)
                                
                                Text(L10n.rawString(category.localizedKey))
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text(category.size.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if cleanup.scanResults.count > 4 {
                            Text("+ \(cleanup.scanResults.count - 4) more categories")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 12)
                }
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: {
                        Task { await cleanup.scan() }
                    }) {
                        Label("Scan", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(cleanup.isScanning)
                    
                    Button(action: {
                        showCleanConfirm = true
                    }) {
                        Label("Clean", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(cleanup.totalCleanableSize == 0 || cleanup.isScanning)
                }
                
                // Open full cleanup
                Button(action: {
                    StatusBarController.shared.openDashboard()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("NavigateToTab"), object: "cleanup")
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("Open Full Cleanup")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            // Small delay to ensure view appears first
            try? await Task.sleep(nanoseconds: 300_000_000)
            await cleanup.scan()
        }
        .alert("Clean Disk", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    let selected = cleanup.scanResults.filter { $0.isSelected }
                    _ = await cleanup.clean(categories: selected)
                }
            }
        } message: {
            Text("Delete \(cleanup.totalCleanableSize.formattedSize) of junk files?")
        }
    }
}

#Preview {
    CleanupWidgetView()
}
