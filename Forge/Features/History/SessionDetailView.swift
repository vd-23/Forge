import SwiftUI
import ForgeCore

/// Everything logged in one finished workout, set by set — and editable, so a
/// mistyped load can be fixed after the fact. Nothing is recomputed on edit:
/// volume, PRs and charts all derive from the sets on read.
struct SessionDetailView: View {
    @Environment(WorkoutController.self) private var controller

    let session: WorkoutSession

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                if let seconds = session.durationSeconds {
                    LabeledContent("Duration", value: DurationFormatting.short(seconds: seconds))
                }
                LabeledContent("Volume", value: WeightFormatting.display(
                    sessionVolumeKg(session.coreInput), unit: unit, fractionDigits: 0
                ))
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                }
            }

            ForEach(session.orderedExercises) { workoutExercise in
                Section(workoutExercise.exercise?.name ?? "—") {
                    let isBodyweight = workoutExercise.exercise?.isBodyweight ?? false
                    ForEach(SetNumbering.number(workoutExercise.orderedSets)) { numbered in
                        SetEntryRow(
                            set: numbered.exerciseSet,
                            label: numbered.label,
                            isBodyweight: isBodyweight,
                            unit: unit,
                            onToggleComplete: { controller.toggleComplete(numbered.exerciseSet) },
                            onDelete: { controller.deleteSet(numbered.exerciseSet) }
                        )
                    }

                    Button("Add set", systemImage: "plus") { addSet(to: workoutExercise) }
                        .font(.subheadline)
                }
            }
        }
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    /// Same defaults as the active workout: repeat the previous set. Added sets
    /// start unticked, so they don't count until the user confirms them.
    private func addSet(to workoutExercise: WorkoutExercise) {
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
}
