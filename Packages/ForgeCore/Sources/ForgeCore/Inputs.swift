import Foundation

/// The exercise attributes ForgeCore needs to score a set.
/// Mapped from the app's `Exercise` model at the call site.
public struct ExerciseInput: Sendable, Codable, Equatable {
    public let id: UUID
    public let isBodyweight: Bool
    public let isUnilateral: Bool

    public init(id: UUID, isBodyweight: Bool, isUnilateral: Bool) {
        self.id = id
        self.isBodyweight = isBodyweight
        self.isUnilateral = isUnilateral
    }
}

/// One logged set. For unilateral exercises, `reps` is the count per side.
public struct SetInput: Sendable, Codable, Equatable {
    public let weightKg: Double?
    public let addedWeightKg: Double?
    public let reps: Int
    public let rpe: Double?
    public let isWarmup: Bool
    public let isComplete: Bool

    public init(
        weightKg: Double?,
        addedWeightKg: Double? = nil,
        reps: Int,
        rpe: Double? = nil,
        isWarmup: Bool = false,
        isComplete: Bool = true
    ) {
        self.weightKg = weightKg
        self.addedWeightKg = addedWeightKg
        self.reps = reps
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isComplete = isComplete
    }
}

/// One exercise slot within a session, with its logged sets in entry order.
public struct WorkoutExerciseInput: Sendable, Codable, Equatable {
    public let exercise: ExerciseInput
    public let sets: [SetInput]

    public init(exercise: ExerciseInput, sets: [SetInput]) {
        self.exercise = exercise
        self.sets = sets
    }
}

/// A whole workout session, finished or in progress.
public struct SessionInput: Sendable, Codable, Equatable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let exercises: [WorkoutExerciseInput]

    public init(id: UUID, startedAt: Date, endedAt: Date?, exercises: [WorkoutExerciseInput]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
    }

    /// A session counts as finished once it has an end timestamp.
    public var isFinished: Bool { endedAt != nil }
}
