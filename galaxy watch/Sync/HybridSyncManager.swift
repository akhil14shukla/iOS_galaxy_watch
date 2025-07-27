import Combine
import CoreBluetooth
import Foundation
import HealthKit

/// Main hybrid sync manager that coordinates between local server and Bluetooth
class HybridSyncManager: ObservableObject {
    static let shared = HybridSyncManager()

    @Published var transportStatus: TransportStatus = .offline
    @Published var isActivelySync: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var pendingDataCount: Int = 0

    // Transport layer components
    private let localServerClient = LocalServerClient()
    private let bluetoothManager = HybridBluetoothManager()

    // Health-related properties
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    // Sync state management
    private var syncState = SyncState()
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    private let syncInterval: TimeInterval = 30  // 30 seconds
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 5

    init() {
        setupNotificationObservers()
        setupPublisherBindings()
        loadSyncState()
        startPeriodicSync()
    }

    deinit {
        syncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBluetoothDataReceived),
            name: NSNotification.Name("BluetoothHealthDataReceived"),
            object: nil
        )
    }

    private func setupPublisherBindings() {
        // Monitor local server connection
        localServerClient.$isConnected
            .sink { [weak self] isConnected in
                self?.updateTransportStatus()
            }
            .store(in: &cancellables)

        // Monitor Bluetooth connection
        bluetoothManager.$isConnected
            .sink { [weak self] isConnected in
                self?.updateTransportStatus()
            }
            .store(in: &cancellables)

        // Monitor errors
        localServerClient.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Local Server: \(error)"
            }
            .store(in: &cancellables)

        bluetoothManager.$lastError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.errorMessage = "Bluetooth: \(error)"
            }
            .store(in: &cancellables)
    }

    private func updateTransportStatus() {
        if localServerClient.isConnected {
            transportStatus = .localServer
        } else if bluetoothManager.isConnected {
            transportStatus = .bluetooth
        } else {
            transportStatus = .offline
        }
    }

    // MARK: - Public Interface

    func startSync() {
        Task {
            await performSync()
        }
    }

    func forceFullSync() {
        syncState = SyncState()  // Reset to sync all data
        saveSyncState()
        Task {
            await performSync()
        }
    }

    func updateLocalServerAddress(host: String, port: Int) {
        localServerClient.updateServerAddress(host: host, port: port)
    }

    func startBluetoothScanning() {
        bluetoothManager.startScanning()
    }

    func connectToBluetooth(peripheral: CBPeripheral) {
        bluetoothManager.connect(to: peripheral)
    }

    func discoverLocalServers() async -> [String] {
        return await localServerClient.discoverLocalServer()
    }

    // MARK: - Settings Management

    func clearLocalData() {
        syncState = SyncState()
        saveSyncState()
        // Clear any cached data
        lastSyncTime = nil
        pendingDataCount = 0
    }

    func setSyncInterval(_ interval: TimeInterval) {
        // Stop current timer
        syncTimer?.invalidate()

        // Start new timer with updated interval
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
            [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }

    func setBackgroundSyncEnabled(_ enabled: Bool) {
        // TODO: Implement background sync configuration
        UserDefaults.standard.set(enabled, forKey: "BackgroundSyncEnabled")
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        // TODO: Implement notification configuration
        UserDefaults.standard.set(enabled, forKey: "NotificationsEnabled")
    }

    func testConnection() async {
        // TODO: Implement connection test
    }

    func isServerReachable() async -> Bool {
        return localServerClient.isConnected
    }

    // MARK: - Sync Logic

    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) {
            [weak self] _ in
            Task {
                await self?.performSync()
            }
        }
    }

    @MainActor
    private func performSync() async {
        guard !isActivelySync else { return }

        isActivelySync = true
        syncProgress = 0.0
        errorMessage = nil

        defer {
            isActivelySync = false
            syncProgress = 1.0
        }

        // Determine which transport to use
        let selectedTransport = selectTransport()
        transportStatus = selectedTransport

        switch selectedTransport {
        case .localServer:
            await syncViaLocalServer()
        case .bluetooth:
            await syncViaBluetooth()
        case .offline:
            errorMessage = "No transport available"
        case .error:
            errorMessage = "Transport error"
        }

        lastSyncTime = Date()
        saveSyncState()
    }

    private func selectTransport() -> TransportStatus {
        // Priority 1: Local Server (if connected and reachable)
        if localServerClient.isConnected {
            return .localServer
        }

        // Priority 2: Bluetooth (if connected)
        if bluetoothManager.isConnected {
            return .bluetooth
        }

        return .offline
    }

    // MARK: - Local Server Sync

    private func syncViaLocalServer() async {
        do {
            syncProgress = 0.1

            // Test connection first
            let isReachable = await localServerClient.testConnection()
            guard isReachable else {
                transportStatus = .offline
                return
            }

            syncProgress = 0.3

            // Fetch new data from server
            let earliestSyncTime =
                [
                    syncState.lastHeartRateSync,
                    syncState.lastStepCountSync,
                    syncState.lastSleepSync,
                    syncState.lastWorkoutSync,
                ].compactMap { $0 }.min() ?? Date(timeIntervalSince1970: 0)

            let fetchResult = await localServerClient.fetchHealthData(since: earliestSyncTime)

            switch fetchResult {
            case .success(let batch):
                if !batch.isEmpty {
                    syncProgress = 0.6
                    await processBatch(batch)
                }

                syncProgress = 0.8

                // Send any pending data to server
                let pendingBatch = await collectPendingData()
                if !pendingBatch.isEmpty {
                    let uploadResult = await localServerClient.uploadHealthData(pendingBatch)
                    switch uploadResult {
                    case .success:
                        await updateSyncState(for: pendingBatch)
                    case .failure(let error):
                        errorMessage = "Upload failed: \(error.localizedDescription)"
                    }
                }

            case .failure(let error):
                errorMessage = "Fetch failed: \(error.localizedDescription)"
            }

        } catch {
            errorMessage = "Local server sync error: \(error.localizedDescription)"
        }
    }

    // MARK: - Bluetooth Sync

    private func syncViaBluetooth() async {
        do {
            syncProgress = 0.1

            // Request sync state from watch
            let syncStateResult = await bluetoothManager.requestSyncState()

            switch syncStateResult {
            case .success(let watchSyncState):
                syncProgress = 0.3

                // Determine what data needs to be synced
                let pendingBatch = await collectPendingData(since: watchSyncState)

                if !pendingBatch.isEmpty {
                    syncProgress = 0.6

                    // Send data to watch
                    let sendResult = await bluetoothManager.sendHealthData(pendingBatch)

                    switch sendResult {
                    case .success:
                        await updateSyncState(for: pendingBatch)
                        syncProgress = 0.9
                    case .failure(let error):
                        errorMessage = "Bluetooth send failed: \(error.localizedDescription)"
                    }
                }

            case .failure(let error):
                errorMessage = "Bluetooth sync state failed: \(error.localizedDescription)"
            }

        } catch {
            errorMessage = "Bluetooth sync error: \(error.localizedDescription)"
        }
    }

    // MARK: - Data Processing

    private func processBatch(_ batch: HealthDataBatch) async {
        // Process heart rate data
        for heartRateData in batch.heartRateData {
            await self.saveHeartRate(heartRateData)
            syncState.updateLastSync(for: .heartRate, to: heartRateData.timestamp)
        }

        // Process step count data
        for stepData in batch.stepCountData {
            await self.saveStepCount(stepData)
            syncState.updateLastSync(for: .stepCount, to: stepData.timestamp)
        }

        // Process sleep data
        for sleepData in batch.sleepData {
            await self.saveSleep(sleepData)
            syncState.updateLastSync(for: .sleep, to: sleepData.timestamp)
        }

        // Process workout data
        for workoutData in batch.workoutData {
            await self.saveWorkout(workoutData)
            syncState.updateLastSync(for: .workout, to: workoutData.timestamp)
        }
    }

    private func collectPendingData(since remoteSyncState: SyncState? = nil) async
        -> HealthDataBatch
    {
        let targetSyncState = remoteSyncState ?? syncState

        // This would collect data from local storage that hasn't been synced yet
        // For now, return empty batch as we're primarily consuming data from the watch
        return HealthDataBatch()
    }

    private func updateSyncState(for batch: HealthDataBatch) async {
        if let latestHeartRate = batch.heartRateData.map(\.timestamp).max() {
            syncState.updateLastSync(for: .heartRate, to: latestHeartRate)
        }

        if let latestStepCount = batch.stepCountData.map(\.timestamp).max() {
            syncState.updateLastSync(for: .stepCount, to: latestStepCount)
        }

        if let latestSleep = batch.sleepData.map(\.timestamp).max() {
            syncState.updateLastSync(for: .sleep, to: latestSleep)
        }

        if let latestWorkout = batch.workoutData.map(\.timestamp).max() {
            syncState.updateLastSync(for: .workout, to: latestWorkout)
        }
    }

    // MARK: - Bluetooth Data Reception

    @objc private func handleBluetoothDataReceived(_ notification: Notification) {
        guard let batch = notification.object as? HealthDataBatch else { return }

        Task {
            await processBatch(batch)
            await MainActor.run {
                self.lastSyncTime = Date()
            }
        }
    }

    // MARK: - Persistence

    private func loadSyncState() {
        if let data = UserDefaults.standard.data(forKey: "HybridSyncState"),
            let state = try? JSONDecoder().decode(SyncState.self, from: data)
        {
            syncState = state
        }
    }

    private func saveSyncState() {
        if let data = try? JSONEncoder().encode(syncState) {
            UserDefaults.standard.set(data, forKey: "HybridSyncState")
        }
    }

    // MARK: - Status Information

    var statusInfo: HybridSyncStatus {
        return HybridSyncStatus(
            transport: transportStatus,
            isActive: isActivelySync,
            lastSyncTime: lastSyncTime,
            errorMessage: errorMessage,
            pendingDataCount: pendingDataCount
        )
    }

    // MARK: - Health Data Operations

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) {
            [weak self] (success: Bool, error: Error?) in
            DispatchQueue.main.async {
                self?.isAuthorized = success
            }
        }
    }

    func saveHeartRate(_ data: HeartRateData) async {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let quantity = HKQuantity(
            unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: data.value)

        let sample = HKQuantitySample(
            type: heartRateType,
            quantity: quantity,
            start: data.timestamp,
            end: data.timestamp,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )

        do {
            try await healthStore.save(sample)
        } catch {
            print("Error saving heart rate: \(error)")
        }
    }

    func saveStepCount(_ data: StepCountData) async {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(data.count))

        let endTime = data.duration.map { data.timestamp.addingTimeInterval($0) } ?? data.timestamp

        let sample = HKQuantitySample(
            type: stepType,
            quantity: quantity,
            start: data.timestamp,
            end: endTime,
            metadata: [HKMetadataKeyWasUserEntered: false]
        )

        do {
            try await healthStore.save(sample)
        } catch {
            print("Error saving step count: \(error)")
        }
    }

    func saveSleep(_ data: SleepData) async {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        var samples: [HKCategorySample] = []

        // Create samples for each sleep stage
        for stage in data.stages {
            let value: Int
            switch stage.stage {
            case .awake:
                value = HKCategoryValueSleepAnalysis.awake.rawValue
            case .light:
                value = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            case .deep:
                value = HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            case .rem:
                value = HKCategoryValueSleepAnalysis.asleepREM.rawValue
            case .unknown:
                value = HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            }

            let sample = HKCategorySample(
                type: sleepType,
                value: value,
                start: stage.startTime,
                end: stage.endTime,
                metadata: [HKMetadataKeyWasUserEntered: false]
            )

            samples.append(sample)
        }

        do {
            try await healthStore.save(samples)
        } catch {
            print("Error saving sleep data: \(error)")
        }
    }

    private func saveWorkout(_ data: HybridWorkoutData) async {
        let workoutType: HKWorkoutActivityType
        switch data.type {
        case .running:
            workoutType = .running
        case .walking:
            workoutType = .walking
        case .cycling:
            workoutType = .cycling
        case .swimming:
            workoutType = .swimming
        case .other:
            workoutType = .other
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workoutType

        let builder = HKWorkoutBuilder(
            healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                builder.beginCollection(withStart: data.startTime) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HealthKit", code: 0,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Failed to begin workout collection"
                                ]))
                    }
                }
            }

            // Add distance if available
            if data.totalDistance > 0 {
                let distanceType = HKQuantityType.quantityType(
                    forIdentifier: .distanceWalkingRunning)!
                let distanceQuantity = HKQuantity(
                    unit: HKUnit.meter(), doubleValue: data.totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: data.startTime,
                    end: data.endTime
                )

                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    builder.add([distanceSample]) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if success {
                            continuation.resume()
                        } else {
                            continuation.resume(
                                throwing: NSError(
                                    domain: "HealthKit", code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to add distance sample"
                                    ]))
                        }
                    }
                }
            }

            // Add calories if available
            if data.totalCalories > 0 {
                let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let calorieQuantity = HKQuantity(
                    unit: HKUnit.kilocalorie(), doubleValue: data.totalCalories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: data.startTime,
                    end: data.endTime
                )

                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    builder.add([calorieSample]) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if success {
                            continuation.resume()
                        } else {
                            continuation.resume(
                                throwing: NSError(
                                    domain: "HealthKit", code: 0,
                                    userInfo: [
                                        NSLocalizedDescriptionKey: "Failed to add calorie sample"
                                    ]))
                        }
                    }
                }
            }

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                builder.endCollection(withEnd: data.endTime) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HealthKit", code: 0,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Failed to end workout collection"
                                ]))
                    }
                }
            }

            let workout = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<HKWorkout, Error>) in
                builder.finishWorkout { workout, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let workout = workout {
                        continuation.resume(returning: workout)
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HealthKit", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to finish workout"]))
                    }
                }
            }

            if !data.route.isEmpty {
                await saveWorkoutRoute(data.route, for: workout)
            }

        } catch {
            print("Error saving workout: \(error)")
        }
    }

    private func saveWorkoutRoute(
        _ route: [HybridWorkoutData.LocationPoint], for workout: HKWorkout
    ) async {
        let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())

        let locations = route.map { $0.clLocation }

        do {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                routeBuilder.insertRouteData(locations) { success, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if success {
                        continuation.resume()
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HealthKit", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to insert route data"]
                            ))
                    }
                }
            }

            let _ = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<HKWorkoutRoute, Error>) in
                routeBuilder.finishRoute(with: workout, metadata: [:]) {
                    (workoutRoute: HKWorkoutRoute?, error: Error?) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let workoutRoute = workoutRoute {
                        continuation.resume(returning: workoutRoute)
                    } else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HealthKit", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to finish route"]))
                    }
                }
            }

            print("Workout route saved successfully")
        } catch {
            print("Error saving workout route: \(error)")
        }
    }
}
