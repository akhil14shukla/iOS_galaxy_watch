import Combine
import HealthKit
import SwiftUI

/// Dedicated Galaxy Watch 4 Classic watchOS Application
/// Optimized for small screen and easy navigation
@main
struct GalaxyWatchOSApp: App {
    var body: some Scene {
        WindowGroup {
            WatchMainView()
        }
    }
}

struct WatchMainView: View {
    @StateObject private var watchManager = GalaxyWatchManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Health Dashboard
            WatchHealthView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Health")
                }
                .tag(0)

            // Activity View
            WatchActivityView()
                .tabItem {
                    Image(systemName: "figure.walk")
                    Text("Activity")
                }
                .tag(1)

            // Sync Status
            WatchSyncView()
                .tabItem {
                    Image(systemName: "arrow.clockwise")
                    Text("Sync")
                }
                .tag(2)

            // Settings
            WatchSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
        .onAppear {
            watchManager.startHealthMonitoring()
        }
    }
}

// MARK: - Health Dashboard View
struct WatchHealthView: View {
    @StateObject private var watchManager = GalaxyWatchManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Heart Rate Card
                    HealthMetricCard(
                        title: "Heart Rate",
                        value: "\(Int(watchManager.currentHeartRate))",
                        unit: "BPM",
                        icon: "heart.fill",
                        color: heartRateColor
                    )

                    // Steps Card
                    HealthMetricCard(
                        title: "Steps",
                        value: "\(watchManager.currentSteps)",
                        unit: "steps",
                        icon: "figure.walk",
                        color: .blue
                    )

                    // Calories Card
                    HealthMetricCard(
                        title: "Calories",
                        value: "\(Int(watchManager.currentCalories))",
                        unit: "cal",
                        icon: "flame.fill",
                        color: .orange
                    )

                    // Battery Level
                    BatteryCard(
                        level: watchManager.batteryLevel,
                        isCharging: false
                    )
                }
                .padding()
            }
            .navigationTitle("Health")
        }
    }

    private var heartRateColor: Color {
        switch watchManager.currentHeartRate {
        case 0..<60: return .blue
        case 60..<100: return .green
        case 100..<140: return .yellow
        case 140..<170: return .orange
        default: return .red
        }
    }
}

// MARK: - Activity View
struct WatchActivityView: View {
    @StateObject private var watchManager = GalaxyWatchManager.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Daily Progress Rings
                    ActivityRingsView(
                        stepsProgress: Double(watchManager.currentSteps) / 10000.0,
                        caloriesProgress: watchManager.currentCalories / 2000.0,
                        activeMinutesProgress: watchManager.activeMinutes / 30.0
                    )

                    // Quick Actions
                    VStack(spacing: 8) {
                        WatchActionButton(
                            title: "Start Workout",
                            icon: "play.fill",
                            color: .green
                        ) {
                            watchManager.startWorkout()
                        }

                        WatchActionButton(
                            title: "Log Activity",
                            icon: "plus.circle.fill",
                            color: .blue
                        ) {
                            // TODO: Quick activity logging
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Activity")
        }
    }
}

// MARK: - Sync Status View
struct WatchSyncView: View {
    @StateObject private var watchManager = GalaxyWatchManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                ConnectionStatusCard(
                    isConnected: watchManager.isPhoneConnected,
                    connectionType: watchManager.connectionType,
                    lastSync: watchManager.lastSyncTime
                )

                // Sync Actions
                VStack(spacing: 12) {
                    WatchActionButton(
                        title: "Sync Now",
                        icon: "arrow.clockwise",
                        color: .blue,
                        isLoading: watchManager.isSyncing
                    ) {
                        Task {
                            await watchManager.performSync()
                        }
                    }

                    WatchActionButton(
                        title: "Force Sync",
                        icon: "arrow.clockwise.circle.fill",
                        color: .orange
                    ) {
                        Task {
                            await watchManager.performFullSync()
                        }
                    }
                }

                // Sync Statistics
                if let stats = watchManager.syncStats {
                    SyncStatsCard(stats: stats)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Sync")
        }
    }
}

// MARK: - Settings View
struct WatchSettingsView: View {
    @StateObject private var watchManager = GalaxyWatchManager.shared
    @State private var selectedSyncInterval = 30.0
    @State private var enableHapticFeedback = true
    @State private var autoSyncEnabled = true

    var body: some View {
        NavigationView {
            List {
                Section("Sync Settings") {
                    Toggle("Auto Sync", isOn: $autoSyncEnabled)
                        .onChange(of: autoSyncEnabled) { enabled in
                            watchManager.setAutoSyncEnabled(enabled)
                        }

                    VStack(alignment: .leading) {
                        Text("Sync Interval: \(Int(selectedSyncInterval))s")
                        Slider(value: $selectedSyncInterval, in: 15...300, step: 15)
                            .onChange(of: selectedSyncInterval) { interval in
                                watchManager.setSyncInterval(interval)
                            }
                    }
                }

                Section("Preferences") {
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                        .onChange(of: enableHapticFeedback) { enabled in
                            watchManager.setHapticFeedbackEnabled(enabled)
                        }
                }

                Section("Device Info") {
                    HStack {
                        Text("Device ID")
                        Spacer()
                        Text(watchManager.deviceID.prefix(8))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Actions") {
                    Button("Reset Sync Data") {
                        watchManager.resetSyncData()
                    }
                    .foregroundColor(.red)

                    Button("Test Connection") {
                        Task {
                            await watchManager.testConnection()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Supporting Views

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct BatteryCard: View {
    let level: Double
    let isCharging: Bool

    var body: some View {
        HStack {
            Image(systemName: isCharging ? "battery.100.bolt" : "battery.100")
                .font(.title2)
                .foregroundColor(batteryColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text("Battery")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(Int(level * 100))")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var batteryColor: Color {
        switch level {
        case 0..<0.2: return .red
        case 0.2..<0.5: return .orange
        default: return .green
        }
    }
}

struct ActivityRingsView: View {
    let stepsProgress: Double
    let caloriesProgress: Double
    let activeMinutesProgress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Steps Ring
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: min(stepsProgress, 1.0))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                // Calories Ring
                Circle()
                    .stroke(Color.orange.opacity(0.3), lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: min(caloriesProgress, 1.0))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                // Active Minutes Ring
                Circle()
                    .stroke(Color.green.opacity(0.3), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: min(activeMinutesProgress, 1.0))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
            }

            HStack(spacing: 20) {
                VStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Text("Steps")
                        .font(.caption2)
                }

                VStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Calories")
                        .font(.caption2)
                }

                VStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Active")
                        .font(.caption2)
                }
            }
        }
    }
}

struct WatchActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: icon)
                }

                Text(title)
                    .fontWeight(.medium)

                Spacer()
            }
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
    }
}

struct ConnectionStatusCard: View {
    let isConnected: Bool
    let connectionType: String
    let lastSync: Date?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.headline)

                Spacer()
            }

            HStack {
                Text("Type: \(connectionType)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            if let lastSync = lastSync {
                HStack {
                    Text("Last Sync: \(lastSync, formatter: timeFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct SyncStatsCard: View {
    let stats: SyncStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync Statistics")
                .font(.headline)

            HStack {
                Text("Success: \(stats.successfulSyncs)")
                    .font(.caption)
                    .foregroundColor(.green)

                Spacer()

                Text("Failed: \(stats.failedSyncs)")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Text("Pending: \(stats.pendingItems)")
                    .font(.caption)
                    .foregroundColor(.orange)

                Spacer()

                Text("Last: \(stats.lastSyncDuration, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Data Models

struct SyncStatistics {
    let successfulSyncs: Int
    let failedSyncs: Int
    let pendingItems: Int
    let lastSyncDuration: Double
}
