import SwiftUI

/// CustomAlertsView - UI for managing custom alert thresholds
struct CustomAlertsView: View {
    @StateObject private var alertsManager = CustomAlerts.shared
    @State private var showingAddAlert = false
    @State private var editingAlert: CustomAlert?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection
            
            // Toggle
            HStack {
                Toggle("Enable Custom Alerts", isOn: $alertsManager.isEnabled)
                    .toggleStyle(.switch)
                Spacer()
            }
            
            Divider()
            
            // Alert List
            if alertsManager.alerts.isEmpty {
                emptyState
            } else {
                alertsList
            }
            
            Spacer()
            
            // Recent Triggers
            if !alertsManager.triggeredAlerts.isEmpty {
                recentTriggersSection
            }
        }
        .padding(24)
        .sheet(isPresented: $showingAddAlert) {
            AlertEditorSheet(alert: nil) { newAlert in
                alertsManager.addAlert(newAlert)
            }
        }
        .sheet(item: $editingAlert) { alert in
            AlertEditorSheet(alert: alert) { updated in
                alertsManager.updateAlert(updated)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom Alerts")
                    .font(.title.bold())
                Text("Set thresholds to receive notifications")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                showingAddAlert = true
            } label: {
                Label("Add Alert", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Alerts List
    
    private var alertsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(alertsManager.alerts) { alert in
                    alertRow(alert)
                }
            }
        }
    }
    
    private func alertRow(_ alert: CustomAlert) -> some View {
        HStack {
            // Icon
            Image(systemName: alert.metric.icon)
                .foregroundColor(alert.isEnabled ? .blue : .gray)
                .frame(width: 30)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.name)
                    .font(.headline)
                Text("\(alert.metric.displayName) \(alert.condition.rawValue.lowercased()) \(String(format: "%.0f", alert.threshold))\(alert.metric.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { alert.isEnabled },
                set: { _ in alertsManager.toggleAlert(alert.id) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            
            // Edit
            Button {
                editingAlert = alert
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            
            // Delete
            Button(role: .destructive) {
                alertsManager.deleteAlert(alert.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No custom alerts")
                .foregroundColor(.secondary)
            Button("Add Your First Alert") {
                showingAddAlert = true
            }
            .buttonStyle(.bordered)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Recent Triggers
    
    private var recentTriggersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Triggers")
                .font(.headline)
            
            ForEach(alertsManager.triggeredAlerts.prefix(5)) { trigger in
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(trigger.alertName)
                        .font(.subheadline)
                    Spacer()
                    Text(trigger.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Alert Editor Sheet

struct AlertEditorSheet: View {
    let alert: CustomAlert?
    let onSave: (CustomAlert) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var metric: AlertMetric = .cpu
    @State private var condition: AlertCondition = .above
    @State private var threshold: Double = 80
    
    var body: some View {
        VStack(spacing: 20) {
            Text(alert == nil ? "Add Alert" : "Edit Alert")
                .font(.title2.bold())
            
            Form {
                TextField("Name", text: $name)
                
                Picker("Metric", selection: $metric) {
                    ForEach(AlertMetric.allCases, id: \.self) { m in
                        Label(m.displayName, systemImage: m.icon).tag(m)
                    }
                }
                
                Picker("Condition", selection: $condition) {
                    ForEach(AlertCondition.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                
                HStack {
                    Text("Threshold")
                    Slider(value: $threshold, in: 0...100, step: 5)
                    Text("\(String(format: "%.0f", threshold))\(metric.unit)")
                        .frame(width: 50)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    let newAlert = CustomAlert(
                        id: alert?.id ?? UUID().uuidString,
                        name: name,
                        metric: metric,
                        condition: condition,
                        threshold: threshold,
                        duration: 30,
                        isEnabled: true
                    )
                    onSave(newAlert)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
        .onAppear {
            if let alert = alert {
                name = alert.name
                metric = alert.metric
                condition = alert.condition
                threshold = alert.threshold
            }
        }
    }
}
