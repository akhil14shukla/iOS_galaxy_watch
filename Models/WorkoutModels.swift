import Foundation

struct GalaxyNotification {
    let id: String
    let title: String
    let body: String
    let timestamp: Date
    let appBundleId: String
}

struct WorkoutSession {
    struct HeartRateReading {
        let timestamp: Date
        let value: Int
    }
    
    let id: UUID
    let startTime: Date
    let endTime: Date
    let heartRateReadings: [HeartRateReading]
    let stepCount: Int
    let distance: Double
    let calories: Int
}
