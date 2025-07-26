//
//  SyncManager.swift
//  galaxy watch
//
//  Created by Akhil on 26/07/25.
//
import Foundation
import HealthKit
import CoreLocation // For GPS data
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

// --- NEW SWIFT DATA STRUCTURES (must match Kotlin exactly) ---

struct LocationData: Decodable {
    let latitude: Double
    let longitude: Double
    let time: Date
}

struct WorkoutData: Decodable {
    let type: String
    let startTime: Date
    let endTime: Date
    let durationMillis: Int
    let totalDistanceMeters: Double
    let totalCalories: Double
    let route: [LocationData]
}

struct SleepStage: Decodable {
    let stage: String
    let startTime: Date
    let endTime: Date
}

struct SleepSession: Decodable {
    let startTime: Date
    let endTime: Date
    let stages: [SleepStage]
}


struct HeartRateDataPoint {
    let value: Double
    let date: Date

    init?(from dictionary: [String: Any]) {
        guard let value = dictionary["value"] as? Double,
              let timestamp = dictionary["date"] as? Timestamp else {
            return nil
        }
        self.value = value
        self.date = timestamp.dateValue()
    }
}

class SyncManager: ObservableObject {
    @Published var healthKitStatus: String = "Not Connected"
    @Published var firebaseStatus: String = "Not Signed In"
    @Published var lastSyncStatus: String = "Awaiting sync..."
    @Published var userID: String?

    private var healthStore = HKHealthStore()
    private var db = Firestore.firestore()
    private var firestoreListener: ListenerRegistration?

    init() {
        checkCurrentUser()
    }

    // --- EXPANDED PERMISSIONS ---
    private var dataTypesToWrite: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType(),
        HKObjectType.seriesType(forIdentifier: HKWorkoutRouteTypeIdentifier)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    
    // --- NEW LISTENERS ---
    private var workoutListener: ListenerRegistration?
    private var sleepListener: ListenerRegistration?
    
    func startListening() {
        startListeningForWorkouts()
        startListeningForSleep()
    }

    // --- NEW: WORKOUT LISTENER ---
    func startListeningForWorkouts() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let collectionPath = "users/\(userID)/workouts"
        
        workoutListener = db.collection(collectionPath)
            .whereField("processed", isEqualTo: false)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                // ... (logic to decode WorkoutData and call a new save function)
                // self.processAndSaveWorkout(decodedWorkouts)
            }
    }

    // --- NEW: SLEEP LISTENER ---
    func startListeningForSleep() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let collectionPath = "users/\(userID)/sleep"

        sleepListener = db.collection(collectionPath)
            .whereField("processed", isEqualTo: false)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                // ... (logic to decode SleepSession and call a new save function)
                // self.processAndSaveSleep(decodedSessions)
            }
    }

    // --- NEW: SAVE WORKOUT TO HEALTHKIT ---
    private func processAndSaveWorkout(_ workouts: [(String, WorkoutData)]) {
        for (docID, workoutData) in workouts {
            // 1. Create HKWorkout object with distance and calories
            // 2. Create HKWorkoutRouteBuilder
            // 3. Convert [LocationData] to [CLLocation] and append to builder
            // 4. Save workout, then save route with workout
            // 5. Mark as processed in Firestore
        }
    }
    
    // --- NEW: SAVE SLEEP TO HEALTHKIT ---
    private func processAndSaveSleep(_ sessions: [(String, SleepSession)]) {
        for (docID, sessionData) in sessions {
            var sleepSamples: [HKCategorySample] = []
            // 1. Create HKCategorySample for the overall session (.inBed)
            // 2. Loop through sessionData.stages
            // 3. Map stage string ("AWAKE", "REM", etc.) to HKCategoryValueSleepAnalysis
            // 4. Create HKCategorySample for each stage
            // 5. Save all samples to HealthKit
            // 6. Mark as processed in Firestore
        }
    }


    // MARK: - HealthKit Authorization
    func requestHealthKitAuthorization() {
        if !HKHealthStore.isHealthDataAvailable() {
            DispatchQueue.main.async { self.healthKitStatus = "Not Available" }
            return
        }

        healthStore.requestAuthorization(toShare: dataTypesToWrite, read: []) { (success, error) in
            DispatchQueue.main.async {
                self.healthKitStatus = success ? "Authorization Granted!" : "Authorization Denied"
            }
        }
    }

    // MARK: - Firebase Authentication
    func checkCurrentUser() {
            if let user = Auth.auth().currentUser {
                self.userID = user.uid // Update the published property
                DispatchQueue.main.async {
                    self.firebaseStatus = "Signed In"
                }
                startListeningForHealthData()
            }
        }
    
    // THIS IS THE KEY CHANGE FOR iOS:
        // This function will now be the ONLY way to sign in, ensuring one user.
        func createAndSignInUser() {
            guard Auth.auth().currentUser == nil else {
                print("User is already signed in.")
                startListeningForHealthData()
                return
            }
            
            Auth.auth().signInAnonymously { [weak self] (authResult, error) in
                guard let self = self else { return }
                
                if let user = authResult?.user {
                    self.userID = user.uid // Capture the new User ID
                    DispatchQueue.main.async {
                        self.firebaseStatus = "Signed In"
                    }
                    self.startListeningForHealthData()
                } else {
                    DispatchQueue.main.async {
                        self.firebaseStatus = "Sign In Failed"
                    }
                }
            }
        }

    // MARK: - Firestore Data Syncing
    func startListeningForHealthData() {
        guard let userID = Auth.auth().currentUser?.uid else {
            DispatchQueue.main.async { self.lastSyncStatus = "Error: Not signed in." }
            return
        }

        stopListening()

        let collectionPath = "users/fbI4t1uVwVXak0gJYJW3SnlDVln1/heartRate"

        firestoreListener = db.collection(collectionPath)
            .whereField("processed", isEqualTo: false)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async { self.lastSyncStatus = "Listener Error!" }
                    print("🔴 Firestore Listener Error: \(error.localizedDescription)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    return
                }

                // Use our custom initializer here
                let dataPoints = documents.compactMap { doc -> (String, HeartRateDataPoint)? in
                    if let dataPoint = HeartRateDataPoint(from: doc.data()) {
                        return (doc.documentID, dataPoint)
                    } else {
                        print("🔴 Decoding Error for document \(doc.documentID)")
                        return nil
                    }
                }

                if !dataPoints.isEmpty {
                    self.processAndSaveHealthData(dataPoints)
                }
            }
        DispatchQueue.main.async { self.lastSyncStatus = "Listening for data..." }
    }

    private func processAndSaveHealthData(_ dataPoints: [(String, HeartRateDataPoint)]) {
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        let samples = dataPoints.map { (_, dataPoint) -> HKQuantitySample in
            let quantity = HKQuantity(unit: hrUnit, doubleValue: dataPoint.value)
            return HKQuantitySample(type: hrType, quantity: quantity, start: dataPoint.date, end: dataPoint.date)
        }

        healthStore.save(samples) { [weak self] (success, error) in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if success {
                    self.lastSyncStatus = "✅ Successfully synced \(samples.count) new data points."
                    print("✅ \(self.lastSyncStatus)")
                    self.markDataAsProcessed(documentIDs: dataPoints.map { $0.0 })
                } else {
                    self.lastSyncStatus = "❌ Failed to save to HealthKit."
                    if let error = error {
                        print("🔴 HealthKit Save Error Details: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func markDataAsProcessed(documentIDs: [String]) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let collectionPath = "users/\(userID)/heartRate"

        let batch = db.batch()
        for docID in documentIDs {
            let docRef = db.collection(collectionPath).document(docID)
            batch.updateData(["processed": true], forDocument: docRef)
        }

        batch.commit()
    }

    func stopListening() {
        firestoreListener?.remove()
        firestoreListener = nil
        print("Stopped Firestore listener.")
    }
}
