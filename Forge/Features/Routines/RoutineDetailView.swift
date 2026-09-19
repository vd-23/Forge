import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(WorkoutController.self) private var controller

    let routine: Routine
    var autoStart: Bool = false

    @State private var startedSession: WorkoutSession?
    @State private var showActiveConflict = false
    /// `.task` re-runs whenever this view reappears — including when the active
    /// workout is finished and pops back onto it. Without this guard, finishing
    /// a workout would immediately auto-start another one.
    @State private var didAutoStart = false

    /// Rough planning aid: ~2.5 min per planned set, assuming 3 sets when the
    /// routine doesn't specify a target.
    private var estimatedMinutes: Int {
        routine.orderedItems.reduce(0) { total, item in
            total + Int(Double(item.targetSets ?? 3) * 2.5)
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Last performed") {
                    RelativeDateText(date: routine.lastPerformedAt)
                }
                LabeledContent("Estimated", value: "~\(estimatedMinutes) min")
            }

            Section("Exercises") {
                if routine.orderedItems.isEmpty {
                    Text("No exercises yet — edit this routine to add some.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(routine.orderedItems) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise?.name ?? "—")
                            if let target = RepRange.targetLabel(
                                sets: item.targetSets,
                                repMin: item.targetRepMin,
                                repMax: item.targetRepMax
                            ) {
                                Text(target)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Start Workout", action: attemptStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .disabled(routine.orderedItems.isEmpty)
        }
        .navigationDestination(item: $startedSession) { session in
            ActiveWorkoutView(session: session, controller: controller)
        }
        .alert("A workout is already in progress", isPresented: $showActiveConflict) {
            Button("Resume it") { startedSession = controller.activeSession }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Finish or discard it before starting another.")
        }
        .task {
            guard autoStart, !didAutoStart else { return }
            didAutoStart = true
            attemptStart()
        }
    }

    private func attemptStart() {
        guard !controller.hasActiveSession else {
            showActiveConflict = true
            return
        }
        startedSession = try? controller.start(from: routine)
    }
}
