import SwiftUI
import SwiftData

/// The workout in progress: one card per exercise, a rest countdown, and the
/// finish flow. Navigating back leaves the session running — it is recovered by
/// `WorkoutController` and resumed from the routine list.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    let controller: WorkoutController

    @State private var restTimer = RestTimer()
    @State private var addingExercise = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var summary: WorkoutSummary?

    /// Bound rather than read once, so switching units in Settings re-renders
    /// every weight field on this screen immediately.
    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(session.orderedExercises) { workoutExercise in
                    WorkoutExerciseCard(
                        workoutExercise: workoutExercise,
                        sessionID: session.id,
                        controller: controller,
                        unit: unit,
                        onSetCompleted: startRest(after:)
                    )
                }

                Button("Add exercise", systemImage: "plus.circle") { addingExercise = true }
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { RestTimerBar(timer: restTimer) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(session.sourceRoutineName)
                        .font(.headline)
                    Text(session.startedAt, style: .timer)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add exercise", systemImage: "plus") { addingExercise = true }
                    Button("Discard workout", role: .destructive) { confirmDiscard = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { confirmFinish = true }
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $addingExercise) {
            NavigationStack {
                ExercisePickerView { controller.addExercise($0, to: session) }
            }
        }
        .sheet(item: $summary) { summary in
            WorkoutSummaryView(summary: summary) {
                self.summary = nil
                dismiss()
            }
        }
        .alert("Finish this workout?", isPresented: $confirmFinish) {
            Button("Finish", action: finish)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Incomplete sets won't be counted.")
        }
        .alert("Discard this workout?", isPresented: $confirmDiscard) {
            Button("Discard", role: .destructive) {
                // Pop first: the session is the value backing this entry in the
                // navigation stack, so deleting it while the view is still
                // mounted would leave the stack holding an invalidated model.
                dismiss()
                Task { controller.discard(session) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Everything logged in this session will be deleted.")
        }
    }

    private func startRest(after workoutExercise: WorkoutExercise) {
        restTimer.start(seconds: workoutExercise.restSeconds ?? Preferences.defaultRestSeconds)
    }

    private func finish() {
        restTimer.skip()
        summary = controller.finish(session)
    }
}
