import SwiftUI
import Charts

struct LiveHealthDashboard: View {
    @StateObject private var realtimeClient = RealtimeHealthClient()
    @State private var showingConnectionSettings = false
    @State private var serverHost = "192.168.1.100"
    @State private var serverPort = "3000"
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Connection Status Banner
                    connectionStatusBanner
                    
                    // Live Health Metrics
                    liveMetricsSection
                    
                    // Watch Connection Status
                    watchConnectionSection
                    
                    // Real-time Charts
                    realTimeChartsSection
                    
                    // Server Metrics
                    serverMetricsSection
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Live Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingConnectionSettings = true }) {
                        Image(systemName: "gear")
                    }
                    
                    Button(action: toggleConnection) {
                        Image(systemName: realtimeClient.isConnected ? "stop.circle" : "play.circle")
                            .foregroundColor(realtimeClient.isConnected ? .red : .green)
                    }
                }
            }
            .sheet(isPresented: $showingConnectionSettings) {
                connectionSettingsSheet
            }
            .onAppear {
                startAutoRefresh()
                if !realtimeClient.isConnected {
                    realtimeClient.connect()
                }
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    // MARK: - View Components
    
    private var connectionStatusBanner: some View {
        HStack {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 12, height: 12)
                .animation(.easeInOut(duration: 0.5), value: realtimeClient.isConnected)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(realtimeClient.connectionStatus.displayText)
                    .font(.headline)
                
                if let lastReceived = realtimeClient.lastDataReceived {
                    Text("Last data: \(timeAgoString(from: lastReceived))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if realtimeClient.connectionStatus == .connecting || 
               realtimeClient.connectionStatus == .reconnecting {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(connectionBackgroundColor)
        .cornerRadius(12)
    }
    
    private var liveMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Health Data")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                LiveMetricCard(
                    title: "Heart Rate",
                    value: String(format: "%.0f", realtimeClient.liveHealthData.currentHeartRate),
                    unit: "BPM",
                    icon: "heart.fill",
                    color: Color(realtimeClient.liveHealthData.heartRateColor),
                    subtitle: realtimeClient.liveHealthData.heartRateZone
                )
                
                LiveMetricCard(
                    title: "Steps Today",
                    value: "\(realtimeClient.liveHealthData.currentSteps)",
                    unit: "steps",
                    icon: "figure.walk",
                    color: .blue,
                    subtitle: stepsProgress
                )
                
                LiveMetricCard(
                    title: "Calories",
                    value: String(format: "%.0f", realtimeClient.liveHealthData.currentCalories),
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange,
                    subtitle: "Active calories"
                )
                
                LiveMetricCard(
                    title: "Battery",
                    value: String(format: "%.0f", realtimeClient.liveHealthData.batteryLevel),
                    unit: "%",
                    icon: batteryIcon,
                    color: batteryColor,
                    subtitle: "Watch battery"
                )
            }
        }
    }
    
    private var watchConnectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Status")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack {
                    Image(systemName: "applewatch")
                        .font(.largeTitle)
                        .foregroundColor(realtimeClient.liveHealthData.isWatchConnected ? .green : .gray)
                    
                    Text("Galaxy Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(realtimeClient.liveHealthData.isWatchConnected ? "Connected" : "Disconnected")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(realtimeClient.liveHealthData.isWatchConnected ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Update")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(timeAgoString(from: realtimeClient.liveHealthData.lastUpdateTime))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private var realTimeChartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Trends")
                .font(.headline)
            
            // Placeholder for real-time heart rate chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Heart Rate Trend")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .frame(height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title)
                                .foregroundColor(.secondary)
                            
                            Text("Real-time chart coming soon")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
    
    private var serverMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Status")
                .font(.headline)
            
            if let metrics = realtimeClient.serverMetrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ServerMetricCard(
                        title: "Total Devices",
                        value: "\(metrics.totalDevices)",
                        icon: "iphone.and.arrow.forward"
                    )
                    
                    ServerMetricCard(
                        title: "Active Connections",
                        value: "\(metrics.activeConnections)",
                        icon: "network"
                    )
                    
                    ServerMetricCard(
                        title: "Data Points Today",
                        value: "\(metrics.dataPointsToday)",
                        icon: "chart.bar.fill"
                    )
                    
                    ServerMetricCard(
                        title: "Server Uptime",
                        value: metrics.uptimeDisplay,
                        icon: "clock.fill"
                    )
                }
            } else {
                Text("Server metrics unavailable")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }
    
    private var connectionSettingsSheet: some View {
        NavigationView {
            Form {
                Section("Server Configuration") {
                    HStack {
                        Text("Host")
                        Spacer()
                        TextField("192.168.1.100", text: $serverHost)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("3000", text: $serverPort)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("Options") {
                    Toggle("Auto Refresh", isOn: $autoRefresh)
                        .onChange(of: autoRefresh) { _, newValue in
                            if newValue {
                                startAutoRefresh()
                            } else {
                                stopAutoRefresh()
                            }
                        }
                }
                
                Section("Actions") {
                    Button("Apply Settings") {
                        applyConnectionSettings()
                        showingConnectionSettings = false
                    }
                    .foregroundColor(.blue)
                    
                    Button("Reset to Defaults") {
                        serverHost = "192.168.1.100"
                        serverPort = "3000"
                    }
                    .foregroundColor(.orange)
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingConnectionSettings = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var connectionStatusColor: Color {
        switch realtimeClient.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var connectionBackgroundColor: Color {
        Color(UIColor.secondarySystemBackground)
            .opacity(realtimeClient.isConnected ? 1.0 : 0.5)
    }
    
    private var stepsProgress: String {
        let goal = 10000
        let progress = min(100, (realtimeClient.liveHealthData.currentSteps * 100) / goal)
        return "\(progress)% of goal"
    }
    
    private var batteryIcon: String {
        let level = realtimeClient.liveHealthData.batteryLevel
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.25"
        case 0..<25: return "battery.0"
        default: return "battery.unknown"
        }
    }
    
    private var batteryColor: Color {
        let level = realtimeClient.liveHealthData.batteryLevel
        switch level {
        case 50...100: return .green
        case 25..<50: return .orange
        case 0..<25: return .red
        default: return .gray
        }
    }
    
    // MARK: - Helper Methods
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
    
    private func toggleConnection() {
        if realtimeClient.isConnected {
            realtimeClient.disconnect()
        } else {
            realtimeClient.connect()
        }
    }
    
    private func applyConnectionSettings() {
        guard let port = Int(serverPort) else { return }
        realtimeClient.updateServerAddress(host: serverHost, port: port)
    }
    
    private func startAutoRefresh() {
        guard autoRefresh else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            realtimeClient.requestServerMetrics()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

struct LiveMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .frame(height: 120)
    }
}

struct ServerMetricCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .frame(height: 100)
    }
}
