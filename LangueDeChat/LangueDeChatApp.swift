import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct LangueDeChatApp: App {
    init() {
        BackgroundRefreshManager.registerTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationManager.shared.requestAuthorization()
                    BackgroundRefreshManager.scheduleNext()
                }
        }
        .modelContainer(for: TrackedParcel.self)
    }
}
