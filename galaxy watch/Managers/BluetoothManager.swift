import Foundation
import CoreBluetooth

class BluetoothManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var sensorData = SensorData()
    @Published var isScanning = false
    @Published var watchStatus = WatchConnectionStatus(
        isConnected: false,
        batteryLevel: 0,
        lastSyncTime: Date(),
        syncStatus: .idle
    )
    
    private var centralManager: CBCentralManager?
    private var galaxyWatch: CBPeripheral?
    private var characteristics: [String: CBCharacteristic] = [:]
    
    // Galaxy Watch 4 Service and Characteristic UUIDs
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")
    private let stepCountServiceUUID = CBUUID(string: "181C")
    private let stepCountCharacteristicUUID = CBUUID(string: "2A53")
    private let distanceServiceUUID = CBUUID(string: "181E")
    private let distanceCharacteristicUUID = CBUUID(string: "2A58")
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    private let notificationServiceUUID = CBUUID(string: "1805")
    private let notificationCharacteristicUUID = CBUUID(string: "2A2B")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForwardNotification),
            name: NSNotification.Name("ForwardNotificationToWatch"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCallLogSync),
            name: NSNotification.Name("SyncCallLogToWatch"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMessageLogSync),
            name: NSNotification.Name("SyncMessageLogToWatch"),
            object: nil
        )
    }
    
    @objc private func handleForwardNotification(_ notification: Notification) {
        guard let galaxyNotification = notification.object as? GalaxyNotification else { return }
        sendNotificationToWatch(galaxyNotification)
    }
    
    @objc private func handleCallLogSync(_ notification: Notification) {
        guard let callLog = notification.object as? CallLog else { return }
        sendCallLogToWatch(callLog)
    }
    
    @objc private func handleMessageLogSync(_ notification: Notification) {
        guard let messageLog = notification.object as? MessageLog else { return }
        sendMessageLogToWatch(messageLog)
    }
    
    private func sendNotificationToWatch(_ notification: GalaxyNotification) {
        guard let characteristic = characteristics["notification"],
              let data = try? JSONEncoder().encode(notification) else { return }
        
        galaxyWatch?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    private func sendCallLogToWatch(_ callLog: CallLog) {
        guard let characteristic = characteristics["callLog"],
              let data = try? JSONEncoder().encode(callLog) else { return }
        
        galaxyWatch?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    private func sendMessageLogToWatch(_ messageLog: MessageLog) {
        guard let characteristic = characteristics["messageLog"],
              let data = try? JSONEncoder().encode(messageLog) else { return }
        
        galaxyWatch?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    func startScanning() {
        guard let manager = centralManager else { return }
        
        if manager.state == .poweredOn {
            manager.scanForPeripherals(
                withServices: [heartRateServiceUUID, stepCountServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
        }
    }
    
    func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }
    
    private func connect(to peripheral: CBPeripheral) {
        galaxyWatch = peripheral
        centralManager?.connect(peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
            isConnected = false
        default:
            print("Bluetooth state: \(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Check if this is our Galaxy Watch
        if peripheral.name?.contains("Galaxy Watch") == true {
            connect(to: peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices([heartRateServiceUUID, stepCountServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        // Attempt to reconnect
        if let galaxy = galaxyWatch {
            connect(to: galaxy)
        }
    }
}

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        service.characteristics?.forEach { characteristic in
            switch characteristic.uuid {
            case notificationCharacteristicUUID:
                characteristics["notification"] = characteristic
            case batteryLevelCharacteristicUUID:
                characteristics["battery"] = characteristic
                peripheral.readValue(for: characteristic)
            default:
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        switch characteristic.uuid {
        case heartRateMeasurementCharacteristicUUID:
            updateHeartRate(from: data)
        case stepCountCharacteristicUUID:
            updateStepCount(from: data)
        case distanceCharacteristicUUID:
            updateDistance(from: data)
        case batteryLevelCharacteristicUUID:
            updateBatteryLevel(from: data)
        default:
            break
        }
    }
    
    private func updateBatteryLevel(from data: Data) {
        guard data.count >= 1 else { return }
        let batteryLevel = Int(data[0])
        watchStatus.batteryLevel = batteryLevel
    }
    
    private func updateHeartRate(from data: Data) {
        // Implementation of heart rate data processing based on BLE specification
        // This is a simplified version
        let bytes = [UInt8](data)
        if bytes[0] & 0x01 == 0 {
            sensorData.heartRate = Int(bytes[1])
        } else {
            sensorData.heartRate = Int(bytes[1]) | (Int(bytes[2]) << 8)
        }
    }
    
    private func updateStepCount(from data: Data) {
        // Implementation of step count data processing
        // This is a simplified version
        let bytes = [UInt8](data)
        sensorData.steps = Int(bytes[1]) | (Int(bytes[2]) << 8)
    }
    
    private func updateDistance(from data: Data) {
        // Implementation of distance data processing
        // This is a simplified version
        let bytes = [UInt8](data)
        sensorData.distance = Double(Int(bytes[1]) | (Int(bytes[2]) << 8))
    }
}
