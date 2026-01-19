import SwiftUI

/// Security Tab - Check system security status and scan for issues
struct SecurityTab: View {
    @StateObject private var scanner = SecurityScanner.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                
                // Overall Score
                scoreSection
                
                // Security Checks
                checksSection
                
                // Suspicious Items
                if !scanner.suspiciousItems.isEmpty {
                    suspiciousSection
                }
                
                // Recommendations
                recommendationsSection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.string(.security))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(L10n.string(.appDescription))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { Task { await scanner.scan() } }) {
                Label(scanner.isScanning ? "Scanning..." : "Rescan", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(scanner.isScanning)
        }
    }
    
    // MARK: - Score Section
    
    private var scoreSection: some View {
        HStack(spacing: 40) {
            // Score gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: Double(scanner.securityStatus.overallScore) / 100)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 15, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(String(format: L10n.string(.numberOnly), scanner.securityStatus.overallScore))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text(L10n.string(.ofHundred))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status info
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(scoreColor)
                        .frame(width: 12, height: 12)
                    Text(scanner.securityStatus.overallStatus)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text(scanner.securityStatus.overallScore < 100 
                    ? String(format: L10n.string(.securitySettingsNeedsWork), scanner.securityStatus.overallStatus.lowercased())
                    : String(format: L10n.string(.securitySettingsGood), scanner.securityStatus.overallStatus.lowercased()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 300)
                
                Button(action: { scanner.openSecurityPreferences() }) {
                    Label(L10n.string(.openSecuritySettings), systemImage: "gear")
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var scoreColor: Color {
        switch scanner.securityStatus.overallColor {
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        default: return .red
        }
    }
    
    // MARK: - Checks Section
    
    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.securityChecks))
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SecurityCheckCard(
                    title: "System Integrity Protection",
                    subtitle: "Protects system files from modification",
                    isEnabled: scanner.securityStatus.sipEnabled,
                    icon: "shield.checkered"
                )
                
                SecurityCheckCard(
                    title: "Gatekeeper",
                    subtitle: "Blocks unverified apps from running",
                    isEnabled: scanner.securityStatus.gatekeeperEnabled,
                    icon: "hand.raised"
                )
                
                SecurityCheckCard(
                    title: "FileVault",
                    subtitle: "Encrypts your startup disk",
                    isEnabled: scanner.securityStatus.fileVaultEnabled,
                    icon: "lock.shield"
                )
                
                SecurityCheckCard(
                    title: "Firewall",
                    subtitle: "Blocks unwanted incoming connections",
                    isEnabled: scanner.securityStatus.firewallEnabled,
                    icon: "flame"
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Suspicious Section
    
    private var suspiciousSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(L10n.string(.suspiciousItemsFound))
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: L10n.string(.itemsCountShort), scanner.suspiciousItems.count))
                    .foregroundColor(.secondary)
            }
            
            ForEach(scanner.suspiciousItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(item.severity == .critical ? .red : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .fontWeight(.medium)
                        Text(item.reason)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { scanner.revealInFinder(item) }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Recommendations
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.recommendations))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if !scanner.securityStatus.fileVaultEnabled {
                    RecommendationRow(
                        icon: "lock.shield",
                        text: "Enable FileVault disk encryption in System Preferences → Privacy & Security",
                        priority: .high
                    )
                }
                
                if !scanner.securityStatus.firewallEnabled {
                    RecommendationRow(
                        icon: "flame",
                        text: "Enable Firewall in System Preferences → Network",
                        priority: .medium
                    )
                }
                
                RecommendationRow(
                    icon: "arrow.clockwise",
                    text: "Keep macOS and apps updated to patch security vulnerabilities",
                    priority: .low
                )
                
                RecommendationRow(
                    icon: "key",
                    text: "Use strong, unique passwords and enable two-factor authentication",
                    priority: .low
                )
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Security Check Card

struct SecurityCheckCard: View {
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isEnabled ? .green : .orange)
                .frame(width: 40, height: 40)
                .background(isEnabled ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(isEnabled ? "On" : "Off")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isEnabled ? .green : .orange)
                }
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Recommendation Row

struct RecommendationRow: View {
    let icon: String
    let text: String
    let priority: Priority
    
    enum Priority {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)
            
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    SecurityTab()
        .frame(width: 700, height: 800)
}
