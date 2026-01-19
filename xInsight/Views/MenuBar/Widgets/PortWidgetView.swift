import SwiftUI

/// Compact Port widget for menu bar
struct PortWidgetView: View {
    @State private var ports: [PortInfo] = []
    @State private var isScanning = false
    @State private var selectedPort: PortInfo?
    @State private var showKillConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cable.connector")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Ports")
                    .font(.headline)
                Spacer()
                
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button(action: { Task { await scanPorts() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            if isScanning {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning ports...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else if ports.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No open ports")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(ports.prefix(10)) { port in
                            PortRowView(port: port) {
                                selectedPort = port
                                showKillConfirmation = true
                            }
                        }
                        
                        if ports.count > 10 {
                            Text("+ \(ports.count - 10) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // Summary
            HStack {
                Text("\(ports.count) active ports")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task { await scanPorts() }
        }
        .alert("Kill Port", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Kill", role: .destructive) {
                if let port = selectedPort {
                    killPort(port)
                }
            }
        } message: {
            if let port = selectedPort {
                Text("Kill process \"\(port.processName)\" (PID: \(port.pid)) listening on port \(port.port)?")
            }
        }
    }
    
    private func scanPorts() async {
        isScanning = true
        ports = await PortScanner.getListeningPorts()
        isScanning = false
    }
    
    @MainActor
    private func killPort(_ port: PortInfo) {
        PortMonitoringService.shared.killPort(port) { success in
            if success {
                print("✅ Successfully killed port \(port.port)")
            } else {
                print("❌ Failed to kill port \(port.port)")
            }
        }
        // Rescan after kill
        Task { await scanPorts() }
    }
}

/// Individual port row with kill button
struct PortRowView: View {
    let port: PortInfo
    let onKill: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
            
            Text(":\(port.port)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
            
            if let desc = port.commonDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isHovering {
                Button(action: onKill) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Kill port \(port.port)")
            } else {
                Text(port.processName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isHovering ? Color.red.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
