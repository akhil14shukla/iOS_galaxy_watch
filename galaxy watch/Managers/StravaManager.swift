import Foundation
import UIKit

class StravaManager: ObservableObject {
    @Published var isConnected = false
    
    private let clientId = "YOUR_STRAVA_CLIENT_ID"
    private let clientSecret = "YOUR_STRAVA_CLIENT_SECRET"
    private let redirectUri = "galaxywatch://oauth/callback"
    
    private var accessToken: String?
    private var refreshToken: String?
    
    func connect() {
        let scope = "activity:write,activity:read_all"
        let urlString = "https://www.strava.com/oauth/mobile/authorize" +
            "?client_id=\(clientId)" +
            "&redirect_uri=\(redirectUri)" +
            "&response_type=code" +
            "&approval_prompt=auto" +
            "&scope=\(scope)"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            print("Invalid callback URL")
            return
        }
        exchangeCodeForToken(code)
    }
    
    private func exchangeCodeForToken(_ code: String) {
        let tokenUrl = "https://www.strava.com/oauth/token"
        let parameters: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        
        var request = URLRequest(url: URL(string: tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String,
                  let refreshToken = json["refresh_token"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                self?.accessToken = accessToken
                self?.refreshToken = refreshToken
                self?.isConnected = true
            }
        }.resume()
    }
    
    func uploadWorkout(_ workout: WorkoutSession) {
        guard let accessToken = accessToken else { return }
        
        let uploadUrl = "https://www.strava.com/api/v3/activities"
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let parameters: [String: Any] = [
            "name": "Galaxy Watch Workout",
            "type": "Workout",
            "start_date_local": ISO8601DateFormatter().string(from: workout.startTime),
            "elapsed_time": Int(workout.endTime.timeIntervalSince(workout.startTime)),
            "description": "Workout recorded via Galaxy Watch",
            "distance": workout.distance * 1000, // Convert to meters
            "trainer": 0,
            "commute": 0
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error uploading to Strava: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Strava upload status: \(httpResponse.statusCode)")
            }
        }.resume()
    }
}
