import Foundation
import CoreBluetooth
import Combine

enum BluetoothError: Error, LocalizedError, Equatable {
    case notAuthorized
    case unsupported
    case notConnected
    case encodingError(String)
    case decodingError(String)
    case writeError(String)
    case readError
    case noPeripheralFound
    case connectionFailed
    case characteristicNotFound
    case serviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Bluetooth is not authorized"
        case .unsupported:
            return "Bluetooth LE is not supported"
        case .notConnected:
            return "Not connected to peripheral"
        case .encodingError(let description):
            return "Encoding failed: \(description)"
        case .decodingError(let description):
            return "Decoding failed: \(description)"
        case .writeError(let description):
            return "Write failed: \(description)"
        case .readError:
            return "Read operation failed"
        case .noPeripheralFound:
            return "No peripheral found"
        case .connectionFailed:
            return "Connection failed"
        case .characteristicNotFound:
            return "Characteristic not found"
        case .serviceNotFound:
            return "Service not found"
        }
    }
}

// Extension to chunk data
extension Data {
    func chunked(into size: Int) -> [Data] {
        return stride(from: 0, to: count, by: size).map {
            Data(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// Enhanced Bluetooth manager for hybrid sync with custom GATT service
class HybridBluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isScanning = false
    @Published var connectedDevice: String?
    @Published var isConnected = false
    @Published var lastError: String?
    @Published var isTransferInProgress = false
    @Published var dataTransferProgress: Double = 0.0
    @Published var connectionStatus = "Initializing"
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    private var connectedPeripheral: CBPeripheral?
    @Published var discoveredDevices: [CBPeripheral] = []
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    private var syncStateCharacteristic: CBCharacteristic?
    
    // Data handling
    private var receivedDataFragments: [UInt8: Data] = [:]
    private var expectedFragmentCount: UInt8 = 0
    
    // Async continuations
    private var dataTransferContinuation: CheckedContinuation<Result<Void, BluetoothError>, Never>?
    private var syncStateReadContinuation: CheckedContinuation<Result<SyncState, BluetoothError>, Never>?
    
    // MARK: - Combine subjects
    private let dataReceivedSubject = PassthroughSubject<HealthDataBatch, Never>()
    private let errorSubject = PassthroughSubject<BluetoothError, Never>()
    
    var dataReceived: AnyPublisher<HealthDataBatch, Never> {
        dataReceivedSubject.eraseToAnyPublisher()
    }
    
    var errors: AnyPublisher<BluetoothError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Constants
    private let healthSyncServiceUUID = CBUUID(string: "12345678-1234-5678-9ABC-DEF012345678")
    private let dataCharacteristicUUID = CBUUID(string: "12345678-1234-5678-9ABC-DEF012345679")
    private let syncStateCharacteristicUUID = CBUUID(string: "12345678-1234-5678-9ABC-DEF01234567A")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    func sendHealthData(_ batch: HealthDataBatch) async -> Result<Void, BluetoothError> {
        guard let peripheral = targetPeripheral,
              let characteristic = writeCharacteristic,
              peripheral.state == .connected else {
            return .failure(.notConnected)
        }
        
        do {
            try await sendData(batch)
            return .success(())
        } catch {
            return .failure(.encodingError(error.localizedDescription))
        }
    }
    
    func readSyncState() async -> Result<SyncState, BluetoothError> {
        guard let peripheral = targetPeripheral,
              let characteristic = syncStateCharacteristic,
              peripheral.state == .connected else {
            return .failure(.notConnected)
        }
        
        return await withCheckedContinuation { continuation in
            syncStateReadContinuation = continuation
            peripheral.readValue(for: characteristic)
        }
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth not ready"
            return
        }
        
        isScanning = true
        connectionStatus = "Scanning for devices..."
        discoveredDevices.removeAll()
        
        centralManager.scanForPeripherals(withServices: [healthSyncServiceUUID], options: nil)
    }
    
    func stopScanning() {
        isScanning = false
        connectionStatus = "Stopped scanning"
        centralManager.stopScan()
    }
    
    func connectToDevice(_ peripheral: CBPeripheral) {
        targetPeripheral = peripheral
        connectionStatus = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }
    
    func connect(to peripheral: CBPeripheral) {
        connectToDevice(peripheral)
    }
    
    func requestSyncState() async -> Result<SyncState, BluetoothError> {
        return await readSyncState()
    }
    
    func disconnect() {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        targetPeripheral = nil
        connectedPeripheral = nil
        isConnected = false
        connectionStatus = "Disconnected"
    }
    
    // MARK: - Private Methods
    
    private func sendData(_ data: HealthDataBatch) async throws {
        guard let targetPeripheral = self.targetPeripheral,
              let characteristic = self.writeCharacteristic else {
            throw BluetoothError.noPeripheralFound
        }
        
        do {
            let jsonData = try JSONEncoder().encode(data)
            
            // Fragment data if needed (BLE characteristic limit is typically 512 bytes)
            let chunks = jsonData.chunked(into: 500)
            
            for (index, chunk) in chunks.enumerated() {
                let fragmentHeader = Data([UInt8(index), UInt8(chunks.count)])
                let fragmentData = fragmentHeader + chunk
                
                targetPeripheral.writeValue(fragmentData, for: characteristic, type: .withResponse)
                
                // Wait a bit between chunks
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        } catch {
            throw BluetoothError.encodingError(error.localizedDescription)
        }
    }
    
    private func sendNextFragment(to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Placeholder for fragment management - implement as needed
        print("Sending next fragment...")
    }
    
    private func processIncomingFragment(_ data: Data) {
        // Placeholder for incoming fragment processing - implement as needed
        print("Processing incoming fragment: \(data)")
    }
}

// MARK: - CBCentralManagerDelegate
extension HybridBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth ready"
        case .poweredOff:
            connectionStatus = "Bluetooth is off"
            isConnected = false
        case .resetting:
            connectionStatus = "Bluetooth resetting"
        case .unauthorized:
            connectionStatus = "Bluetooth unauthorized"
        case .unsupported:
            connectionStatus = "Bluetooth unsupported"
        case .unknown:
            connectionStatus = "Bluetooth unknown state"
        @unknown default:
            connectionStatus = "Bluetooth unknown state"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Check if this looks like a Galaxy Watch
        if let name = peripheral.name,
           (name.contains("Galaxy Watch") || name.contains("SM-R")) {
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected - Discovering services"
        peripheral.delegate = self
        peripheral.discoverServices([healthSyncServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Connection failed"
        lastError = error?.localizedDescription
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Disconnected"
        
        if let error = error {
            lastError = error.localizedDescription
        }
        
        // Clear references
        connectedPeripheral = nil
        dataCharacteristic = nil
        syncStateCharacteristic = nil
    }
}

// MARK: - CBPeripheralDelegate

extension HybridBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil,
              let services = peripheral.services else {
            connectionStatus = "Service discovery failed"
            lastError = error?.localizedDescription
            return
        }
        
        for service in services {
            if service.uuid == healthSyncServiceUUID {
                peripheral.discoverCharacteristics([dataCharacteristicUUID, syncStateCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil,
              let characteristics = service.characteristics else {
            connectionStatus = "Characteristic discovery failed"
            lastError = error?.localizedDescription
            return
        }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case dataCharacteristicUUID:
                dataCharacteristic = characteristic
                // Enable notifications for incoming data
                peripheral.setNotifyValue(true, for: characteristic)
                
            case syncStateCharacteristicUUID:
                syncStateCharacteristic = characteristic
                
            default:
                break
            }
        }
        
        if dataCharacteristic != nil && syncStateCharacteristic != nil {
            connectionStatus = "Ready for data sync"
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              let data = characteristic.value else {
            lastError = error?.localizedDescription
            return
        }
        
        switch characteristic.uuid {
        case dataCharacteristicUUID:
            processIncomingFragment(data)
            
        case syncStateCharacteristicUUID:
            do {
                let syncState = try JSONDecoder().decode(SyncState.self, from: data)
                syncStateReadContinuation?.resume(returning: .success(syncState))
                syncStateReadContinuation = nil
            } catch {
                syncStateReadContinuation?.resume(returning: .failure(.decodingError(error.localizedDescription)))
                syncStateReadContinuation = nil
            }
            
        default:
            break
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            isTransferInProgress = false
            dataTransferContinuation?.resume(returning: .failure(.writeError(error.localizedDescription)))
            dataTransferContinuation = nil
            lastError = error.localizedDescription
            return
        }
        
        // Continue sending next fragment
        if characteristic.uuid == dataCharacteristicUUID {
            sendNextFragment(to: peripheral, characteristic: characteristic)
        }
    }
}
