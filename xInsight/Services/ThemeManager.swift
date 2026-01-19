import SwiftUI

/// ThemeManager - Manages app appearance and custom themes
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // MARK: - Published Properties
    @Published var currentTheme: AppTheme = .system
    @Published var accentColor: Color = .blue
    @Published var useDynamicColors: Bool = true
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Theme Management
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        applyTheme()
        saveSettings()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveSettings()
    }
    
    private func applyTheme() {
        switch currentTheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
    
    // MARK: - Dynamic Colors
    
    var primaryColor: Color {
        useDynamicColors ? accentColor : .blue
    }
    
    var successColor: Color {
        .green
    }
    
    var warningColor: Color {
        .yellow
    }
    
    var dangerColor: Color {
        .red
    }
    
    var backgroundColor: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    var secondaryBackgroundColor: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    // MARK: - Persistence
    
    private func saveSettings() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        
        // Save accent color as RGB
        if let components = NSColor(accentColor).cgColor.components {
            UserDefaults.standard.set(components, forKey: "accent_color")
        }
        
        UserDefaults.standard.set(useDynamicColors, forKey: "use_dynamic_colors")
    }
    
    private func loadSettings() {
        if let themeValue = UserDefaults.standard.string(forKey: "app_theme"),
           let theme = AppTheme(rawValue: themeValue) {
            currentTheme = theme
        }
        
        if let components = UserDefaults.standard.array(forKey: "accent_color") as? [CGFloat],
           components.count >= 3 {
            accentColor = Color(red: components[0], green: components[1], blue: components[2])
        }
        
        useDynamicColors = UserDefaults.standard.bool(forKey: "use_dynamic_colors")
        
        applyTheme()
    }
}

// MARK: - Theme Enum

enum AppTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    private let presetColors: [Color] = [
        .blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .cyan
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Theme Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        themeButton(theme)
                    }
                }
            }
            
            Divider()
            
            // Accent Color
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent Color")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { color in
                        colorButton(color)
                    }
                    
                    ColorPicker("", selection: $themeManager.accentColor)
                        .labelsHidden()
                        .frame(width: 30, height: 30)
                }
                
                Toggle("Use dynamic colors", isOn: $themeManager.useDynamicColors)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func themeButton(_ theme: AppTheme) -> some View {
        Button {
            themeManager.setTheme(theme)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: theme.icon)
                    .font(.title2)
                Text(theme.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 70)
            .background(themeManager.currentTheme == theme ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(themeManager.currentTheme == theme ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func colorButton(_ color: Color) -> some View {
        Button {
            themeManager.setAccentColor(color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .opacity(themeManager.accentColor == color ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }
}
