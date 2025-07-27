import Foundation
import Network
import Combine

/// Local server client for HTTP-based data synchronization
class LocalServerClient: ObservableObject {
    @Published var isConnected = false
    @Published var serverHost = "192.168.1.100" // Default local IP
    @Published var serverPort = 8080
    @Published var lastError: String?
    
    private var urlSession: URLSession
    private var monitor: NWPathMonitor?
    private var monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.urlSession = URLSession(configuration: config)
        
        startNetworkMonitoring()
    }
    
    deinit {
        monitor?.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor?.start(queue: monitorQueue)
    }
    
    // MARK: - Server Configuration
    
    func updateServerAddress(host: String, port: Int) {
        self.serverHost = host
        self.serverPort = port
        Task {
            await testConnection()
        }
    }
    
    private var baseURL: URL {
        return URL(string: "http://\(serverHost):\(serverPort)/api/v1")!
    }
    
    // MARK: - Connection Testing
    
    func testConnection() async -> Bool {
        do {
            let url = baseURL.appendingPathComponent("health")
            let (_, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == 200
                await MainActor.run {
                    self.isConnected = success
                    self.lastError = success ? nil : "Server returned status \(httpResponse.statusCode)"
                }
                return success
            }
            return false
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.lastError = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Data Upload
    
    func uploadHealthData(_ batch: HealthDataBatch) async -> Result<Void, LocalServerError> {
        guard isConnected else {
            return .failure(.notConnected)
        }
        
        do {
            let url = baseURL.appendingPathComponent("data")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let jsonData = try JSONEncoder().encode(batch)
            request.httpBody = jsonData
            
            let (_, response) = try await urlSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200...299:
                    await MainActor.run {
                        self.lastError = nil
                    }
                    return .success(())
                case 400:
                    return .failure(.badRequest)
                case 409:
                    return .failure(.conflict)
                case 500...599:
                    return .failure(.serverError)
                default:
                    return .failure(.unknownError)
                }
            }
            
            return .failure(.unknownError)
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - Data Download
    
    func fetchHealthData(since timestamp: Date) async -> Result<HealthDataBatch, LocalServerError> {
        guard isConnected else {
            return .failure(.notConnected)
        }
        
        do {
            var components = URLComponents(url: baseURL.appendingPathComponent("data"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: timestamp))
            ]
            
            guard let url = components.url else {
                return .failure(.badRequest)
            }
            
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 200:
                    let batch = try JSONDecoder().decode(HealthDataBatch.self, from: data)
                    await MainActor.run {
                        self.lastError = nil
                    }
                    return .success(batch)
                case 404:
                    // No new data available
                    return .success(HealthDataBatch())
                case 400:
                    return .failure(.badRequest)
                case 500...599:
                    return .failure(.serverError)
                default:
                    return .failure(.unknownError)
                }
            }
            
            return .failure(.unknownError)
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            return .failure(.networkError(error))
        }
    }
    
    // MARK: - Server Discovery
    
    func discoverLocalServer() async -> [String] {
        var discoveredServers: [String] = []
        
        // Common local IP ranges to scan
        let commonHosts = [
            "192.168.1.100", "192.168.1.101", "192.168.1.102",
            "192.168.0.100", "192.168.0.101", "192.168.0.102",
            "10.0.0.100", "10.0.0.101", "10.0.0.102",
            "localhost"
        ]
        
        await withTaskGroup(of: (String, Bool).self) { group in
            for host in commonHosts {
                group.addTask {
                    let originalHost = self.serverHost
                    self.serverHost = host
                    let isReachable = await self.testConnection()
                    self.serverHost = originalHost
                    return (host, isReachable)
                }
            }
            
            for await (host, isReachable) in group {
                if isReachable {
                    discoveredServers.append(host)
                }
            }
        }
        
        return discoveredServers
    }
}

// MARK: - Error Types

enum LocalServerError: Error, LocalizedError {
    case notConnected
    case badRequest
    case conflict
    case serverError
    case networkError(Error)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to local server"
        case .badRequest:
            return "Invalid request format"
        case .conflict:
            return "Data conflict detected"
        case .serverError:
            return "Server internal error"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknownError:
            return "Unknown server error"
        }
    }
}
