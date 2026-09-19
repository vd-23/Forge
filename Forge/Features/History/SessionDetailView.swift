import SwiftUI
import ForgeCore

/// Everything logged in one finished workout, set by set.
struct SessionDetailView: View {
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
                    if workoutExercise.orderedSets.isEmpty {
                        Text("No sets logged")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(workoutExercise.orderedSets) { set in
                            row(set, isBodyweight: workoutExercise.exercise?.isBodyweight ?? false)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Sets that didn't count toward volume are kept visible but dimmed and
    /// tagged, so the record of the session stays honest.
    private func row(_ set: ExerciseSet, isBodyweight: Bool) -> some View {
        HStack(spacing: 8) {
            Text(SetFormatting.line(set, isBodyweight: isBodyweight, unit: unit))
                .foregroundStyle(set.isWorkingSet ? .primary : .secondary)

            if set.isWarmup { tag("warm-up") }
            if !set.isComplete { tag("skipped") }

            Spacer()

            if let rpe = set.rpe {
                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: .capsule)
    }
}
