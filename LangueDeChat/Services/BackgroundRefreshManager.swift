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

    /// `setTaskCompleted` is what lets the system suspend us, so it must never
    /// be called while `refreshAll` still has a save in flight: iOS kills a
    /// process that is suspended while holding a lock on a file in a shared
    /// container, and our store lives in the App Group (RUNNINGBOARD
    /// `0xdead10cc`, seen as a SIGKILL inside `sqlite3_step` / `pagerWalFrames`).
    ///
    /// So the expiration handler only *cancels* — the completion call is made
    /// from the work itself, once `refreshAll` has returned and the store is
    /// unlocked. `refreshAll` is cancellation-aware, so that unwind is short
    /// enough to stay inside the grace period the expiration handler gives us.
    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()

        let taskHandle = Task { @MainActor in
            let container = SharedStore.makeContainer()
            await ParcelRefresher.shared.refreshAll(in: container.mainContext)
            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            taskHandle.cancel()
        }
    }
}
