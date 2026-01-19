import SwiftUI

/// Toast notification item
struct ToastNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let type: ToastType
    let timestamp: Date
    
    enum ToastType {
        case portStart
        case portStop
        case portKill
        case warning
        case info
        case success
        
        var icon: String {
            switch self {
            case .portStart: return "play.circle.fill"
            case .portStop: return "stop.circle.fill"
            case .portKill: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .portStart: return .green
            case .portStop: return .red
            case .portKill: return .orange
            case .warning: return .orange
            case .info: return .blue
            case .success: return .green
            }
        }
    }
    
    static func == (lhs: ToastNotification, rhs: ToastNotification) -> Bool {
        lhs.id == rhs.id
    }
}

/// In-app toast notification manager
@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var notifications: [ToastNotification] = []
    @Published var currentNotification: ToastNotification?
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    func show(_ notification: ToastNotification) {
        // Add to history
        notifications.insert(notification, at: 0)
        
        // Keep only last 50
        if notifications.count > 50 {
            notifications = Array(notifications.prefix(50))
        }
        
        // Show current notification
        currentNotification = notification
        
        // Auto dismiss after 4 seconds
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    currentNotification = nil
                }
            }
        }
    }
    
    func showPortStarted(port: UInt16, process: String, description: String?) {
        let desc = description ?? "Unknown service"
        show(ToastNotification(
            title: "🟢 Port Started",
            message: "Port \(port) (\(desc)) opened by \(process)",
            type: .portStart,
            timestamp: Date()
        ))
    }
    
    func showPortStopped(port: UInt16) {
        show(ToastNotification(
            title: "🔴 Port Stopped",
            message: "Port \(port) is no longer listening",
            type: .portStop,
            timestamp: Date()
        ))
    }
    
    func showPortKilled(port: UInt16, process: String) {
        show(ToastNotification(
            title: "⚡ Port Killed",
            message: "Killed \(process) on port \(port)",
            type: .portKill,
            timestamp: Date()
        ))
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) {
            currentNotification = nil
        }
    }
}

/// Toast notification banner view
struct ToastBannerView: View {
    @ObservedObject var manager = ToastManager.shared
    
    var body: some View {
        VStack {
            if let notification = manager.currentNotification {
                HStack(spacing: 12) {
                    Image(systemName: notification.type.icon)
                        .font(.title2)
                        .foregroundColor(notification.type.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(notification.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: { manager.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(notification.type.color.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.currentNotification)
    }
}

/// Notification history panel
struct NotificationHistoryView: View {
    @ObservedObject var manager = ToastManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Notifications")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    manager.notifications.removeAll()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            if manager.notifications.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent notifications")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(manager.notifications) { notification in
                            HStack(spacing: 8) {
                                Image(systemName: notification.type.icon)
                                    .foregroundColor(notification.type.color)
                                    .font(.caption)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(notification.title.replacingOccurrences(of: "🟢 ", with: "").replacingOccurrences(of: "🔴 ", with: "").replacingOccurrences(of: "⚡ ", with: ""))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(notification.message)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(timeAgo(notification.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
    }
    
    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        return "\(seconds / 3600)h"
    }
}
