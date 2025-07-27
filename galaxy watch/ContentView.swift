import CoreBluetooth
import SwiftUI

struct ContentView: View {
    @StateObject private var hybridSyncManager = HybridSyncManager()
    @StateObject private var localServerClient = LocalServerClient()
    @StateObject private var bluetoothManager = HybridBluetoothManager()

    @State private var showingServerSettings = false
    @State private var showingBluetoothDevices = false
    @State private var serverHost = "192.168.1.100"
    @State private var serverPort = "8080"
    @State private var discoveredServers: [String] = []
    @State private var isDiscoveringServers = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Main Sync View
            mainSyncView
                .tabItem {
                    Image(systemName: "sync.circle")
                    Text("Sync")
                }
                .tag(0)

            // Live Dashboard
            LiveHealthDashboard()
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Live")
                }
                .tag(1)

            // Analytics View
            AnalyticsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Analytics")
                }
                .tag(2)

            // Settings View
            EnhancedSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }

    private var mainSyncView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Transport Status
                    transportStatusSection

                    // Sync Status
                    syncStatusSection

                    // Local Server Configuration
                    localServerSection

                    // Bluetooth Configuration
                    bluetoothSection

                    // Manual Sync Controls
                    syncControlsSection

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Galaxy Watch Sync")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingServerSettings) {
                serverSettingsSheet
            }
            .sheet(isPresented: $showingBluetoothDevices) {
                bluetoothDevicesSheet
            }
        }
    }

    private var settingsView: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // App Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Version")
                                Spacer()
                                Text("2.0.0")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Build")
                                Spacer()
                                Text("2025.1")
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Platform")
                                Spacer()
                                Text("iOS 18.5+")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Privacy & Security
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy & Security")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("✓ All data stays on your local network")
                            Text("✓ No cloud services required")
                            Text("✓ End-to-end encryption for Bluetooth")
                            Text("✓ Open source components")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Feature Status
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)

                        VStack(spacing: 8) {
                            FeatureStatusRow(
                                title: "Galaxy Watch BLE",
                                status: bluetoothManager.isScanning ? .active : .inactive,
                                description: "Bluetooth Low Energy connection"
                            )

                            FeatureStatusRow(
                                title: "Local Server",
                                status: localServerClient.isConnected ? .active : .inactive,
                                description: "HTTP-based data synchronization"
                            )

                            FeatureStatusRow(
                                title: "Apple Health",
                                status: .active,
                                description: "Health data integration"
                            )

                            FeatureStatusRow(
                                title: "Real-time Streaming",
                                status: .active,
                                description: "WebSocket live updates"
                            )

                            FeatureStatusRow(
                                title: "Analytics",
                                status: .active,
                                description: "Advanced health insights"
                            )
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    // Support & Help
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Support")
                            .font(.headline)

                        VStack(spacing: 8) {
                            Button("View Documentation") {
                                // Open documentation
                            }
                            .foregroundColor(.blue)

                            Button("Report Issue") {
                                // Open issue reporting
                            }
                            .foregroundColor(.blue)

                            Button("Check for Updates") {
                                // Check for updates
                            }
                            .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct FeatureStatusRow: View {
    let title: String
    let status: FeatureStatus
    let description: String

    enum FeatureStatus {
        case active, inactive, warning

        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .gray
            case .warning: return .orange
            }
        }

        var icon: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .inactive: return "circle"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: transportIconName)
                .font(.system(size: 60))
                .foregroundColor(transportColor)
                .animation(.easeInOut(duration: 0.3), value: hybridSyncManager.transportStatus)

            Text("Hybrid Data Sync")
                .font(.title2)
                .fontWeight(.semibold)

            Text(transportStatusText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Transport Status Section

    private var transportStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Transport Status")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(transportColor)
                    .frame(width: 12, height: 12)
            }

            HStack(spacing: 20) {
                transportCard(
                    title: "Local Server",
                    icon: "network",
                    isActive: hybridSyncManager.transportStatus == .localServer,
                    isConnected: localServerClient.isConnected
                )

                transportCard(
                    title: "Bluetooth",
                    icon: "bluetooth",
                    isActive: hybridSyncManager.transportStatus == .bluetooth,
                    isConnected: bluetoothManager.isConnected
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func transportCard(title: String, icon: String, isActive: Bool, isConnected: Bool)
        -> some View
    {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .primary : .secondary)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text(isConnected ? "Connected" : "Disconnected")
                .font(.caption2)
                .foregroundColor(isConnected ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    // MARK: - Sync Status Section

    private var syncStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sync Status")
                    .font(.headline)
                Spacer()
                if hybridSyncManager.isActivelySync {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last Sync:")
                    Spacer()
                    Text(lastSyncText)
                        .foregroundColor(.secondary)
                }

                if hybridSyncManager.isActivelySync {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress:")
                            Spacer()
                            Text("\(Int(hybridSyncManager.syncProgress * 100))%")
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: hybridSyncManager.syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                }

                if let error = hybridSyncManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Local Server Section

    private var localServerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Local Server")
                        .font(.headline)
                    Text("\(serverHost):\(serverPort)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Settings") {
                    showingServerSettings = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        isDiscoveringServers = true
                        discoveredServers = await hybridSyncManager.discoverLocalServers()
                        isDiscoveringServers = false
                    }
                }) {
                    HStack {
                        if isDiscoveringServers {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text("Discover")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isDiscoveringServers)

                Button("Test Connection") {
                    Task {
                        await localServerClient.testConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if !discoveredServers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discovered Servers:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(discoveredServers, id: \.self) { server in
                        Button(server) {
                            serverHost = server
                            hybridSyncManager.updateLocalServerAddress(
                                host: server, port: Int(serverPort) ?? 8080)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Bluetooth Section

    private var bluetoothSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Bluetooth")
                        .font(.headline)
                    Text(bluetoothManager.connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Devices") {
                    showingBluetoothDevices = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 12) {
                Button(bluetoothManager.isScanning ? "Stop Scan" : "Scan") {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        hybridSyncManager.startBluetoothScanning()
                    }
                }
                .buttonStyle(.bordered)

                if bluetoothManager.isConnected {
                    Button("Disconnect") {
                        bluetoothManager.disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Connect") {
                        showingBluetoothDevices = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(bluetoothManager.discoveredDevices.isEmpty)
                }
            }

            if bluetoothManager.isConnected && bluetoothManager.dataTransferProgress > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Transfer Progress:")
                        Spacer()
                        Text("\(Int(bluetoothManager.dataTransferProgress * 100))%")
                    }
                    .font(.caption)

                    ProgressView(value: bluetoothManager.dataTransferProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Sync Controls Section

    private var syncControlsSection: some View {
        VStack(spacing: 12) {
            Text("Manual Sync")
                .font(.headline)

            VStack(spacing: 8) {
                Button("Start Sync") {
                    hybridSyncManager.startSync()
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    hybridSyncManager.isActivelySync
                        || hybridSyncManager.transportStatus == .offline)

                Button("Force Full Sync") {
                    hybridSyncManager.forceFullSync()
                }
                .buttonStyle(.bordered)
                .disabled(
                    hybridSyncManager.isActivelySync
                        || hybridSyncManager.transportStatus == .offline)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Server Settings Sheet

    private var serverSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Server Configuration") {
                    HStack {
                        Text("Host:")
                        TextField("IP Address", text: $serverHost)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Port:")
                        TextField("Port", text: $serverPort)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }

                Section("Status") {
                    HStack {
                        Text("Connection:")
                        Spacer()
                        Text(localServerClient.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(localServerClient.isConnected ? .green : .red)
                    }

                    if let error = localServerClient.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingServerSettings = false
                },
                trailing: Button("Save") {
                    hybridSyncManager.updateLocalServerAddress(
                        host: serverHost,
                        port: Int(serverPort) ?? 8080
                    )
                    showingServerSettings = false
                }
            )
        }
    }

    // MARK: - Bluetooth Devices Sheet

    private var bluetoothDevicesSheet: some View {
        NavigationView {
            List {
                if bluetoothManager.discoveredDevices.isEmpty {
                    Text("No devices found. Start scanning to discover Galaxy Watches.")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name ?? "Unknown Device")
                                    .font(.headline)
                                Text(device.identifier.uuidString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Connect") {
                                hybridSyncManager.connectToBluetooth(peripheral: device)
                                showingBluetoothDevices = false
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Bluetooth Devices")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    showingBluetoothDevices = false
                },
                trailing: Button(bluetoothManager.isScanning ? "Stop" : "Scan") {
                    if bluetoothManager.isScanning {
                        bluetoothManager.stopScanning()
                    } else {
                        hybridSyncManager.startBluetoothScanning()
                    }
                }
            )
        }
    }

    // MARK: - Computed Properties

    private var transportIconName: String {
        switch hybridSyncManager.transportStatus {
        case .localServer:
            return "network"
        case .bluetooth:
            return "bluetooth"
        case .offline:
            return "wifi.slash"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    private var transportColor: Color {
        switch hybridSyncManager.transportStatus {
        case .localServer:
            return .blue
        case .bluetooth:
            return .purple
        case .offline:
            return .orange
        case .error:
            return .red
        }
    }

    private var transportStatusText: String {
        switch hybridSyncManager.transportStatus {
        case .localServer:
            return "Connected via Local Server\nOptimal performance for large data transfers"
        case .bluetooth:
            return "Connected via Bluetooth\nDirect device-to-device communication"
        case .offline:
            return "No Connection Available\nCheck your network and Bluetooth settings"
        case .error:
            return "Connection Error\nPlease check your settings and try again"
        }
    }

    private var lastSyncText: String {
        if let lastSync = hybridSyncManager.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        } else {
            return "Never"
        }
    }
}
