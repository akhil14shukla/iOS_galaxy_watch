import Foundation

struct SensorData {
    var heartRate: Int = 0
    var steps: Int = 0
    var distance: Double = 0.0
    var calories: Int = 0
    var timestamp: Date = Date()
}

struct WorkoutSession: Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date
    let heartRateReadings: [HeartRateReading]
    let stepCount: Int
    let distance: Double
    let calories: Int
    
    struct HeartRateReading: Codable {
        let timestamp: Date
        let value: Int
    }
}

struct GalaxyNotification: Codable {
    let id: String
    let title: String
    let body: String
    let timestamp: Date
    let appBundleId: String
}

struct CallLog: Codable {
    let id: UUID
    let phoneNumber: String
    let duration: TimeInterval
    let timestamp: Date
    let type: CallType
    
    enum CallType: String, Codable {
        case incoming
        case outgoing
        case missed
    }
}

struct MessageLog: Codable {
    let id: UUID
    let sender: String
    let content: String
    let timestamp: Date
    let isRead: Bool
}

// Watch Connection Status
struct WatchConnectionStatus: Codable {
    var isConnected: Bool
    var batteryLevel: Int
    var lastSyncTime: Date
    var syncStatus: SyncStatus
    
    enum SyncStatus: String, Codable {
        case syncing
        case synced
        case failed
        case idle
    }
}
