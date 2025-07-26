// ContentView.swift
import SwiftUI

struct ContentView: View {
    
    @StateObject private var syncManager = SyncManager()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wave.3.right.circle.fill")
                .imageScale(.large)
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Galaxy Watch Sync")
                .font(.title)
                .bold()

            // --- UI CHANGES START HERE ---

            if syncManager.userID == nil {
                // If there is no user, show the sign-in button.
                Button(action: {
                    syncManager.createAndSignInUser()
                }) {
                    Text("1. Sign In & Generate ID")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                // If we have a user, show the ID and next steps.
                Text("Pairing ID:")
                    .font(.headline)
                
                Text(syncManager.userID ?? "No ID")
                    .font(.system(.footnote, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Text("Enter this ID into your Galaxy Watch app.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Divider()

            Button(action: {
                syncManager.requestHealthKitAuthorization()
            }) {
                Text("2. Connect to Apple Health")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            // --- UI CHANGES END HERE ---
        }
        .padding()
    }
}
