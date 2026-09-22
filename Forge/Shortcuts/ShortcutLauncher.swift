import Foundation
import SwiftData

/// Glue between App Intents and the workout controller. The intent runs in
/// the app process but outside the SwiftUI tree, so it leaves a pending
/// routine id in defaults; the root view picks it up on activation and
/// starts (or resumes) from there.
@MainActor
enum ShortcutLauncher {
    enum Outcome: Equatable {
        case started
        case resumedExisting
        case notFound
    }

    static let pendingKey = "pendingShortcutRoutineID"

    static func start(routineID: UUID, controller: WorkoutController, context: ModelContext) -> Outcome {
        if controller.hasActiveSession { return .resumedExisting }
        guard let routine = availableRoutines(in: context).first(where: { $0.id == routineID }),
              (try? controller.start(from: routine)) != nil
        else { return .notFound }
        return .started
    }

    /// How many routines get their own tile in Shortcuts and Spotlight.
    static let shortcutSlots = 4

    /// The routines that appear as individual shortcuts: most recently
    /// performed first, then by name, capped at `shortcutSlots`.
    static func featuredRoutines(in context: ModelContext) -> [Routine] {
        Array(availableRoutines(in: context)
            .sorted { lhs, rhs in
                switch (lhs.lastPerformedAt, rhs.lastPerformedAt) {
                case let (l?, r?): l > r
                case (nil, _?): false
                case (_?, nil): true
                case (nil, nil): lhs.name < rhs.name
                }
            }
            .prefix(shortcutSlots))
    }

    static func availableRoutines(in context: ModelContext) -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func setPending(_ id: UUID, defaults: UserDefaults = Preferences.defaults) {
        defaults.set(id.uuidString, forKey: pendingKey)
    }

    static func takePending(defaults: UserDefaults = Preferences.defaults) -> UUID? {
        defer { defaults.removeObject(forKey: pendingKey) }
        return defaults.string(forKey: pendingKey).flatMap(UUID.init)
    }
}
