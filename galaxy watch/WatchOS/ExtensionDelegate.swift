import Foundation
import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Initialize the Galaxy Watch Manager
        _ = GalaxyWatchManager.shared
        print("Galaxy Watch 4 Classic Sync App launched")
    }

    func applicationDidBecomeActive() {
        // App became active, refresh data
        GalaxyWatchManager.shared.startHealthMonitoring()
    }

    func applicationWillResignActive() {
        // App will resign active, schedule background refresh
        GalaxyWatchManager.shared.scheduleBackgroundRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Handle background refresh
                Task {
                    await GalaxyWatchManager.shared.performSync()
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }

            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Handle snapshot refresh
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil)

            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Handle connectivity refresh
                connectivityTask.setTaskCompletedWithSnapshot(false)

            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Handle URL session background task
                urlSessionTask.setTaskCompletedWithSnapshot(false)

            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Handle relevant shortcuts
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)

            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Handle intent completion
                intentDidRunTask.setTaskCompletedWithSnapshot(false)

            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    func applicationWillEnterForeground() {
        // App will enter foreground
        print("App entering foreground")
    }

    func applicationDidEnterBackground() {
        // App entered background
        print("App entered background")
        GalaxyWatchManager.shared.scheduleBackgroundRefresh()
    }
}
