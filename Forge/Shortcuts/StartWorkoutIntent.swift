import AppIntents
import SwiftData

/// A routine as Shortcuts and Siri see it.
struct RoutineEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Routine")
    static let defaultQuery = RoutineQuery()

    let id: UUID
    let name: String
    let exerciseCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(exerciseCount) exercises"
        )
    }

    @MainActor
    init(_ routine: Routine) {
        id = routine.id
        name = routine.name
        exerciseCount = routine.items.count
    }
}

struct RoutineQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [RoutineEntity] {
        ShortcutLauncher.availableRoutines(in: PersistenceController.shared.mainContext)
            .filter { identifiers.contains($0.id) }
            .map(RoutineEntity.init)
    }

    /// What the Shortcuts app and Spotlight offer as ready-made tiles.
    @MainActor
    func suggestedEntities() async throws -> [RoutineEntity] {
        ShortcutLauncher.featuredRoutines(in: PersistenceController.shared.mainContext)
            .map(RoutineEntity.init)
    }
}

/// "Start Push Day" — opens the app straight into the workout.
struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts a workout from one of your routines.")
    static let openAppWhenRun = true

    @Parameter(title: "Routine")
    var routine: RoutineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$routine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutLauncher.setPending(routine.id)
        return .result()
    }
}

/// One App Shortcut, parameterised by routine. Calling
/// `updateAppShortcutParameters()` makes the system expand it into one tile
/// per `suggestedEntities()` result — "Push Day", "Pull Day", … — so each
/// routine is a single tap from Shortcuts or Spotlight.
struct ForgeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start \(\.$routine) in \(.applicationName)",
                "\(\.$routine) in \(.applicationName)",
                "Begin \(\.$routine) with \(.applicationName)",
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional",
            parameterPresentation: ParameterPresentation(
                for: \.$routine,
                summary: Summary("Start \(\.$routine)"),
                optionsCollections: {
                    OptionsCollection(RoutineQuery(), title: "Routines", systemImageName: "list.bullet.rectangle")
                }
            )
        )
    }
}

