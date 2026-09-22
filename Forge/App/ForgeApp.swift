import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container: ModelContainer
    @State private var workoutController: WorkoutController

    init() {
        let container = PersistenceController.shared
        self.container = container
        // One controller for the whole app: "is a workout in progress" is
        // global state that the routine list, detail, and launch-time
        // stale-session check all read.
        _workoutController = State(initialValue: WorkoutController(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(workoutController)
                .task { PersistenceController.seedIfEmpty(container.mainContext) }
        }
        .modelContainer(container)
    }
}
