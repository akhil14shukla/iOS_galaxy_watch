//
//  galaxy_watchTests.swift
//  galaxy watchTests
//
//  Created by Akhil on 26/07/25.
//

import XCTest
@testable import galaxy_watch

class galaxy_watchTests: XCTestCase {
    var hybridSyncManager: HybridSyncManager!
    
    override func setUpWithError() throws {
        hybridSyncManager = HybridSyncManager()
    }
    
    override func tearDownWithError() throws {
        hybridSyncManager = nil
    }
    
    // MARK: - Basic Sync Manager Tests
    
    func testHybridSyncManagerInitialization() throws {
        XCTAssertNotNil(hybridSyncManager)
        XCTAssertEqual(hybridSyncManager.currentTransport, .local)
    }
    
    func testSyncStateInitialization() throws {
        let syncState = SyncState()
        XCTAssertEqual(syncState.lastSyncTimestamp, Date.distantPast)
        XCTAssertEqual(syncState.pendingUploads, 0)
        XCTAssertEqual(syncState.successfulSyncs, 0)
        XCTAssertEqual(syncState.failedSyncs, 0)
    }
    
    func testHealthDataModels() throws {
        let heartRateData = HeartRateData(
            timestamp: Date(),
            value: 75.0,
            deviceId: "test-device"
        )
        
        XCTAssertEqual(heartRateData.value, 75.0)
        XCTAssertEqual(heartRateData.deviceId, "test-device")
        
        let stepData = StepCountData(
            timestamp: Date(),
            value: 10000,
            deviceId: "test-device"
        )
        
        XCTAssertEqual(stepData.value, 10000)
        XCTAssertEqual(stepData.deviceId, "test-device")
    }
    
    func testWorkoutDataModel() throws {
        let workoutData = HybridWorkoutData(
            type: "running",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            durationMillis: 3600000,
            totalDistanceMeters: 5000.0,
            totalCalories: 300.0,
            route: []
        )
        
        XCTAssertEqual(workoutData.type, "running")
        XCTAssertEqual(workoutData.totalDistanceMeters, 5000.0)
        XCTAssertEqual(workoutData.totalCalories, 300.0)
    }
    
    func testHealthDataBatch() throws {
        let heartRateData = HeartRateData(
            timestamp: Date(),
            value: 75.0,
            deviceId: "test-device"
        )
        
        let stepData = StepCountData(
            timestamp: Date(),
            value: 10000,
            deviceId: "test-device"
        )
        
        let batch = HealthDataBatch(
            timestamp: Date(),
            deviceId: "test-device",
            heartRateData: [heartRateData],
            stepCountData: [stepData],
            sleepData: [],
            workoutData: []
        )
        
        XCTAssertEqual(batch.heartRateData.count, 1)
        XCTAssertEqual(batch.stepCountData.count, 1)
        XCTAssertEqual(batch.sleepData.count, 0)
        XCTAssertEqual(batch.workoutData.count, 0)
    }
}
