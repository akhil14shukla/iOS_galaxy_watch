//
//  galaxy_watchApp.swift
//  galaxy watch
//
//  Created by Akhil on 26/07/25.
//

import SwiftUI
import FirebaseCore // Import Firebase

@main
struct galaxy_watchApp: App {
    // Add this initializer
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
