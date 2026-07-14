import BackgroundTasks
import SwiftData

enum BackgroundRefreshManager {
    static let taskIdentifier = "com.shakshi.LangueDeChat.refresh"

    static func registerTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()

        let taskHandle = Task { @MainActor in
            let container = SharedStore.makeContainer()
            await ParcelRefresher.shared.refreshAll(in: container.mainContext)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            taskHandle.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
