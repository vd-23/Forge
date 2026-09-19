import SwiftUI

// Placeholder — the real set-logging screen lands in Task 14.
// For now it proves the session was created and lets you finish or discard it.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    let controller: WorkoutController

    var body: some View {
        List {
            Section("Planned") {
                ForEach(session.orderedExercises) { we in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(we.exercise?.name ?? "—")
                        if let target = RepRange.targetLabel(
                            sets: we.targetSets,
                            repMin: we.targetRepMin,
                            repMax: we.targetRepMax
                        ) {
                            Text(target)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") {
                    controller.finish(session)
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Discard", role: .destructive) {
                    controller.discard(session)
                    dismiss()
                }
            }
        }
    }
}
