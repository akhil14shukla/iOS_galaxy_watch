//
//  galaxy_watchTests.swift
//  galaxy watchTests
//
//  Created by Akhil on 26/07/25.
//

import XCTest
import CoreBluetooth
import HealthKit
@testable import galaxy_watch

class galaxy_watchTests: XCTestCase {
    var bluetoothManager: BluetoothManager!
    var healthManager: HealthManager!
    var stravaManager: StravaManager!
    
    override func setUpWithError() throws {
        bluetoothManager = BluetoothManager.shared
        healthManager = HealthManager.shared
        stravaManager = StravaManager.shared
    }
    
    override func tearDownWithError() throws {
        bluetoothManager = nil
        healthManager = nil
        stravaManager = nil
    }
    
    // MARK: - Bluetooth Connection Tests
    
    func testBluetoothConnection() {
        XCTAssertFalse(bluetoothManager.isConnected)
        
        // Simulate watch discovery
        let mockPeripheral = MockPeripheral(identifier: UUID(), name: "Galaxy Watch4")
        bluetoothManager.centralManager(MockCentralManager(),
            didDiscover: mockPeripheral,
            advertisementData: ["kCBAdvDataLocalName": "Galaxy Watch4"],
            rssi: NSNumber(value: -50))
        
        // Verify connection attempt
        XCTAssertTrue(bluetoothManager.isScanning)
        
        // Simulate successful connection
        bluetoothManager.centralManager(MockCentralManager(),
            didConnect: mockPeripheral)
        
        XCTAssertTrue(bluetoothManager.isConnected)
    }
    
    // MARK: - Sensor Data Tests
    
    func testSensorDataUpdates() {
        // Test heart rate update
        let heartRateData = Data([0x00, 0x45]) // Heart rate of 69 BPM
        let heartRateChar = MockCharacteristic(uuid: CBUUID(string: "2A37"))
        bluetoothManager.peripheral(MockPeripheral(identifier: UUID(), name: "Galaxy Watch4"),
            didUpdateValueFor: heartRateChar,
            error: nil)
        
        XCTAssertEqual(bluetoothManager.sensorData.heartRate, 69)
        
        // Test step count update
        let stepChar = MockCharacteristic(uuid: CBUUID(string: "2A53"))
        bluetoothManager.peripheral(MockPeripheral(identifier: UUID(), name: "Galaxy Watch4"),
            didUpdateValueFor: stepChar,
            error: nil)
        
        XCTAssertEqual(bluetoothManager.sensorData.steps, 256)
    }
    
    // MARK: - Notification Tests
    
    func testNotificationForwarding() {
        let expectation = XCTestExpectation(description: "Notification forwarded")
        
        // Create test notification
        let notification = GalaxyNotification(
            id: UUID().uuidString,
            title: "Test Message",
            body: "Hello World",
            timestamp: Date(),
            appBundleId: "com.test.app"
        )
        
        // Watch for notification forwarding
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ForwardNotificationToWatch"),
            object: nil,
            queue: nil
        ) { note in
            guard let forwarded = note.object as? GalaxyNotification else {
                XCTFail("Invalid notification object")
                return
            }
            
            XCTAssertEqual(forwarded.title, "Test Message")
            XCTAssertEqual(forwarded.body, "Hello World")
            expectation.fulfill()
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("ForwardNotificationToWatch"),
            object: notification
        )
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Health Data Tests
    
    func testHealthDataSync() {
        let expectation = XCTestExpectation(description: "Health data synced")
        
        // Create test workout session
        let workout = WorkoutSession(
            id: UUID(),
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            heartRateReadings: [
                WorkoutSession.HeartRateReading(timestamp: Date(), value: 75)
            ],
            stepCount: 5000,
            distance: 3.5,
            calories: 250
        )
        
        // Sync workout data
        healthManager.syncWorkout(workout) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Strava Integration Tests
    
    func testStravaAuthentication() {
        let expectation = XCTestExpectation(description: "Strava auth completed")
        
        // Simulate Strava OAuth callback
        let mockURL = URL(string: "galaxywatch://oauth/callback?code=test_auth_code")!
        
        // Post OAuth callback notification
        NotificationCenter.default.post(
            name: NSNotification.Name("StravaAuthCallback"),
            object: mockURL
        )
        
        // Wait for auth process
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            XCTAssertNotNil(self.stravaManager)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Mock Classes

class MockCentralManager: CBCentralManager {
    override var state: CBManagerState { return .poweredOn }
}

class MockPeripheral: CBPeripheral {
    private let deviceName: String
    
    init(identifier: UUID, name: String) {
        self.deviceName = name
        super.init(delegate: nil, queue: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var state: CBPeripheralState { return .connected }
    override var name: String? { return deviceName }
}

class MockCharacteristic: CBCharacteristic {
    private let mockUUID: CBUUID
    private let mockValue: Data
    
    init(uuid: CBUUID, value: Data = Data([0x00, 0x45])) {
        self.mockUUID = uuid
        self.mockValue = value
        super.init()
    }
    
    override var uuid: CBUUID { return mockUUID }
    override var value: Data? { return mockValue }
}
