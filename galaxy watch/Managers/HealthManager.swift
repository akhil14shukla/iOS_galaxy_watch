import Foundation
import HealthKit

class HealthManager: ObservableObject {
    @Published var isHealthKitEnabled = false
    
    private let healthStore = HKHealthStore()
    private let requiredTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
    ]
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        // Define the types we want to read from HealthKit
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isHealthKitEnabled = success
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveSensorData(_ data: SensorData) {
        guard isHealthKitEnabled else { return }
        
        // Save heart rate
        if data.heartRate > 0 {
            let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
            let heartRateQuantity = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: Double(data.heartRate))
            let heartRateSample = HKQuantitySample(type: heartRateType,
                                                 quantity: heartRateQuantity,
                                                 start: data.timestamp,
                                                 end: data.timestamp)
            
            healthStore.save(heartRateSample) { success, error in
                if let error = error {
                    print("Error saving heart rate: \(error.localizedDescription)")
                }
            }
        }
        
        // Save steps
        if data.steps > 0 {
            let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
            let stepsQuantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(data.steps))
            let stepsSample = HKQuantitySample(type: stepsType,
                                             quantity: stepsQuantity,
                                             start: data.timestamp,
                                             end: data.timestamp)
            
            healthStore.save(stepsSample) { success, error in
                if let error = error {
                    print("Error saving steps: \(error.localizedDescription)")
                }
            }
        }
        
        // Save distance
        if data.distance > 0 {
            let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
            let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: data.distance * 1000) // Convert km to meters
            let distanceSample = HKQuantitySample(type: distanceType,
                                                quantity: distanceQuantity,
                                                start: data.timestamp,
                                                end: data.timestamp)
            
            healthStore.save(distanceSample) { success, error in
                if let error = error {
                    print("Error saving distance: \(error.localizedDescription)")
                }
            }
        }
        
        // Save calories
        if data.calories > 0 {
            let caloriesType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
            let caloriesQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: Double(data.calories))
            let caloriesSample = HKQuantitySample(type: caloriesType,
                                                quantity: caloriesQuantity,
                                                start: data.timestamp,
                                                end: data.timestamp)
            
            healthStore.save(caloriesSample) { success, error in
                if let error = error {
                    print("Error saving calories: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func syncWorkout(_ workout: WorkoutSession, completion: @escaping (Bool) -> Void) {
        guard isHealthKitEnabled else {
            completion(false)
            return
        }
        
        // Create workout
        let workoutConfig = HKWorkoutConfiguration()
        workoutConfig.activityType = .running
        
        // Create workout using HKWorkoutBuilder (recommended approach)
        let workoutBuilder = HKWorkoutBuilder(healthStore: healthStore, configuration: workoutConfig, device: .local())
        
        // Set workout dates
        workoutBuilder.beginCollection(withStart: workout.startTime) { success, error in
            if let error = error {
                print("Error beginning workout collection: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            workoutBuilder.endCollection(withEnd: workout.endTime) { success, error in
                if let error = error {
                    print("Error ending workout collection: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                workoutBuilder.finishWorkout { finishedWorkout, error in
                    if let error = error {
                        print("Error finishing workout: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let finishedWorkout = finishedWorkout else {
                        completion(false)
                        return
                    }
                    
                    // Save heart rate samples
                    self.saveHeartRateSamples(workout.heartRateReadings, workout: finishedWorkout) { success in
                        completion(success)
                    }
                }
            }
        }
    }
    
    private func saveHeartRateSamples(_ readings: [WorkoutSession.HeartRateReading], workout: HKWorkout, completion: @escaping (Bool) -> Void) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let unit = HKUnit.count().unitDivided(by: .minute())
        
        let samples = readings.map { reading in
            HKQuantitySample(
                type: heartRateType,
                quantity: HKQuantity(unit: unit, doubleValue: Double(reading.value)),
                start: reading.timestamp,
                end: reading.timestamp,
                device: .local(),
                metadata: [HKMetadataKeyWasUserEntered: false]
            )
        }
        
        healthStore.save(samples) { success, error in
            if let error = error {
                print("Error saving heart rate samples: \(error.localizedDescription)")
                completion(false)
                return
            }
            completion(true)
        }
    }
}
