import Combine
import Foundation
import Network

/// Real-time WebSocket client for live health data streaming
class RealtimeHealthClient: ObservableObject {
    @Published var isConnected = false
    @Published var lastDataReceived: Date?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var liveHealthData: LiveHealthData = LiveHealthData()
    @Published var serverMetrics: ServerMetrics?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var serverURL: URL
    private var deviceId: String
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private let maxReconnectAttempts = 5
    private var reconnectAttempts = 0

    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error(String)

        var displayText: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    struct LiveHealthData {
        var currentHeartRate: Double = 0
        var currentSteps: Int = 0
        var currentCalories: Double = 0
        var batteryLevel: Double = 0
        var isWatchConnected: Bool = false
        var lastUpdateTime: Date = Date()

        var heartRateZone: String {
            switch currentHeartRate {
            case 0..<60: return "Resting"
            case 60..<100: return "Normal"
            case 100..<140: return "Fat Burn"
            case 140..<170: return "Cardio"
            case 170...: return "Peak"
            default: return "Unknown"
            }
        }

        var heartRateColor: String {
            switch currentHeartRate {
            case 0..<60: return "blue"
            case 60..<100: return "green"
            case 100..<140: return "yellow"
            case 140..<170: return "orange"
            case 170...: return "red"
            default: return "gray"
            }
        }
    }

    struct ServerMetrics {
        let totalDevices: Int
        let activeConnections: Int
        let dataPointsToday: Int
        let serverUptime: TimeInterval
        let lastSyncTime: Date?

        var uptimeDisplay: String {
            let hours = Int(serverUptime) / 3600
            let minutes = (Int(serverUptime) % 3600) / 60
            let seconds = Int(serverUptime) % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    init(serverHost: String = "192.168.1.100", serverPort: Int = 3000) {
        self.deviceId = UUID().uuidString
        self.serverURL = URL(string: "ws://\(serverHost):\(serverPort)/ws")!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Connection Management

    func connect() {
        guard webSocketTask == nil else {
            print("WebSocket already connected or connecting")
            return
        }

        connectionStatus = .connecting
        reconnectAttempts = 0

        var request = URLRequest(url: serverURL)
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
        request.setValue("ios", forHTTPHeaderField: "X-Device-Type")

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        startListening()
        startHeartbeat()

        print("WebSocket connecting to: \(serverURL)")
    }

    func disconnect() {
        stopHeartbeat()
        stopReconnectTimer()

        webSocketTask?.cancel(with: .goingAway, reason: "User disconnected".data(using: .utf8))
        webSocketTask = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .disconnected
        }

        print("WebSocket disconnected")
    }

    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.startListening()  // Continue listening

            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleConnectionError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleStringMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleStringMessage(text)
            }
        @unknown default:
            print("Unknown WebSocket message type")
        }
    }

    private func handleStringMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            print("Failed to parse WebSocket message: \(text)")
            return
        }

        DispatchQueue.main.async {
            self.processMessage(json)
        }
    }

    private func processMessage(_ json: [String: Any]) {
        guard let type = json["type"] as? String else { return }

        switch type {
        case "welcome":
            handleWelcomeMessage(json)
        case "health_data_update":
            handleHealthDataUpdate(json)
        case "device_status":
            handleDeviceStatusUpdate(json)
        case "server_metrics":
            handleServerMetrics(json)
        case "pong":
            print("Received pong from server")
        case "error":
            if let message = json["message"] as? String {
                connectionStatus = .error(message)
            }
        default:
            print("Unknown message type: \(type)")
        }
    }

    private func handleWelcomeMessage(_ json: [String: Any]) {
        print("WebSocket connection established")
        isConnected = true
        connectionStatus = .connected
        reconnectAttempts = 0
        lastDataReceived = Date()

        // Subscribe to health data updates
        subscribeToStreams(["health_data_update", "device_status", "server_metrics"])

        // Request current server metrics
        requestServerMetrics()
    }

    private func handleHealthDataUpdate(_ json: [String: Any]) {
        guard let data = json["data"] as? [String: Any],
            let healthData = data["data"] as? [String: Any]
        else { return }

        var updatedData = liveHealthData

        if let heartRate = healthData["heartRate"] as? Double {
            updatedData.currentHeartRate = heartRate
        }

        if let steps = healthData["steps"] as? Int {
            updatedData.currentSteps = steps
        }

        if let calories = healthData["calories"] as? Double {
            updatedData.currentCalories = calories
        }

        if let battery = healthData["batteryLevel"] as? Double {
            updatedData.batteryLevel = battery
        }

        updatedData.lastUpdateTime = Date()
        updatedData.isWatchConnected = true

        liveHealthData = updatedData
        lastDataReceived = Date()

        print(
            "Health data updated: HR=\(updatedData.currentHeartRate), Steps=\(updatedData.currentSteps)"
        )
    }

    private func handleDeviceStatusUpdate(_ json: [String: Any]) {
        guard let data = json["data"] as? [String: Any],
            let deviceId = data["deviceId"] as? String,
            let status = data["status"] as? String
        else { return }

        print("Device \(deviceId) status: \(status)")

        if deviceId.contains("galaxy") || deviceId.contains("watch") {
            var updatedData = liveHealthData
            updatedData.isWatchConnected = (status == "active")
            liveHealthData = updatedData
        }
    }

    private func handleServerMetrics(_ json: [String: Any]) {
        guard let data = json["data"] as? [String: Any] else { return }

        let metrics = ServerMetrics(
            totalDevices: data["totalDevices"] as? Int ?? 0,
            activeConnections: data["activeConnections"] as? Int ?? 0,
            dataPointsToday: data["dataPointsToday"] as? Int ?? 0,
            serverUptime: data["serverUptime"] as? TimeInterval ?? 0,
            lastSyncTime: parseDate(from: data["lastSyncTime"] as? String)
        )

        serverMetrics = metrics
    }

    private func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    // MARK: - Message Sending

    func subscribeToStreams(_ streams: [String]) {
        let message: [String: Any] = [
            "type": "subscribe",
            "data": ["streams": streams],
        ]
        sendMessage(message)
    }

    func unsubscribeFromStreams(_ streams: [String]) {
        let message: [String: Any] = [
            "type": "unsubscribe",
            "data": ["streams": streams],
        ]
        sendMessage(message)
    }

    func sendLiveHealthData(_ healthData: [String: Any]) {
        let message: [String: Any] = [
            "type": "health_data",
            "data": healthData,
        ]
        sendMessage(message)
    }

    func requestServerMetrics() {
        let message: [String: Any] = [
            "type": "get_metrics"
        ]
        sendMessage(message)
    }

    private func sendMessage(_ message: [String: Any]) {
        guard isConnected else {
            print("Cannot send message: not connected")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let string = String(data: data, encoding: .utf8) ?? ""

            webSocketTask?.send(.string(string)) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Failed to serialize message: \(error)")
        }
    }

    // MARK: - Heartbeat and Reconnection

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
            [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendPing() {
        guard isConnected else { return }

        let message: [String: Any] = [
            "type": "ping",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
        ]
        sendMessage(message)
    }

    private func handleConnectionError(_ error: Error) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = .error(error.localizedDescription)
        }

        stopHeartbeat()
        webSocketTask = nil

        // Attempt reconnection
        if reconnectAttempts < maxReconnectAttempts {
            startReconnectTimer()
        } else {
            print("Max reconnection attempts reached")
        }
    }

    private func startReconnectTimer() {
        stopReconnectTimer()

        DispatchQueue.main.async {
            self.connectionStatus = .reconnecting
        }

        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)  // Exponential backoff, max 30s

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            self?.attemptReconnection()
        }

        print(
            "Reconnecting in \(delay) seconds (attempt \(reconnectAttempts + 1)/\(maxReconnectAttempts))"
        )
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func attemptReconnection() {
        reconnectAttempts += 1
        connect()
    }

    // MARK: - Configuration Updates

    func updateServerAddress(host: String, port: Int) {
        let wasConnected = isConnected

        if wasConnected {
            disconnect()
        }

        serverURL = URL(string: "ws://\(host):\(port)/ws")!

        if wasConnected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.connect()
            }
        }

        print("Updated server address to: \(serverURL)")
    }

    deinit {
        disconnect()
    }
}
