import SwiftUI

/// Homebrew Tab - Package and Cask Management
struct HomebrewTab: View {
    @StateObject private var brew = HomebrewManager.shared
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingPackageInfo = false
    @State private var packageInfo = ""
    @State private var selectedPackageName = ""
    @State private var showingInstallSheet = false
    @State private var installQuery = ""
    @State private var searchResults: [String] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            if !brew.isBrewInstalled {
                brewNotInstalledView
            } else {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    HStack {
                        Text("Formulas (\(brew.packages.count))")
                        if brew.outdatedPackages.count > 0 {
                            Text("\(brew.outdatedPackages.count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }.tag(0)
                    
                    HStack {
                        Text("Casks (\(brew.casks.count))")
                        if brew.outdatedCasks.count > 0 {
                            Text("\(brew.outdatedCasks.count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }.tag(1)
                    
                    Text("Maintenance").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                switch selectedTab {
                case 0: packagesList
                case 1: casksList
                default: maintenanceView
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            brew.checkBrewStatus()
        }
        .sheet(isPresented: $showingPackageInfo) {
            packageInfoSheet
        }
        .sheet(isPresented: $showingInstallSheet) {
            installSheet
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "mug.fill")
                        .font(.title)
                        .foregroundColor(.brown)
                    
                    Text("Homebrew")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                if !brew.brewVersion.isEmpty {
                    Text(brew.brewVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Stats & Actions
            HStack(spacing: 16) {
                if brew.isLoading || brew.isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(brew.totalPackages) packages")
                        .font(.caption)
                    if brew.totalOutdated > 0 {
                        Text("\(brew.totalOutdated) outdated")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Button {
                    showingInstallSheet = true
                } label: {
                    Label("Install", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task { await brew.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
    
    // MARK: - Not Installed View
    
    private var brewNotInstalledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mug")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Homebrew Not Installed")
                .font(.title2.bold())
            
            Text("Install Homebrew to manage packages")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Run this command in Terminal:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .textSelection(.enabled)
            }
            
            Button("Open brew.sh") {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Packages List
    
    private var packagesList: some View {
        VStack(spacing: 0) {
            // Search & Upgrade All
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search formulas...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                
                if brew.outdatedPackages.count > 0 {
                    Button {
                        Task { _ = await brew.upgradeAllPackages() }
                    } label: {
                        Label("Upgrade All", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.horizontal)
            
            // List
            List {
                ForEach(filteredPackages) { pkg in
                    PackageRow(
                        name: pkg.name,
                        version: pkg.version,
                        isOutdated: pkg.isOutdated,
                        onInfo: {
                            selectedPackageName = pkg.name
                            Task {
                                packageInfo = await brew.getInfo(pkg.name)
                                showingPackageInfo = true
                            }
                        },
                        onUpgrade: {
                            Task { _ = await brew.upgradePackage(pkg.name) }
                        },
                        onUninstall: {
                            Task { _ = await brew.uninstallPackage(pkg.name) }
                        }
                    )
                }
            }
            .listStyle(.inset)
        }
    }
    
    private var filteredPackages: [BrewPackage] {
        if searchText.isEmpty {
            return brew.packages.sorted { $0.isOutdated && !$1.isOutdated }
        }
        return brew.packages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Casks List
    
    private var casksList: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search casks...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            
            // List
            List {
                ForEach(filteredCasks) { cask in
                    PackageRow(
                        name: cask.name,
                        version: cask.version,
                        isOutdated: cask.isOutdated,
                        isCask: true,
                        onInfo: {
                            selectedPackageName = cask.name
                            Task {
                                packageInfo = await brew.getInfo(cask.name)
                                showingPackageInfo = true
                            }
                        },
                        onUpgrade: {
                            Task { _ = await brew.upgradeCask(cask.name) }
                        },
                        onUninstall: {
                            Task { _ = await brew.uninstallCask(cask.name) }
                        }
                    )
                }
            }
            .listStyle(.inset)
        }
    }
    
    private var filteredCasks: [BrewCask] {
        if searchText.isEmpty {
            return brew.casks.sorted { $0.isOutdated && !$1.isOutdated }
        }
        return brew.casks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Maintenance View
    
    private var maintenanceView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Update
                MaintenanceCard(
                    icon: "arrow.down.circle",
                    iconColor: .blue,
                    title: "Update Homebrew",
                    description: "Fetch the newest version of Homebrew and formulae"
                ) {
                    Task { _ = await brew.updateBrew() }
                }
                
                // Cleanup
                MaintenanceCard(
                    icon: "trash.circle",
                    iconColor: .orange,
                    title: "Cleanup",
                    description: "Remove old versions and cached downloads"
                ) {
                    Task { _ = await brew.cleanup() }
                }
                
                // Doctor
                MaintenanceCard(
                    icon: "stethoscope",
                    iconColor: .green,
                    title: "Doctor",
                    description: "Check your system for potential problems"
                ) {
                    Task {
                        packageInfo = await brew.doctor()
                        selectedPackageName = "Doctor Report"
                        showingPackageInfo = true
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Package Info Sheet
    
    private var packageInfoSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedPackageName)
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    showingPackageInfo = false
                }
            }
            .padding()
            
            ScrollView {
                Text(packageInfo)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
    
    // MARK: - Install Sheet
    
    private var installSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Install Package")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    showingInstallSheet = false
                }
            }
            
            HStack {
                TextField("Search packages...", text: $installQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            searchResults = await brew.search(installQuery)
                        }
                    }
                
                Button("Search") {
                    Task {
                        searchResults = await brew.search(installQuery)
                    }
                }
                .buttonStyle(.bordered)
            }
            
            if searchResults.isEmpty {
                Text("Enter a package name to search")
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                List(searchResults, id: \.self) { result in
                    HStack {
                        Text(result)
                        Spacer()
                        Button("Install") {
                            Task {
                                if result.contains("--cask") || result.contains("cask/") {
                                    _ = await brew.installCask(result.replacingOccurrences(of: "cask/", with: ""))
                                } else {
                                    _ = await brew.installPackage(result)
                                }
                                showingInstallSheet = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Package Row

struct PackageRow: View {
    let name: String
    let version: String
    let isOutdated: Bool
    var isCask: Bool = false
    let onInfo: () -> Void
    let onUpgrade: () -> Void
    let onUninstall: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCask ? "app.badge" : "shippingbox")
                .foregroundColor(isCask ? .purple : .blue)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(name)
                        .fontWeight(.medium)
                    
                    if isOutdated {
                        Text("Update available")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text(version)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button {
                    onInfo()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.bordered)
                
                if isOutdated {
                    Button {
                        onUpgrade()
                    } label: {
                        Image(systemName: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                Button {
                    onUninstall()
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

// MARK: - Maintenance Card

struct MaintenanceCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(iconColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Run") {
                action()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    HomebrewTab()
        .frame(width: 800, height: 600)
}
