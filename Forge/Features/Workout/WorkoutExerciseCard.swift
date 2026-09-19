import SwiftUI
import SwiftData

/// One exercise in the active workout: its target, what was logged last time,
/// and the editable rows for today's sets.
struct WorkoutExerciseCard: View {
    @Environment(\.modelContext) private var context

    let workoutExercise: WorkoutExercise
    let sessionID: UUID
    let controller: WorkoutController
    let unit: WeightUnit
    let onSetCompleted: (WorkoutExercise) -> Void

    /// Resolved once on appear rather than in `body`: it runs a fetch.
    @State private var lastSummary: String?

    private var isBodyweight: Bool { workoutExercise.exercise?.isBodyweight ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Text(lastSummary.map { "Last: \($0)" } ?? "First time")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(workoutExercise.orderedSets) { set in
                SetEntryRow(
                    set: set,
                    isBodyweight: isBodyweight,
                    unit: unit,
                    onToggleComplete: {
                        controller.toggleComplete(set)
                        if set.isComplete { onSetCompleted(workoutExercise) }
                    },
                    onDelete: { controller.deleteSet(set) }
                )
            }

            Button("Add set", systemImage: "plus", action: addSet)
                .font(.subheadline)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        // Keyed on the unit so the reference line is re-rendered in the new one.
        .task(id: unit) { loadLastPerformance() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(workoutExercise.exercise?.name ?? "—")
                .font(.headline)
            if let target = RepRange.targetLabel(
                sets: workoutExercise.targetSets,
                repMin: workoutExercise.targetRepMin,
                repMax: workoutExercise.targetRepMax
            ) {
                Text(target)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// New sets copy the previous set's load and reps — the common case is
    /// repeating it, and editing down is quicker than typing from scratch.
    private func addSet() {
        let previous = workoutExercise.orderedSets.last
        controller.addSet(
            to: workoutExercise,
            weightKg: previous?.weightKg,
            addedWeightKg: previous?.addedWeightKg,
            reps: previous?.reps ?? workoutExercise.targetRepMin ?? 8,
            rpe: nil,
            isWarmup: false
        )
    }

    private func loadLastPerformance() {
        let sets = LastPerformance.mostRecentSets(
            ofExerciseID: workoutExercise.exerciseID,
            excludingSession: sessionID,
            in: context
        )
        lastSummary = LastPerformance.summary(of: sets, isBodyweight: isBodyweight, unit: unit)
    }
}
