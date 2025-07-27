import Combine
import CoreBluetooth
import Foundation
import HealthKit
import WatchKit

/// Galaxy Watch 4 Classic Manager for watchOS
/// Handles health data, sync, and connection management
class GalaxyWatchManager: NSObject, ObservableObject {
    static let shared = GalaxyWatchManager()

    // MARK: - Published Properties
    @Published var currentHeartRate: Double = 0
    @Published var currentSteps: Int = 0
    @Published var currentCalories: Double = 0
    @Published var batteryLevel: Double = 1.0
    @Published var activeMinutes: Double = 0

    @Published var isPhoneConnected: Bool = false
    @Published var connectionType: String = "Bluetooth"
    @Published var lastSyncTime: Date?
    @Published var isSyncing: Bool = false
    @Published var syncStats: SyncStatistics?

    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var centralManager: CBCentralManager?
    private var phonePeripheral: CBPeripheral?
    private var characteristics: [CBUUID: CBCharacteristic] = [:]

    private var healthKitTimer: Timer?
    private var syncTimer: Timer?
    private var connectionTimer: Timer?

    private var syncInterval: TimeInterval = 30
    private var autoSyncEnabled: Bool = true
    private var hapticFeedbackEnabled: Bool = true

    let deviceID = UUID().uuidString

    // MARK: - Galaxy Watch 4 Service UUIDs
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateCharacteristicUUID = CBUUID(string: "2A37")
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")
    private let customSyncServiceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789012")

    override init() {
        super.init()
        setupHealthKit()
        setupBluetooth()
        loadSettings()

        // Initialize sync stats
        syncStats = SyncStatistics(
            successfulSyncs: UserDefaults.standard.integer(forKey: "SuccessfulSyncs"),
            failedSyncs: UserDefaults.standard.integer(forKey: "FailedSyncs"),
            pendingItems: 0,
            lastSyncDuration: 0
        )
    }

    // MARK: - Health Monitoring

    func startHealthMonitoring() {
        requestHealthKitPermissions()
        startHealthKitQueries()
        startPeriodicSync()
    }

    private func setupHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
    }

    private func requestHealthKitPermissions() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) {
            [weak self] success, error in
            if success {
                DispatchQueue.main.async {
                    self?.startHealthKitQueries()
                }
            }
        }
    }

    private func startHealthKitQueries() {
        startHeartRateQuery()
        startStepsQuery()
        startCaloriesQuery()
        startActiveMinutesQuery()
    }

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) {
            [weak self] _, _, error in
            self?.fetchLatestHeartRate()
        }

        healthStore.execute(query)
        fetchLatestHeartRate()
    }

    private func fetchLatestHeartRate() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                let heartRate = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                DispatchQueue.main.async {
                    self?.currentHeartRate = heartRate
                }
            }
        }

        healthStore.execute(query)
    }

    private func startStepsQuery() {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        let query = HKStatisticsQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            if let sum = result?.sumQuantity() {
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                DispatchQueue.main.async {
                    self?.currentSteps = steps
                }
            }
        }

        healthStore.execute(query)
    }

    private func startCaloriesQuery() {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        let query = HKStatisticsQuery(
            quantityType: caloriesType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            if let sum = result?.sumQuantity() {
                let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                DispatchQueue.main.async {
                    self?.currentCalories = calories
                }
            }
        }

        healthStore.execute(query)
    }

    private func startActiveMinutesQuery() {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)
        else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

        let query = HKStatisticsQuery(
            quantityType: exerciseType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, _ in
            if let sum = result?.sumQuantity() {
                let minutes = sum.doubleValue(for: HKUnit.minute())
                DispatchQueue.main.async {
                    self?.activeMinutes = minutes
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Bluetooth Setup

    private func setupBluetooth() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    private func startScanning() {
        guard let centralManager = centralManager,
            centralManager.state == .poweredOn
        else { return }

        let serviceUUIDs = [heartRateServiceUUID, batteryServiceUUID, deviceInfoServiceUUID]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
    }

    private func connectToPhone() {
        guard let phonePeripheral = phonePeripheral else { return }
        centralManager?.connect(phonePeripheral, options: nil)
    }

    // MARK: - Sync Management

    func performSync() async {
        guard !isSyncing else { return }

        await MainActor.run {
            isSyncing = true
        }

        let startTime = Date()

        do {
            // Simulate sync process
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            // Update sync statistics
            let duration = Date().timeIntervalSince(startTime)
            await updateSyncSuccess(duration: duration)

            await MainActor.run {
                lastSyncTime = Date()

                if hapticFeedbackEnabled {
                    // Haptic feedback on successful sync
                    WKInterfaceDevice.current().play(.success)
                }
            }

        } catch {
            await updateSyncFailure()

            await MainActor.run {
                if hapticFeedbackEnabled {
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }

        await MainActor.run {
            isSyncing = false
        }
    }

    func performFullSync() async {
        await performSync()
    }

    private func startPeriodicSync() {
        guard autoSyncEnabled else { return }

        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) {
            [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }

    @MainActor
    private func updateSyncSuccess(duration: Double) {
        let successCount = UserDefaults.standard.integer(forKey: "SuccessfulSyncs") + 1
        UserDefaults.standard.set(successCount, forKey: "SuccessfulSyncs")

        syncStats = SyncStatistics(
            successfulSyncs: successCount,
            failedSyncs: syncStats?.failedSyncs ?? 0,
            pendingItems: 0,
            lastSyncDuration: duration
        )
    }

    @MainActor
    private func updateSyncFailure() {
        let failureCount = UserDefaults.standard.integer(forKey: "FailedSyncs") + 1
        UserDefaults.standard.set(failureCount, forKey: "FailedSyncs")

        syncStats = SyncStatistics(
            successfulSyncs: syncStats?.successfulSyncs ?? 0,
            failedSyncs: failureCount,
            pendingItems: syncStats?.pendingItems ?? 0,
            lastSyncDuration: syncStats?.lastSyncDuration ?? 0
        )
    }

    // MARK: - Workout Management

    func startWorkout() {
        // TODO: Implement workout session
        print("Starting workout session...")

        if hapticFeedbackEnabled {
            WKInterfaceDevice.current().play(.start)
        }
    }

    // MARK: - Settings Management

    func setAutoSyncEnabled(_ enabled: Bool) {
        autoSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AutoSyncEnabled")

        if enabled {
            startPeriodicSync()
        } else {
            syncTimer?.invalidate()
        }
    }

    func setSyncInterval(_ interval: TimeInterval) {
        syncInterval = interval
        UserDefaults.standard.set(interval, forKey: "SyncInterval")

        if autoSyncEnabled {
            startPeriodicSync()
        }
    }

    func setHapticFeedbackEnabled(_ enabled: Bool) {
        hapticFeedbackEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "HapticFeedbackEnabled")
    }

    func resetSyncData() {
        UserDefaults.standard.removeObject(forKey: "SuccessfulSyncs")
        UserDefaults.standard.removeObject(forKey: "FailedSyncs")

        syncStats = SyncStatistics(
            successfulSyncs: 0,
            failedSyncs: 0,
            pendingItems: 0,
            lastSyncDuration: 0
        )

        lastSyncTime = nil

        if hapticFeedbackEnabled {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func testConnection() async {
        // TODO: Implement connection test
        await MainActor.run {
            isPhoneConnected = true
            connectionType = "Test Mode"
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            isPhoneConnected = false
            connectionType = "Bluetooth"
        }
    }

    private func loadSettings() {
        autoSyncEnabled = UserDefaults.standard.bool(forKey: "AutoSyncEnabled")
        syncInterval = UserDefaults.standard.double(forKey: "SyncInterval")
        hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: "HapticFeedbackEnabled")

        // Set defaults if not set
        if syncInterval == 0 {
            syncInterval = 30
        }
        if !UserDefaults.standard.object(forKey: "HapticFeedbackEnabled") != nil {
            hapticFeedbackEnabled = true
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension GalaxyWatchManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        case .poweredOff, .unsupported, .unauthorized:
            DispatchQueue.main.async {
                self.isPhoneConnected = false
                self.connectionType = "Bluetooth Unavailable"
            }
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        // Look for iPhone advertising as peripheral
        if let name = peripheral.name,
            name.contains("iPhone")
                || advertisementData[CBAdvertisementDataLocalNameKey] as? String == "iPhone"
        {
            phonePeripheral = peripheral
            phonePeripheral?.delegate = self
            connectToPhone()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isPhoneConnected = true
            self.connectionType = "Bluetooth LE"
        }

        // Discover services
        peripheral.discoverServices([
            heartRateServiceUUID, batteryServiceUUID, customSyncServiceUUID,
        ])
    }

    func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        DispatchQueue.main.async {
            self.isPhoneConnected = false
            self.connectionType = "Disconnected"
        }

        // Attempt to reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.startScanning()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension GalaxyWatchManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            self.characteristics[characteristic.uuid] = characteristic

            // Subscribe to notifications for heart rate and battery
            if characteristic.uuid == heartRateCharacteristicUUID
                || characteristic.uuid == batteryLevelCharacteristicUUID
            {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let data = characteristic.value else { return }

        switch characteristic.uuid {
        case heartRateCharacteristicUUID:
            parseHeartRateData(data)
        case batteryLevelCharacteristicUUID:
            parseBatteryData(data)
        default:
            break
        }
    }

    private func parseHeartRateData(_ data: Data) {
        let heartRate = data.withUnsafeBytes { bytes in
            return Double(bytes.bindMemory(to: UInt16.self).first ?? 0)
        }

        DispatchQueue.main.async {
            self.currentHeartRate = heartRate
        }
    }

    private func parseBatteryData(_ data: Data) {
        let batteryLevel = data.withUnsafeBytes { bytes in
            return Double(bytes.bindMemory(to: UInt8.self).first ?? 0) / 100.0
        }

        DispatchQueue.main.async {
            self.batteryLevel = batteryLevel
        }
    }
}

// MARK: - WatchKit Integration

extension GalaxyWatchManager {
    func scheduleBackgroundRefresh() {
        let refreshDate = Date().addingTimeInterval(syncInterval)
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: refreshDate, userInfo: nil
        ) { error in
            if let error = error {
                print("Failed to schedule background refresh: \(error)")
            }
        }
    }
}
