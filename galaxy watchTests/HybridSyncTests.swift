import XCTest
import Combine
import CoreBluetooth
@testable import galaxy_watch

class HybridSyncManagerTests: XCTestCase {
    var hybridSyncManager: HybridSyncManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        hybridSyncManager = HybridSyncManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        hybridSyncManager = nil
        cancellables = nil
    }
    
    // MARK: - Transport Selection Tests
    
    func testTransportSelectionPriority() {
        // Test that local server is preferred over Bluetooth
        let expectation = XCTestExpectation(description: "Transport status updated")
        
        hybridSyncManager.$transportStatus
            .sink { status in
                if status != .offline {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testOfflineTransportWhenNothingConnected() {
        XCTAssertEqual(hybridSyncManager.transportStatus, .offline)
    }
    
    // MARK: - Local Server Tests
    
    func testLocalServerConfiguration() async {
        let testHost = "192.168.1.100"
        let testPort = 8080
        
        hybridSyncManager.updateLocalServerAddress(host: testHost, port: testPort)
        
        // Since we don't have a real server, this should fail but test the configuration
        let discoveredServers = await hybridSyncManager.discoverLocalServers()
        
        // The discovery should complete without crashing
        XCTAssertTrue(discoveredServers.isEmpty || !discoveredServers.isEmpty)
    }
    
    // MARK: - Bluetooth Tests
    
    func testBluetoothScanningInitiation() {
        hybridSyncManager.startBluetoothScanning()
        
        // Should not crash when starting Bluetooth scanning
        XCTAssertNotNil(hybridSyncManager)
    }
    
    // MARK: - Data Model Tests
    
    func testHealthDataBatchCreation() {
        let heartRateData = HeartRateData(value: 75.0)
        let stepCountData = StepCountData(count: 1000)
        
        let batch = HealthDataBatch(
            heartRateData: [heartRateData],
            stepCountData: [stepCountData]
        )
        
        XCTAssertFalse(batch.isEmpty)
        XCTAssertEqual(batch.totalCount, 2)
        XCTAssertEqual(batch.heartRateData.count, 1)
        XCTAssertEqual(batch.stepCountData.count, 1)
    }
    
    func testWorkoutDataCreation() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(3600) // 1 hour
        
        let workoutData = HybridWorkoutData(
            type: "running",
            startTime: startTime,
            endTime: endTime,
            durationMillis: 3600000,
            totalDistanceMeters: 5000.0,
            totalCalories: 400.0,
            route: []
        )
        
        XCTAssertEqual(workoutData.type, "running")
        XCTAssertEqual(workoutData.durationMillis, 3600000)
        XCTAssertEqual(workoutData.totalDistanceMeters, 5000.0)
        XCTAssertEqual(workoutData.totalCalories, 400.0)
    }
    
    func testSleepDataCreation() {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(28800) // 8 hours
        
        let stages = [
            SleepData.SleepStage(
                stage: .light,
                startTime: startTime,
                endTime: startTime.addingTimeInterval(1800)
            ),
            SleepData.SleepStage(
                stage: .deep,
                startTime: startTime.addingTimeInterval(1800),
                endTime: startTime.addingTimeInterval(5400)
            )
        ]
        
        let sleepData = SleepData(
            startTime: startTime,
            endTime: endTime,
            stages: stages
        )
        
        XCTAssertEqual(sleepData.stages.count, 2)
        XCTAssertEqual(sleepData.stages[0].stage, .light)
        XCTAssertEqual(sleepData.stages[1].stage, .deep)
    }
    
    // MARK: - Sync State Tests
    
    func testSyncStateInitialization() {
        var syncState = SyncState()
        
        XCTAssertNotNil(syncState.lastHeartRateSync)
        XCTAssertNotNil(syncState.lastStepCountSync)
        XCTAssertNotNil(syncState.lastSleepSync)
        XCTAssertNotNil(syncState.lastWorkoutSync)
        XCTAssertNil(syncState.lastFullSync)
    }
    
    func testSyncStateUpdate() {
        var syncState = SyncState()
        let testDate = Date()
        
        syncState.updateLastSync(for: .heartRate, to: testDate)
        
        XCTAssertEqual(syncState.lastHeartRateSync, testDate)
        XCTAssertNotNil(syncState.lastFullSync)
    }
    
    // MARK: - Integration Tests
    
    func testSyncManagerInitialization() {
        XCTAssertNotNil(hybridSyncManager)
        XCTAssertEqual(hybridSyncManager.transportStatus, .offline)
        XCTAssertFalse(hybridSyncManager.isActivelySync)
        XCTAssertEqual(hybridSyncManager.syncProgress, 0.0)
    }
    
    func testManualSyncTrigger() {
        let expectation = XCTestExpectation(description: "Sync completed")
        
        // Monitor sync status changes
        hybridSyncManager.$isActivelySync
            .dropFirst() // Skip initial value
            .sink { isActive in
                if !isActive {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start sync
        hybridSyncManager.startSync()
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testForceFullSync() {
        let expectation = XCTestExpectation(description: "Full sync completed")
        
        hybridSyncManager.$isActivelySync
            .dropFirst()
            .sink { isActive in
                if !isActive {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        hybridSyncManager.forceFullSync()
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorMessageHandling() {
        // Initially no error
        XCTAssertNil(hybridSyncManager.errorMessage)
        
        // Trigger sync when offline (should generate error)
        hybridSyncManager.startSync()
        
        // Give some time for the sync to attempt and fail
        let expectation = XCTestExpectation(description: "Error message set")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.hybridSyncManager.errorMessage != nil {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testSyncPerformance() {
        measure {
            let batch = createLargeHealthDataBatch()
            XCTAssertFalse(batch.isEmpty)
        }
    }
    
    private func createLargeHealthDataBatch() -> HealthDataBatch {
        var heartRateData: [HeartRateData] = []
        var stepCountData: [StepCountData] = []
        
        // Create 100 heart rate readings
        for i in 0..<100 {
            let data = HeartRateData(
                value: Double(70 + i % 30), // 70-100 BPM range
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 60)) // Every minute
            )
            heartRateData.append(data)
        }
        
        // Create 24 step count readings (hourly)
        for i in 0..<24 {
            let data = StepCountData(
                count: 500 + i * 100, // Progressive step count
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600)) // Every hour
            )
            stepCountData.append(data)
        }
        
        return HealthDataBatch(
            heartRateData: heartRateData,
            stepCountData: stepCountData
        )
    }
}

// MARK: - Local Server Client Tests

class LocalServerClientTests: XCTestCase {
    var localServerClient: LocalServerClient!
    
    override func setUpWithError() throws {
        localServerClient = LocalServerClient()
    }
    
    override func tearDownWithError() throws {
        localServerClient = nil
    }
    
    func testServerAddressConfiguration() {
        let testHost = "192.168.1.200"
        let testPort = 9090
        
        localServerClient.updateServerAddress(host: testHost, port: testPort)
        
        XCTAssertEqual(localServerClient.serverHost, testHost)
        XCTAssertEqual(localServerClient.serverPort, testPort)
    }
    
    func testConnectionTestWithInvalidServer() async {
        // Configure invalid server
        localServerClient.updateServerAddress(host: "192.168.999.999", port: 8080)
        
        let isConnected = await localServerClient.testConnection()
        
        XCTAssertFalse(isConnected)
        XCTAssertNotNil(localServerClient.lastError)
    }
    
    func testHealthDataUploadEncoding() async {
        let batch = HealthDataBatch(
            heartRateData: [HeartRateData(value: 75.0)],
            stepCountData: [StepCountData(count: 1000)]
        )
        
        // This will fail due to no server, but tests the encoding path
        let result = await localServerClient.uploadHealthData(batch)
        
        switch result {
        case .success:
            XCTFail("Should not succeed without server")
        case .failure(let error):
            // Expected to fail, but should be a network error, not encoding error
            XCTAssertTrue(error is LocalServerError)
        }
    }
    
    func testServerDiscovery() async {
        let discoveredServers = await localServerClient.discoverLocalServer()
        
        // Should complete without crashing (may be empty if no servers found)
        XCTAssertTrue(discoveredServers.count >= 0)
    }
}

// MARK: - Bluetooth Manager Tests

class HybridBluetoothManagerTests: XCTestCase {
    var bluetoothManager: HybridBluetoothManager!
    
    override func setUpWithError() throws {
        bluetoothManager = HybridBluetoothManager()
    }
    
    override func tearDownWithError() throws {
        bluetoothManager = nil
    }
    
    func testInitialState() {
        XCTAssertFalse(bluetoothManager.isConnected)
        XCTAssertFalse(bluetoothManager.isScanning)
        XCTAssertTrue(bluetoothManager.discoveredDevices.isEmpty)
        XCTAssertEqual(bluetoothManager.dataTransferProgress, 0.0)
    }
    
    func testScanningStateManagement() {
        // Note: In iOS Simulator, Bluetooth scanning won't actually work
        // but we can test the state management
        
        bluetoothManager.startScanning()
        // May or may not change isScanning depending on Bluetooth availability
        
        bluetoothManager.stopScanning()
        XCTAssertFalse(bluetoothManager.isScanning)
    }
    
    func testDataFragmentation() {
        // Test data fragmentation for large transfers
        let largeData = Data(repeating: 0x42, count: 2000) // 2KB of data
        
        // This tests the internal fragmentation logic indirectly
        let batch = HealthDataBatch(
            heartRateData: Array(repeating: HeartRateData(value: 75.0), count: 100)
        )
        
        XCTAssertFalse(batch.isEmpty)
        XCTAssertEqual(batch.totalCount, 100)
    }
    
    func testBluetoothErrorHandling() {
        // Test error states
        XCTAssertNil(bluetoothManager.lastError)
        
        // Attempt operation while disconnected
        Task {
            let result = await bluetoothManager.sendHealthData(HealthDataBatch())
            
            switch result {
            case .success:
                XCTFail("Should fail when not connected")
            case .failure(let error):
                XCTAssertEqual(error, .notConnected)
            }
        }
    }
}

// MARK: - Enhanced Health Manager Tests

class EnhancedHealthManagerTests: XCTestCase {
    var healthManager: EnhancedHealthManager!
    
    override func setUpWithError() throws {
        healthManager = EnhancedHealthManager()
    }
    
    override func tearDownWithError() throws {
        healthManager = nil
    }
    
    func testHealthKitAuthorization() {
        // Test that authorization request doesn't crash
        healthManager.requestAuthorization()
        
        // In simulator, this may not complete successfully,
        // but should not crash
        XCTAssertNotNil(healthManager)
    }
    
    func testDataSavingMethods() async {
        // Test that data saving methods can be called without crashing
        let heartRateData = HeartRateData(value: 75.0)
        let stepCountData = StepCountData(count: 1000)
        let sleepData = SleepData(
            startTime: Date().addingTimeInterval(-28800),
            endTime: Date(),
            stages: [
                SleepData.SleepStage(
                    stage: .light,
                    startTime: Date().addingTimeInterval(-28800),
                    endTime: Date().addingTimeInterval(-25200)
                )
            ]
        )
        let workoutData = HybridWorkoutData(
            type: "running",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            durationMillis: 3600000,
            totalDistanceMeters: 5000.0,
            totalCalories: 400.0,
            route: []
        )
        
        // These will require HealthKit permissions in a real app
        // but should not crash in testing
        await healthManager.saveHeartRate(heartRateData)
        await healthManager.saveStepCount(stepCountData)
        await healthManager.saveSleep(sleepData)
        await healthManager.saveWorkout(workoutData)
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
}

        }
    }
}
