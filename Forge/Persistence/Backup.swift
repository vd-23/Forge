import Foundation
import SwiftData

/// The whole store as one JSON document. Every model keeps its `id` so a
/// restore reproduces the same graph; relationships are written as ids.
struct ForgeBackup: Codable {
    static let currentVersion = 1

    var version = currentVersion
    var exportedAt: Date
    var customBodyParts: [String]
    var preferences: PreferencesSnapshot
    var exercises: [ExerciseRecord]
    var routines: [RoutineRecord]
    var sessions: [SessionRecord]

    struct PreferencesSnapshot: Codable {
        var weightUnit: String
        var defaultRestSeconds: Int
    }

    struct ExerciseRecord: Codable {
        var id: UUID
        var name: String
        var bodyPart: String
        var isBodyweight: Bool
        var isUnilateral: Bool
        var defaultRestSeconds: Int?
        var isArchived: Bool
        var createdAt: Date
    }

    struct RoutineRecord: Codable {
        var id: UUID
        var name: String
        var isArchived: Bool
        var createdAt: Date
        var lastPerformedAt: Date?
        var sortOrder: Int?
        var items: [RoutineItemRecord]
    }

    struct RoutineItemRecord: Codable {
        var exerciseID: UUID
        var order: Int
        var targetSets: Int?
        var targetRepMin: Int?
        var targetRepMax: Int?
        var targetRestSeconds: Int?
    }

    struct SessionRecord: Codable {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var notes: String?
        var sourceRoutineID: UUID?
        var sourceRoutineName: String
        var exercises: [SessionExerciseRecord]
    }

    struct SessionExerciseRecord: Codable {
        var exerciseID: UUID
        var order: Int
        var targetSets: Int?
        var targetRepMin: Int?
        var targetRepMax: Int?
        var restSeconds: Int?
        var sets: [SetRecord]
    }

    struct SetRecord: Codable {
        var order: Int
        var weightKg: Double?
        var addedWeightKg: Double?
        var reps: Int
        var rpe: Double?
        var isWarmup: Bool
        var isComplete: Bool
        var completedAt: Date?
    }
}

@MainActor
enum BackupCoder {
    enum Error: Swift.Error, Equatable {
        case malformed
        case unsupportedVersion(Int)
    }

    struct RestoreSummary: Equatable {
        let exercises: Int
        let routines: Int
        let sessions: Int
    }

    static let fileExtension = "forgebackup"

    // MARK: Export

    static func export(from context: ModelContext, defaults: UserDefaults = Preferences.defaults) throws -> Data {
        let catalog = BodyPartCatalog(defaults: defaults)
        let prefs = Preferences(defaults: defaults)

        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.createdAt)]))
        let routines = try context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.createdAt)]))
        // An in-progress workout belongs to this device; a restored copy would
        // be invisible until the next launch.
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt)]
        ))

        let backup = ForgeBackup(
            exportedAt: .now,
            customBodyParts: catalog.custom.map(\.displayName),
            preferences: .init(weightUnit: prefs.weightUnit.rawValue, defaultRestSeconds: prefs.defaultRestSeconds),
            exercises: exercises.map { e in
                .init(id: e.id, name: e.name, bodyPart: e.primaryBodyPartRaw, isBodyweight: e.isBodyweight,
                      isUnilateral: e.isUnilateral, defaultRestSeconds: e.defaultRestSeconds,
                      isArchived: e.isArchived, createdAt: e.createdAt)
            },
            routines: routines.map { r in
                .init(id: r.id, name: r.name, isArchived: r.isArchived, createdAt: r.createdAt,
                      lastPerformedAt: r.lastPerformedAt, sortOrder: r.sortOrder,
                      items: r.orderedItems.compactMap { item in
                          guard let exercise = item.exercise else { return nil }
                          return .init(exerciseID: exercise.id, order: item.order, targetSets: item.targetSets,
                                       targetRepMin: item.targetRepMin, targetRepMax: item.targetRepMax,
                                       targetRestSeconds: item.targetRestSeconds)
                      })
            },
            sessions: sessions.map { s in
                .init(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, notes: s.notes,
                      sourceRoutineID: s.sourceRoutine?.id, sourceRoutineName: s.sourceRoutineName,
                      exercises: s.orderedExercises.map { we in
                          .init(exerciseID: we.exerciseID, order: we.order, targetSets: we.targetSets,
                                targetRepMin: we.targetRepMin, targetRepMax: we.targetRepMax, restSeconds: we.restSeconds,
                                sets: we.orderedSets.map { set in
                                    .init(order: set.order, weightKg: set.weightKg, addedWeightKg: set.addedWeightKg,
                                          reps: set.reps, rpe: set.rpe, isWarmup: set.isWarmup,
                                          isComplete: set.isComplete, completedAt: set.completedAt)
                                })
                      })
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(backup)
    }

    // MARK: Restore

    /// Replaces the store's contents. Nothing is deleted until the document
    /// has been decoded, so a bad file leaves the current data alone.
    @discardableResult
    static func restore(_ data: Data, into context: ModelContext, defaults: UserDefaults = Preferences.defaults) throws -> RestoreSummary {
        let backup = try decode(data)

        // Object deletes, not `delete(model:)`: the batch form runs straight
        // against the store, skips cascade rules, and fails on the
        // Exercise→RoutineItem inverse — after sessions are already gone.
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(session) }
        for routine in try context.fetch(FetchDescriptor<Routine>()) { context.delete(routine) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        try context.save()

        defaults.set(backup.customBodyParts, forKey: BodyPartCatalog.key)
        let prefs = Preferences(defaults: defaults)
        prefs.weightUnit = WeightUnit(rawValue: backup.preferences.weightUnit) ?? .kg
        prefs.defaultRestSeconds = backup.preferences.defaultRestSeconds

        var exercisesByID: [UUID: Exercise] = [:]
        for record in backup.exercises {
            let exercise = Exercise(
                name: record.name,
                primaryBodyPart: BodyPart(rawValue: record.bodyPart),
                isBodyweight: record.isBodyweight,
                isUnilateral: record.isUnilateral,
                defaultRestSeconds: record.defaultRestSeconds
            )
            exercise.id = record.id
            exercise.isArchived = record.isArchived
            exercise.createdAt = record.createdAt
            context.insert(exercise)
            exercisesByID[record.id] = exercise
        }

        var routinesByID: [UUID: Routine] = [:]
        for record in backup.routines {
            let routine = Routine(name: record.name)
            routine.id = record.id
            routine.isArchived = record.isArchived
            routine.createdAt = record.createdAt
            routine.lastPerformedAt = record.lastPerformedAt
            routine.sortOrder = record.sortOrder ?? 0
            context.insert(routine)
            for item in record.items {
                guard let exercise = exercisesByID[item.exerciseID] else { continue }
                routine.items.append(RoutineItem(
                    exercise: exercise, order: item.order, targetSets: item.targetSets,
                    targetRepMin: item.targetRepMin, targetRepMax: item.targetRepMax,
                    targetRestSeconds: item.targetRestSeconds
                ))
            }
            routinesByID[record.id] = routine
        }

        for record in backup.sessions {
            let session = WorkoutSession(
                startedAt: record.startedAt,
                sourceRoutine: record.sourceRoutineID.flatMap { routinesByID[$0] },
                sourceRoutineName: record.sourceRoutineName
            )
            session.id = record.id
            session.endedAt = record.endedAt
            session.notes = record.notes
            context.insert(session)
            for we in record.exercises {
                guard let exercise = exercisesByID[we.exerciseID] else { continue }
                let workoutExercise = WorkoutExercise(
                    exercise: exercise, exerciseID: exercise.id, order: we.order,
                    targetSets: we.targetSets, targetRepMin: we.targetRepMin, targetRepMax: we.targetRepMax,
                    restSeconds: we.restSeconds
                )
                for set in we.sets {
                    let exerciseSet = ExerciseSet(
                        order: set.order, weightKg: set.weightKg, addedWeightKg: set.addedWeightKg,
                        reps: set.reps, rpe: set.rpe, isWarmup: set.isWarmup
                    )
                    exerciseSet.isComplete = set.isComplete
                    exerciseSet.completedAt = set.completedAt
                    workoutExercise.sets.append(exerciseSet)
                }
                session.exercises.append(workoutExercise)
            }
        }

        try context.save()
        return RestoreSummary(exercises: backup.exercises.count, routines: backup.routines.count, sessions: backup.sessions.count)
    }

    static func decode(_ data: Data) throws -> ForgeBackup {
        struct Header: Decodable { let version: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let header = try? decoder.decode(Header.self, from: data) else { throw Error.malformed }
        guard header.version == ForgeBackup.currentVersion else { throw Error.unsupportedVersion(header.version) }
        do {
            return try decoder.decode(ForgeBackup.self, from: data)
        } catch {
            throw Error.malformed
        }
    }
}
