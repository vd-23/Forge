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
                .task {
                    PersistenceController.seedIfEmpty(container.mainContext)
                    #if DEBUG
                    // Screenshots: `-demoBackupPath <file>` loads a backup made by
                    // scripts/make-demo-backup.py in place of whatever is there.
                    if let path = UserDefaults.standard.string(forKey: "demoBackupPath"),
                       let data = FileManager.default.contents(atPath: path) {
                        _ = try? BackupCoder.restore(data, into: container.mainContext)
                    }
                    #endif
                }
        }
        .modelContainer(container)
    }
}
