import Foundation
import Network
import Combine

/// Local server client for HTTP-based data synchronization
class LocalServerClient: ObservableObject {
    @Published var isConnected = false
    @Published var serverHost = "192.168.1.100" // Default local IP
    @Published var serverPort = 3000 // Changed to match server's default port
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
        
        // Convert iOS HealthDataBatch to server format and upload each data type separately
        let deviceId = "ios_device_001" // Simplified device ID for now
        let deviceName = "iPhone"
        let deviceType = "ios"
        
        do {
            // Upload heart rate data
            if !batch.heartRateData.isEmpty {
                try await uploadDataType(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    deviceType: deviceType,
                    dataType: "heart_rate",
                    records: batch.heartRateData.map { heartRate in
                        [
                            "timestamp": Int64(heartRate.timestamp.timeIntervalSince1970 * 1000),
                            "value": heartRate.value,
                            "unit": "bpm",
                            "metadata": [
                                "confidence": heartRate.confidence ?? 0.0
                            ]
                        ]
                    }
                )
            }
            
            // Upload step count data
            if !batch.stepCountData.isEmpty {
                try await uploadDataType(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    deviceType: deviceType,
                    dataType: "steps",
                    records: batch.stepCountData.map { stepCount in
                        [
                            "timestamp": Int64(stepCount.timestamp.timeIntervalSince1970 * 1000),
                            "value": Double(stepCount.count),
                            "unit": "steps",
                            "metadata": stepCount.duration != nil ? [
                                "duration": stepCount.duration!
                            ] : [:]
                        ]
                    }
                )
            }
            
            await MainActor.run {
                self.lastError = nil
            }
            return .success(())
        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
            return .failure(.networkError(error))
        }
    }
    
    private func uploadDataType(deviceId: String, deviceName: String, deviceType: String, dataType: String, records: [[String: Any]]) async throws {
        let url = baseURL.appendingPathComponent("health-data")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "deviceId": deviceId,
            "deviceName": deviceName,
            "deviceType": deviceType,
            "dataType": dataType,
            "records": records
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                return
            case 400:
                throw LocalServerError.badRequest
            case 409:
                throw LocalServerError.conflict
            case 500...599:
                throw LocalServerError.serverError
            default:
                throw LocalServerError.unknownError
            }
        }
        
        throw LocalServerError.unknownError
    }
    
    // MARK: - Data Download
    
    func fetchHealthData(since timestamp: Date) async -> Result<HealthDataBatch, LocalServerError> {
        guard isConnected else {
            return .failure(.notConnected)
        }
        
        do {
            // Generate a device ID for iOS app - simplified for now
            let deviceId = "ios_device_001"
            
            var components = URLComponents(url: baseURL.appendingPathComponent("sync/data/\(deviceId)"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "since", value: String(Int64(timestamp.timeIntervalSince1970 * 1000)))
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
