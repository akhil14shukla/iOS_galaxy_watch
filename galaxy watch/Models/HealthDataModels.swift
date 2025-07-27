import Foundation
import CoreLocation

// MARK: - Health Data Models for Hybrid Sync

/// Generic health data point with timestamp for stateful syncing
protocol HealthDataPoint: Codable {
    var timestamp: Date { get }
    var id: String { get }
}

/// Heart rate data point
struct HeartRateData: HealthDataPoint {
    let id: String
    let timestamp: Date
    let value: Double // BPM
    let confidence: Double? // Optional confidence level
    
    init(value: Double, timestamp: Date = Date(), confidence: Double? = nil) {
        self.id = UUID().uuidString
        self.value = value
        self.timestamp = timestamp
        self.confidence = confidence
    }
}

/// Step count data point
struct StepCountData: HealthDataPoint {
    let id: String
    let timestamp: Date
    let count: Int
    let duration: TimeInterval? // Optional duration for the step count
    
    init(count: Int, timestamp: Date = Date(), duration: TimeInterval? = nil) {
        self.id = UUID().uuidString
        self.count = count
        self.timestamp = timestamp
        self.duration = duration
    }
}

/// Sleep data
struct SleepData: HealthDataPoint {
    let id: String
    let timestamp: Date
    let startTime: Date
    let endTime: Date
    let stages: [SleepStage]
    
    struct SleepStage: Codable {
        let stage: SleepStageType
        let startTime: Date
        let endTime: Date
    }
    
    enum SleepStageType: String, Codable {
        case awake = "AWAKE"
        case light = "LIGHT"
        case deep = "DEEP"
        case rem = "REM"
        case unknown = "UNKNOWN"
    }
    
    init(startTime: Date, endTime: Date, stages: [SleepStage]) {
        self.id = UUID().uuidString
        self.timestamp = startTime
        self.startTime = startTime
        self.endTime = endTime
        self.stages = stages
    }
}

/// Workout data with GPS route  
struct HybridWorkoutData: HealthDataPoint {
    let id: String
    let timestamp: Date
    let type: WorkoutType
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let totalDistance: Double // meters
    let totalCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let route: [LocationPoint]
    
    struct LocationPoint: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double?
        let timestamp: Date
        let speed: Double?
        let accuracy: Double?
        
        var clLocation: CLLocation {
            let location = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude ?? 0,
                horizontalAccuracy: accuracy ?? 5.0,
                verticalAccuracy: accuracy ?? 5.0,
                timestamp: timestamp
            )
            return location
        }
    }
    
    enum WorkoutType: String, Codable {
        case running = "RUNNING"
        case walking = "WALKING"
        case cycling = "CYCLING"
        case swimming = "SWIMMING"
        case other = "OTHER"
    }
    
    init(type: WorkoutType, startTime: Date, endTime: Date, totalDistance: Double, totalCalories: Double, route: [LocationPoint] = [], averageHeartRate: Double? = nil, maxHeartRate: Double? = nil) {
        self.id = UUID().uuidString
        self.timestamp = startTime
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.duration = endTime.timeIntervalSince(startTime)
        self.totalDistance = totalDistance
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.route = route
    }
}

/// Batch of health data for efficient transfer
struct HealthDataBatch: Codable {
    let id: String
    let timestamp: Date
    let heartRateData: [HeartRateData]
    let stepCountData: [StepCountData]
    let sleepData: [SleepData]
    let workoutData: [HybridWorkoutData]
    
    init(heartRateData: [HeartRateData] = [], stepCountData: [StepCountData] = [], sleepData: [SleepData] = [], workoutData: [HybridWorkoutData] = []) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.heartRateData = heartRateData
        self.stepCountData = stepCountData
        self.sleepData = sleepData
        self.workoutData = workoutData
    }
    
    var isEmpty: Bool {
        return heartRateData.isEmpty && stepCountData.isEmpty && sleepData.isEmpty && workoutData.isEmpty
    }
    
    var totalCount: Int {
        return heartRateData.count + stepCountData.count + sleepData.count + workoutData.count
    }
}

/// Sync state for tracking last successful sync
struct SyncState: Codable {
    var lastHeartRateSync: Date?
    var lastStepCountSync: Date?
    var lastSleepSync: Date?
    var lastWorkoutSync: Date?
    var lastFullSync: Date?
    
    init() {
        // Initialize with epoch time to sync all historical data on first run
        let epoch = Date(timeIntervalSince1970: 0)
        self.lastHeartRateSync = epoch
        self.lastStepCountSync = epoch
        self.lastSleepSync = epoch
        self.lastWorkoutSync = epoch
        self.lastFullSync = nil
    }
    
    mutating func updateLastSync(for dataType: DataType, to date: Date) {
        switch dataType {
        case .heartRate:
            lastHeartRateSync = date
        case .stepCount:
            lastStepCountSync = date
        case .sleep:
            lastSleepSync = date
        case .workout:
            lastWorkoutSync = date
        }
        lastFullSync = Date()
    }
    
    enum DataType {
        case heartRate, stepCount, sleep, workout
    }
}

/// Transport layer status
enum TransportStatus: String, Codable {
    case localServer = "LOCAL_SERVER"
    case bluetooth = "BLUETOOTH"
    case offline = "OFFLINE"
    case error = "ERROR"
}

/// Sync status with transport information
struct HybridSyncStatus: Codable {
    let timestamp: Date
    let transport: TransportStatus
    let isActive: Bool
    let lastSyncTime: Date?
    let errorMessage: String?
    let pendingDataCount: Int
    
    init(transport: TransportStatus, isActive: Bool = false, lastSyncTime: Date? = nil, errorMessage: String? = nil, pendingDataCount: Int = 0) {
        self.timestamp = Date()
        self.transport = transport
        self.isActive = isActive
        self.lastSyncTime = lastSyncTime
        self.errorMessage = errorMessage
        self.pendingDataCount = pendingDataCount
    }
}
