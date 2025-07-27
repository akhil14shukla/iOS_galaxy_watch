//
//  galaxy_watchApp.swift
//  galaxy watch
//
//  Created by Akhil on 26/07/25.
//

import SwiftUI
import FirebaseCore // Import Firebase for legacy sync support

@main
struct galaxy_watchApp: App {
    // Initialize Firebase for backward compatibility
    // Note: Firebase is kept for potential legacy data migration
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request necessary permissions on app launch
                    requestAppPermissions()
                }
        }
    }
    
    private func requestAppPermissions() {
        // Request HealthKit permissions
        let syncManager = HybridSyncManager()
        syncManager.requestAuthorization()
        
        // Additional permission requests can be added here
        print("Galaxy Watch Hybrid Sync initialized")
    }
}
