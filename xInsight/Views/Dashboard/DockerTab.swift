import SwiftUI

/// Docker Tab - Container and Image Management
struct DockerTab: View {
    @StateObject private var docker = DockerMonitor.shared
    @State private var selectedTab = 0
    @State private var selectedContainer: Container?
    @State private var showingLogs = false
    @State private var containerLogs = ""
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            if !docker.isDockerInstalled {
                dockerNotInstalledView
            } else if !docker.isDockerRunning {
                dockerNotRunningView
            } else {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Containers (\(docker.containers.count))").tag(0)
                    Text("Images (\(docker.images.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if selectedTab == 0 {
                    containersList
                } else {
                    imagesList
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            docker.checkDockerStatus()
            docker.startAutoRefresh()
        }
        .onDisappear {
            docker.stopAutoRefresh()
        }
        .sheet(isPresented: $showingLogs) {
            logsSheet
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Docker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Text("Container and image management")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status
            HStack(spacing: 16) {
                if docker.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(docker.isDockerRunning ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(docker.isDockerRunning ? "Running" : "Stopped")
                            .font(.caption)
                    }
                    Text("\(docker.containers.filter { $0.isRunning }.count) active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button {
                    Task { await docker.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    // MARK: - Not Installed View
    
    private var dockerNotInstalledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Docker Not Installed")
                .font(.title2.bold())
            
            Text("Install Docker Desktop to manage containers")
                .foregroundColor(.secondary)
            
            Button("Download Docker Desktop") {
                NSWorkspace.shared.open(URL(string: "https://www.docker.com/products/docker-desktop/")!)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Not Running View
    
    private var dockerNotRunningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "power.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Docker Not Running")
                .font(.title2.bold())
            
            Text("Start Docker Desktop to manage containers")
                .foregroundColor(.secondary)
            
            Button("Open Docker Desktop") {
                NSWorkspace.shared.open(URL(string: "docker://")!)
            }
            .buttonStyle(.borderedProminent)
            
            Button("Refresh Status") {
                docker.checkDockerStatus()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Containers List
    
    private var containersList: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search containers...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // List
            List {
                ForEach(filteredContainers) { container in
                    ContainerRow(container: container) {
                        // Start/Stop
                        if container.isRunning {
                            Task { await docker.stopContainer(container) }
                        } else {
                            Task { await docker.startContainer(container) }
                        }
                    } onRestart: {
                        Task { await docker.restartContainer(container) }
                    } onLogs: {
                        selectedContainer = container
                        Task {
                            containerLogs = await docker.getContainerLogs(container)
                            showingLogs = true
                        }
                    } onRemove: {
                        Task { await docker.removeContainer(container) }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
    
    private var filteredContainers: [Container] {
        if searchText.isEmpty {
            return docker.containers
        }
        return docker.containers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.image.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Images List
    
    private var imagesList: some View {
        VStack(spacing: 0) {
            // Actions
            HStack {
                Spacer()
                
                Button {
                    Task { _ = await docker.pruneSystem() }
                } label: {
                    Label("Prune", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // List
            List {
                ForEach(docker.images) { image in
                    ImageRow(image: image) {
                        Task { await docker.removeImage(image) }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
    
    // MARK: - Logs Sheet
    
    private var logsSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Logs: \(selectedContainer?.name ?? "")")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    showingLogs = false
                }
            }
            .padding()
            
            ScrollView {
                Text(containerLogs)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - Container Row

struct ContainerRow: View {
    let container: Container
    let onToggle: () -> Void
    let onRestart: () -> Void
    let onLogs: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(container.isRunning ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(container.name)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(container.image)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !container.ports.isEmpty {
                        Text(container.ports)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Status
            Text(container.status)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Actions
            HStack(spacing: 4) {
                Button {
                    onToggle()
                } label: {
                    Image(systemName: container.isRunning ? "stop.fill" : "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(container.isRunning ? .red : .green)
                
                Button {
                    onRestart()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(!container.isRunning)
                
                Button {
                    onLogs()
                } label: {
                    Image(systemName: "doc.text")
                }
                .buttonStyle(.bordered)
                
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Image Row

struct ImageRow: View {
    let image: DockerImage
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(image.fullName)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(image.id.prefix(12))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(image.created)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(image.size)
                .font(.caption)
                .foregroundColor(.orange)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DockerTab()
        .frame(width: 800, height: 600)
}
