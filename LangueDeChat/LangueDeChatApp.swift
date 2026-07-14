import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct LangueDeChatApp: App {
    private let container: ModelContainer

    init() {
        BackgroundRefreshManager.registerTask()
        // Move a pre-existing store into the App Group before opening it, so the
        // app and the share extension share one store from here on.
        SharedStore.migrateExistingStoreIfNeeded()
        container = SharedStore.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await NotificationManager.shared.requestAuthorization()
                    BackgroundRefreshManager.scheduleNext()
                }
        }
        .modelContainer(container)
    }
}
