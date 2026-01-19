import SwiftUI

/// Settings view for app configuration
struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0
    @AppStorage("showNotifications") private var showNotifications: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInDock") private var showInDock: Bool = false
    @AppStorage("app_language") private var appLanguage: String = "system"
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label(L10n.string(.settings), systemImage: "gear")
                }
            
            languageSettings
                .tabItem {
                    Label(L10n.string(.language), systemImage: "globe")
                }
            
            notificationSettings
                .tabItem {
                    Label(L10n.string(.notifications), systemImage: "bell")
                }
            
            thresholdsSettings
                .tabItem {
                    Label(L10n.string(.thresholds), systemImage: "slider.horizontal.3")
                }
            
            aboutView
                .tabItem {
                    Label(L10n.string(.about), systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 350)
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        Form {
            Section {
                Toggle(L10n.string(.launchAtLogin), isOn: $launchAtLogin)
                Toggle(L10n.string(.showInDock), isOn: $showInDock)
            }
            
            Section {
                Picker(L10n.string(.refreshInterval), selection: $refreshInterval) {
                    Text(L10n.string(.oneSecond)).tag(1.0)
                    Text(L10n.string(.twoSeconds)).tag(2.0)
                    Text(L10n.string(.fiveSeconds)).tag(5.0)
                    Text(L10n.string(.tenSeconds)).tag(10.0)
                }
                
                Text(L10n.string(.intervalDescription))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Language Settings
    
    private var languageSettings: some View {
        Form {
            Section("Language / Ngôn ngữ") {
                Picker("Select Language", selection: $appLanguage) {
                    ForEach(L10n.Language.allCases, id: \.rawValue) { language in
                        HStack {
                            Text(language.displayName)
                            if language == .system {
                                Text(L10n.string(.auto))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)  // Dropdown style
                .onChange(of: appLanguage) { _, newValue in
                    if let lang = L10n.Language(rawValue: newValue) {
                        L10n.currentLanguage = lang
                        // Reload translations for immediate effect
                        L10n.loadTranslations()
                    }
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string(.preview))
                        .font(.headline)
                    
                    Divider()
                    
                    Group {
                        Label(L10n.string(.overview), systemImage: "square.grid.2x2")
                        Label(L10n.string(.processes), systemImage: "list.bullet.rectangle")
                        Label(L10n.string(.insights), systemImage: "lightbulb")
                        Label(L10n.string(.ports), systemImage: "network")
                        Label(L10n.string(.systemNormal), systemImage: "checkmark.circle")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            L10n.loadSavedLanguage()
            appLanguage = L10n.currentLanguage.rawValue
        }
    }
    
    // MARK: - Notification Settings
    
    private var notificationSettings: some View {
        Form {
            Section {
                Toggle(L10n.string(.enableNotifications), isOn: $showNotifications)
            }
            
            Section(L10n.string(.notifyWhen)) {
                Toggle(L10n.string(.cpuExceedsThreshold), isOn: .constant(true))
                Toggle(L10n.string(.memoryPressureHigh), isOn: .constant(true))
                Toggle(L10n.string(.thermalThrottling), isOn: .constant(true))
                Toggle(L10n.string(.portStartsStops), isOn: .constant(true))
            }
            .disabled(!showNotifications)
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Thresholds Settings
    
    @AppStorage("cpuThreshold") private var cpuThreshold: Double = 80
    @AppStorage("memoryThreshold") private var memoryThreshold: Double = 75
    @AppStorage("temperatureThreshold") private var temperatureThreshold: Double = 80
    
    private var thresholdsSettings: some View {
        Form {
            Section(L10n.string(.warningThresholds)) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.string(.cpuUsage))
                        Spacer()
                        Text(String(format: L10n.string(.percentValue), Int(cpuThreshold)))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $cpuThreshold, in: 50...100, step: 5)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.string(.memoryUsage))
                        Spacer()
                        Text(String(format: L10n.string(.percentValue), Int(memoryThreshold)))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $memoryThreshold, in: 50...100, step: 5)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(L10n.string(.cpuTemp))
                        Spacer()
                        Text(String(format: L10n.string(.tempFormat), Int(temperatureThreshold)))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $temperatureThreshold, in: 60...100, step: 5)
                }
            }
            
            Section {
                Button(L10n.string(.resetToDefaults)) {
                    cpuThreshold = 80
                    memoryThreshold = 75
                    temperatureThreshold = 80
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - About View
    
    private var aboutView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text(L10n.string(.appName))
                .font(.title)
                .fontWeight(.bold)
            
            Text(L10n.string(.appDescription))
                .foregroundColor(.secondary)
            
            Text("\(L10n.string(.version)) 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .frame(width: 200)
            
            HStack {
                Text(L10n.string(.vietnamese))
                Text(L10n.string(.bullet))
                Text(L10n.string(.english))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text(L10n.string(.copyright))
                .font(.caption)
                .foregroundColor(.secondary)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
