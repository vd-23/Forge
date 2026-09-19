import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container = PersistenceController.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { PersistenceController.seedIfEmpty(container.mainContext) }
        }
        .modelContainer(container)
    }
}
