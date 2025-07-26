import Foundation
import UIKit

class StravaManager: ObservableObject {
    static let shared = StravaManager()
    
    private let clientId = "YOUR_STRAVA_CLIENT_ID"
    private let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
    private let redirectUri = "your-app-scheme://strava-auth"
    
    @Published var isAuthenticated = false
    private var accessToken: String?
    
    private init() {
        // Check for existing authentication
        if let token = UserDefaults.standard.string(forKey: "StravaAccessToken") {
            accessToken = token
            isAuthenticated = true
        }
    }
    
    func authenticate() {
        guard let authUrl = URL(string: "https://www.strava.com/oauth/authorize?client_id=\(clientId)&response_type=code&redirect_uri=\(redirectUri)&scope=activity:write,read") else { return }
        
        // Open authentication URL in Safari
        UIApplication.shared.open(authUrl)
    }
    
    func handleAuthCallback(url: URL) {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else { return }
        
        exchangeCodeForToken(code)
    }
    
    private func exchangeCodeForToken(_ code: String) {
        let tokenUrl = "https://www.strava.com/oauth/token"
        let parameters = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        // Implement token exchange request
        // Store token in UserDefaults when received
    }
    
    func updateHeartRate(_ heartRate: Double) {
        // Cache heart rate data for workout upload
    }
    
    func uploadWorkout(heartRate: Double, distance: Double, duration: TimeInterval) {
        guard let accessToken = accessToken else { return }
        
        let uploadUrl = "https://www.strava.com/api/v3/activities"
        let parameters: [String: Any] = [
            "name": "Galaxy Watch Workout",
            "type": "Run",
            "start_date_local": ISO8601DateFormatter().string(from: Date()),
            "elapsed_time": Int(duration),
            "distance": distance,
            "heart_rate": heartRate
        ]
        
        // Implement workout upload request
    }
}
