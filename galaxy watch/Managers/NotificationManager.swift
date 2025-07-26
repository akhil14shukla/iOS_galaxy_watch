import Foundation
import UserNotifications
import CallKit

class NotificationManager: NSObject, ObservableObject {
    @Published var isNotificationEnabled = false
    @Published var isCallSyncEnabled = false
    
    private let callController = CXCallController()
    private let callProvider: CXProvider
    private let notificationCenter = UNUserNotificationCenter.current()
    
    override init() {
        let configuration = CXProviderConfiguration(localizedName: "Galaxy Watch")
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.phoneNumber]
        
        callProvider = CXProvider(configuration: configuration)
        super.init()
        
        callProvider.setDelegate(self, queue: nil)
        notificationCenter.delegate = self
        requestNotificationPermissions()
    }
    
    func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isNotificationEnabled = granted
            }
        }
    }
    
    // Forward notifications to Galaxy Watch
    func forwardNotification(_ notification: UNNotification) {
        let content = notification.request.content
        let notificationData = GalaxyNotification(
            id: notification.request.identifier,
            title: content.title,
            body: content.body,
            timestamp: Date(),
            appBundleId: content.threadIdentifier
        )
        
        // Send to BluetoothManager for forwarding
        NotificationCenter.default.post(
            name: NSNotification.Name("ForwardNotificationToWatch"),
            object: notificationData
        )
    }
    
    // Handle incoming calls
    func handleIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        
        callProvider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("Error reporting incoming call: \(error.localizedDescription)")
            }
        }
    }
    
    // Log sync methods
    func syncCallLog(_ call: CallLog) {
        // Store call log and forward to watch
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncCallLogToWatch"),
            object: call
        )
    }
    
    func syncMessageLog(_ message: MessageLog) {
        // Store message log and forward to watch
        NotificationCenter.default.post(
            name: NSNotification.Name("SyncMessageLogToWatch"),
            object: message
        )
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        forwardNotification(notification)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        forwardNotification(response.notification)
        completionHandler()
    }
}

// MARK: - CXProviderDelegate
extension NotificationManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        // Handle provider reset
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        // Handle call answer
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        // Handle call end
        action.fulfill()
    }
}