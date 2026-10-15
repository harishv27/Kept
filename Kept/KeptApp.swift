import SwiftUI
import SwiftData

@main
struct KeptApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(SharedStore.container)
                .task { await DemoData.seedIfRequested(SharedStore.container) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await Reminders.syncAll() } }
        }
    }
}
