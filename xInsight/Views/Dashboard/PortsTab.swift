import SwiftUI

/// Ports management tab
struct PortsTab: View {
    @ObservedObject private var portMonitor = PortMonitoringService.shared
    @State private var selectedPort: PortInfo?
    @State private var showStopConfirmation = false
    @State private var isManualRefreshing = false
    
    var body: some View {
        HSplitView {
            // Active Ports List
            portsListView
                .frame(minWidth: 400)
            
            // Port Details / Recent Changes
            detailView
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Manual Refresh
    
    private func manualRefresh() {
        guard !isManualRefreshing else { return }
        isManualRefreshing = true
        Task {
            await portMonitor.rescan()
            isManualRefreshing = false
        }
    }
    
    // MARK: - Ports List
    
    private var portsListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L10n.string(.ports))
                    .font(.headline)
                
                Spacer()
                
                if isManualRefreshing {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(String(format: L10n.string(.portsCount), portMonitor.activePorts.count))
                        .foregroundColor(.secondary)
                }
                
                Button(action: { manualRefresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(isManualRefreshing)
            }
            .padding()
            
            Divider()
            
            if portMonitor.activePorts.isEmpty && portMonitor.lastScanTime == nil {
                ProgressView("Scanning ports...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if portMonitor.activePorts.isEmpty {
                emptyPortsView
            } else {
                List(selection: $selectedPort) {
                    ForEach(portMonitor.activePorts) { portInfo in
                        PortRow(portInfo: portInfo, onStop: {
                            selectedPort = portInfo
                            showStopConfirmation = true
                        })
                        .tag(portInfo)
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Stop Port?",
            isPresented: $showStopConfirmation,
            titleVisibility: .visible
        ) {
            if let port = selectedPort {
                Button("Stop \(port.processName) on port \(port.port)", role: .destructive) {
                    stopPort(port)
                }
                Button("Cancel", role: .cancel) {}
            }
        } message: {
            if let port = selectedPort {
                Text(String(format: L10n.string(.terminateProcess), port.processName, port.pid))
            }
        }
    }
    
    private var emptyPortsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L10n.string(.noActivePorts))
                .font(.headline)
            
            Text(L10n.string(.noServicesListening))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        VStack(spacing: 0) {
            // Recent changes
            HStack {
                Text(L10n.string(.portDetails))
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            Divider()
            
            if let port = selectedPort {
                portDetailView(port)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "network")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    
                    Text(L10n.string(.selectPortToView))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func portDetailView(_ port: PortInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Port info card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(format: L10n.string(.portFormat), port.port))
                        .font(.system(.largeTitle, design: .monospaced))
                        .fontWeight(.bold)
                    
                    if let desc = port.commonDescription {
                        Text(desc)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                LabeledContent("Process", value: port.processName)
                LabeledContent("PID", value: "\(port.pid)")
                LabeledContent("Address", value: port.localAddress)
                LabeledContent("Protocol", value: port.protocol_)
                LabeledContent("State", value: port.state.rawValue)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(12)
            
            // Actions
            HStack {
                Button(role: .destructive, action: { stopPort(port) }) {
                    Label(L10n.string(.stopPort), systemImage: "stop.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func stopPort(_ port: PortInfo) {
        portMonitor.killPort(port) { success in
            if success {
                selectedPort = nil
            }
        }
    }
}

// MARK: - Simple Port Change Info
struct PortChangeInfo: Identifiable {
    let id = UUID()
    let port: UInt16
    let processName: String
    let isStarted: Bool
    let timestamp: Date
}

// MARK: - Port Row

struct PortRow: View {
    let portInfo: PortInfo
    let onStop: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Port indicator
            Circle()
                .fill(stateColor)
                .frame(width: 10, height: 10)
            
            // Port info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    // Port without locale formatting
                    Text(String(format: L10n.string(.addressPortFormat), portInfo.localAddress, portInfo.port))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                    
                    if let desc = portInfo.commonDescription {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text(portInfo.processName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: L10n.string(.pidFormat), portInfo.pid))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Stop button (visible on hover)
            if isHovering {
                Button(action: onStop) {
                    Image(systemName: "stop.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Stop this port")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private var stateColor: Color {
        switch portInfo.state {
        case .listen: return .green
        case .established: return .blue
        case .timeWait: return .yellow
        case .closeWait: return .orange
        case .unknown: return .gray
        }
    }
}

#Preview {
    PortsTab()
        .frame(width: 800, height: 500)
}
