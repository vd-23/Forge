import SwiftUI

/// Drag-to-reorder and swipe-to-delete for the exercises in a running workout.
/// A plain `List` in edit mode, because the workout screen itself is a scroll
/// view and can't host drag handles.
struct WorkoutReorderView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    let controller: WorkoutController

    var body: some View {
        List {
            ForEach(session.orderedExercises) { workoutExercise in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workoutExercise.exercise?.name ?? "—")
                            .font(.body)
                            .foregroundStyle(ForgeColor.ink)
                        let done = workoutExercise.sets.filter(\.isComplete).count
                        Text("\(done)/\(workoutExercise.sets.count) sets")
                            .font(ForgeType.meta)
                            .foregroundStyle(ForgeColor.ink3)
                    }
                }
            }
            .onMove { source, destination in
                Haptics.selection()
                controller.moveExercises(in: session, from: source, to: destination)
            }
            .onDelete { offsets in
                Haptics.heavy()
                for index in offsets.sorted(by: >) {
                    controller.removeExercise(session.orderedExercises[index])
                }
            }
            .listRowBackground(ForgeColor.surface)
        }
        .environment(\.editMode, .constant(.active))
        .forgeForm()
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { Haptics.tap(); dismiss() }
            }
        }
    }
}
