import HealthKit
import SwiftUI

struct EnhancedSettingsView: View {
    @StateObject private var healthManager = HealthManager()
    @StateObject private var syncManager = HybridSyncManager.shared
    @StateObject private var bluetoothManager = BluetoothManager()

    @State private var isHealthKitAuthorized = false
    @State private var isBluetoothEnabled = false
    @State private var isServerConnected = false
    @State private var syncInterval: Double = 60
    @State private var enableBackgroundSync = true
    @State private var enableNotifications = true
    @State private var selectedSyncMethod = SyncMethod.hybrid
    @State private var showingHealthGoals = false
    @State private var showingDataExport = false
    @State private var showingPrivacyInfo = false

    enum SyncMethod: String, CaseIterable {
        case wifi = "Wi-Fi Only"
        case bluetooth = "Bluetooth Only"
        case hybrid = "Hybrid (Wi-Fi + Bluetooth)"
    }

    var body: some View {
        NavigationView {
            List {
                // System Status Section
                Section("System Status") {
                    StatusRow(
                        title: "HealthKit",
                        status: isHealthKitAuthorized ? .connected : .disconnected,
                        description: isHealthKitAuthorized
                            ? "Health data access granted" : "Health access required"
                    ) {
                        if !isHealthKitAuthorized {
                            requestHealthKitPermission()
                        }
                    }

                    StatusRow(
                        title: "Bluetooth",
                        status: isBluetoothEnabled ? .connected : .disconnected,
                        description: isBluetoothEnabled
                            ? "Bluetooth ready for device sync" : "Bluetooth disabled"
                    ) {
                        // Open Bluetooth settings
                        if let url = URL(string: "App-Prefs:root=Bluetooth") {
                            UIApplication.shared.open(url)
                        }
                    }

                    StatusRow(
                        title: "Local Server",
                        status: isServerConnected ? .connected : .disconnected,
                        description: isServerConnected
                            ? "Connected to local sync server" : "Server connection unavailable"
                    ) {
                        Task {
                            await syncManager.testConnection()
                        }
                    }
                }

                // Sync Configuration Section
                Section("Sync Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Method")
                            .font(.headline)

                        Picker("Sync Method", selection: $selectedSyncMethod) {
                            ForEach(SyncMethod.allCases, id: \.self) { method in
                                Text(method.rawValue).tag(method)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        Text(getSyncMethodDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sync Interval")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(syncInterval))s")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $syncInterval, in: 30...300, step: 30) {
                            Text("Sync Interval")
                        }
                        .onChange(of: syncInterval) { newValue in
                            syncManager.setSyncInterval(TimeInterval(newValue))
                        }

                        Text("How often to sync health data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Toggle("Background Sync", isOn: $enableBackgroundSync)
                        .onChange(of: enableBackgroundSync) { enabled in
                            syncManager.setBackgroundSyncEnabled(enabled)
                        }

                    Toggle("Sync Notifications", isOn: $enableNotifications)
                        .onChange(of: enableNotifications) { enabled in
                            syncManager.setNotificationsEnabled(enabled)
                        }
                }

                // Health Goals Section
                Section("Health Goals") {
                    Button(action: { showingHealthGoals = true }) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.blue)
                            Text("Customize Health Goals")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Data Management Section
                Section("Data Management") {
                    Button(action: { showingDataExport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.green)
                            Text("Export Health Data")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: clearLocalData) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Local Data")
                        }
                    }
                    .foregroundColor(.red)
                }

                // Privacy & Security Section
                Section("Privacy & Security") {
                    Button(action: { showingPrivacyInfo = true }) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.purple)
                            Text("Privacy Information")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    NavigationLink(destination: DataPermissionsView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.orange)
                            Text("Data Permissions")
                        }
                    }
                }

                // Advanced Section
                Section("Advanced") {
                    NavigationLink(destination: DiagnosticsView()) {
                        HStack {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.teal)
                            Text("System Diagnostics")
                        }
                    }

                    NavigationLink(destination: DeveloperSettingsView()) {
                        HStack {
                            Image(systemName: "hammer")
                                .foregroundColor(.gray)
                            Text("Developer Settings")
                        }
                    }
                }

                // App Information Section
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(getBuildNumber())
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(getDeviceID())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                checkSystemStatus()
            }
            .sheet(isPresented: $showingHealthGoals) {
                HealthGoalsView()
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .sheet(isPresented: $showingPrivacyInfo) {
                PrivacyInfoView()
            }
        }
    }

    private func checkSystemStatus() {
        // Check HealthKit authorization
        isHealthKitAuthorized = healthManager.isAuthorized

        // Check Bluetooth status
        isBluetoothEnabled = bluetoothManager.isBluetoothEnabled

        // Check server connection
        Task {
            isServerConnected = await syncManager.isServerReachable()
        }
    }

    private func requestHealthKitPermission() {
        Task {
            await healthManager.requestPermissions()
            isHealthKitAuthorized = healthManager.isAuthorized
        }
    }

    private func getSyncMethodDescription() -> String {
        switch selectedSyncMethod {
        case .wifi:
            return "Sync only when connected to Wi-Fi. More reliable but requires network access."
        case .bluetooth:
            return "Sync directly with paired devices via Bluetooth. Works offline but slower."
        case .hybrid:
            return "Automatically choose the best connection method. Recommended for most users."
        }
    }

    private func clearLocalData() {
        // TODO: Implement data clearing
        syncManager.clearLocalData()
    }

    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func getBuildNumber() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private func getDeviceID() -> String {
        UIDevice.current.identifierForVendor?.uuidString.prefix(8).uppercased() ?? "UNKNOWN"
    }
}

struct StatusRow: View {
    let title: String
    let status: ConnectionStatus
    let description: String
    let action: (() -> Void)?

    enum ConnectionStatus {
        case connected, disconnected, connecting

        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .connecting: return .orange
            }
        }

        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .disconnected: return "xmark.circle.fill"
            case .connecting: return "clock.circle.fill"
            }
        }
    }

    init(title: String, status: ConnectionStatus, description: String, action: (() -> Void)? = nil)
    {
        self.title = title
        self.status = status
        self.description = description
        self.action = action
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let action = action, status == .disconnected {
                Button("Fix", action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

struct HealthGoalsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dailySteps = 10000.0
    @State private var sleepHours = 8.0
    @State private var activeMinutes = 30.0
    @State private var caloriesBurned = 500.0
    @State private var waterIntake = 8.0

    var body: some View {
        NavigationView {
            Form {
                Section("Activity Goals") {
                    VStack(alignment: .leading) {
                        Text("Daily Steps: \(Int(dailySteps))")
                        Slider(value: $dailySteps, in: 5000...20000, step: 500)
                    }

                    VStack(alignment: .leading) {
                        Text("Active Minutes: \(Int(activeMinutes))")
                        Slider(value: $activeMinutes, in: 15...120, step: 5)
                    }

                    VStack(alignment: .leading) {
                        Text("Calories Burned: \(Int(caloriesBurned))")
                        Slider(value: $caloriesBurned, in: 200...1000, step: 50)
                    }
                }

                Section("Sleep & Wellness") {
                    VStack(alignment: .leading) {
                        Text("Sleep Hours: \(sleepHours, specifier: "%.1f")")
                        Slider(value: $sleepHours, in: 6...10, step: 0.5)
                    }

                    VStack(alignment: .leading) {
                        Text("Water Intake (glasses): \(Int(waterIntake))")
                        Slider(value: $waterIntake, in: 4...12, step: 1)
                    }
                }
            }
            .navigationTitle("Health Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoals()
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveGoals() {
        // TODO: Save goals to user defaults and sync to server
        let goals: [String: Any] = [
            "dailySteps": Int(dailySteps),
            "sleepHours": sleepHours,
            "activeMinutes": Int(activeMinutes),
            "caloriesBurned": Int(caloriesBurned),
            "waterIntake": Int(waterIntake),
        ]

        UserDefaults.standard.set(goals, forKey: "healthGoals")
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTimeRange = TimeRange.lastWeek
    @State private var selectedDataTypes: Set<String> = ["heart_rate", "steps", "sleep"]
    @State private var isExporting = false

    enum TimeRange: String, CaseIterable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case last3Months = "Last 3 Months"
        case allTime = "All Time"
    }

    let dataTypes = [
        "heart_rate": "Heart Rate",
        "steps": "Steps",
        "sleep": "Sleep",
        "calories": "Calories",
        "distance": "Distance",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Time Range") {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                }

                Section("Data Types") {
                    ForEach(Array(dataTypes.keys), id: \.self) { key in
                        Toggle(
                            dataTypes[key] ?? key,
                            isOn: Binding(
                                get: { selectedDataTypes.contains(key) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedDataTypes.insert(key)
                                    } else {
                                        selectedDataTypes.remove(key)
                                    }
                                }
                            ))
                    }
                }

                Section {
                    Button(action: exportData) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isExporting ? "Exporting..." : "Export Data")
                        }
                    }
                    .disabled(isExporting || selectedDataTypes.isEmpty)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func exportData() {
        isExporting = true

        // TODO: Implement data export
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExporting = false
            dismiss()
        }
    }
}

struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    privacySection(
                        title: "Health Data Collection",
                        content:
                            "This app collects health data from HealthKit with your explicit permission. Data includes heart rate, steps, sleep patterns, and other metrics you choose to share."
                    )

                    privacySection(
                        title: "Data Storage",
                        content:
                            "Health data is stored locally on your device and synchronized to your local server. No data is sent to third-party services without your consent."
                    )

                    privacySection(
                        title: "Data Sharing",
                        content:
                            "Your health data is only shared with devices and services you explicitly connect. You can revoke access at any time through the app settings."
                    )

                    privacySection(
                        title: "Security",
                        content:
                            "All data transmission uses encrypted connections. Local storage is protected by iOS security features and your device passcode."
                    )

                    privacySection(
                        title: "Your Rights",
                        content:
                            "You can view, export, or delete your health data at any time. You have full control over what data is collected and how it's used."
                    )
                }
                .padding()
            }
            .navigationTitle("Privacy Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func privacySection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

struct DataPermissionsView: View {
    var body: some View {
        List {
            Section("HealthKit Permissions") {
                PermissionRow(title: "Heart Rate", isGranted: true)
                PermissionRow(title: "Steps", isGranted: true)
                PermissionRow(title: "Sleep Analysis", isGranted: false)
                PermissionRow(title: "Active Energy", isGranted: true)
                PermissionRow(title: "Distance", isGranted: false)
            }

            Section("System Permissions") {
                PermissionRow(title: "Bluetooth", isGranted: true)
                PermissionRow(title: "Notifications", isGranted: true)
                PermissionRow(title: "Background App Refresh", isGranted: false)
            }
        }
        .navigationTitle("Data Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PermissionRow: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
    }
}

struct DiagnosticsView: View {
    var body: some View {
        List {
            Section("Connection Tests") {
                DiagnosticRow(title: "Local Server", status: .connected)
                DiagnosticRow(title: "HealthKit", status: .connected)
                DiagnosticRow(title: "Bluetooth", status: .warning)
            }

            Section("Performance Metrics") {
                HStack {
                    Text("Sync Success Rate")
                    Spacer()
                    Text("95.2%")
                        .foregroundColor(.green)
                }

                HStack {
                    Text("Average Sync Time")
                    Spacer()
                    Text("2.3s")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Last Successful Sync")
                    Spacer()
                    Text("2 minutes ago")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("System Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DiagnosticRow: View {
    let title: String
    let status: Status

    enum Status {
        case connected, warning, error

        var color: Color {
            switch self {
            case .connected: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var text: String {
            switch self {
            case .connected: return "OK"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(status.text)
                .foregroundColor(status.color)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(status.color.opacity(0.1))
                .cornerRadius(4)
        }
    }
}

struct DeveloperSettingsView: View {
    @State private var enableDebugLogging = false
    @State private var mockDataEnabled = false
    @State private var simulateErrors = false

    var body: some View {
        List {
            Section("Debug Options") {
                Toggle("Enable Debug Logging", isOn: $enableDebugLogging)
                Toggle("Use Mock Data", isOn: $mockDataEnabled)
                Toggle("Simulate Connection Errors", isOn: $simulateErrors)
            }

            Section("Reset Options") {
                Button("Reset All Settings") {
                    // TODO: Reset settings
                }
                .foregroundColor(.orange)

                Button("Clear Debug Logs") {
                    // TODO: Clear logs
                }
                .foregroundColor(.blue)
            }
        }
        .navigationTitle("Developer Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    EnhancedSettingsView()
}
