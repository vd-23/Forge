import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(WorkoutController.self) private var controller

    let routine: Routine
    var autoStart: Bool = false
    /// The whole tab's navigation stack. Pushing the workout through here rather
    /// than a local `navigationDestination(item:)` keeps it on screen: saving a
    /// set refreshes the routine list's `@Query`, which tears down and rebuilds
    /// any destination this view declares itself.
    @Binding var path: [RoutineDestination]

    @State private var showActiveConflict = false
    /// `.task` re-runs whenever this view reappears — including when the active
    /// workout is finished and pops back onto it. Without this guard, finishing
    /// a workout would immediately auto-start another one.
    @State private var didAutoStart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                facts
                SectionLabel("Exercises").padding(.top, 6)
                exercises
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .forgeBackground()
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Start Workout", action: attemptStart)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(routine.orderedItems.isEmpty)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 28)
        }
        .alert("A workout is already in progress", isPresented: $showActiveConflict) {
            Button("Resume it") {
                if let active = controller.activeSession {
                    path.append(.activeWorkout(active))
                }
            }
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

    private var facts: some View {
        HStack(spacing: 0) {
            fact("Last done") {
                RelativeDateText(date: routine.lastPerformedAt, style: .compact)
            }
            Rectangle().fill(ForgeColor.divider).frame(width: 1, height: 40)
            fact("Estimated") { Text("~\(routine.estimatedMinutes) min") }
            Rectangle().fill(ForgeColor.divider).frame(width: 1, height: 40)
            fact("Sets") { Text("\(routine.plannedSetCount)") }
        }
        .card(padding: 16)
    }

    private func fact(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(label)
            value()
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(ForgeColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var exercises: some View {
        if routine.orderedItems.isEmpty {
            Text("No exercises yet — edit this routine to add some.")
                .font(.body)
                .foregroundStyle(ForgeColor.ink3)
                .card()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(routine.orderedItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { CardDivider() }
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(ForgeColor.ink3)
                            .frame(width: 24, height: 24)
                            .background(ForgeColor.sunken, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise?.name ?? "—")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(ForgeColor.ink)
                            if let target = RepRange.targetLabel(
                                sets: item.targetSets,
                                repMin: item.targetRepMin,
                                repMax: item.targetRepMax
                            ) {
                                Text(target)
                                    .font(ForgeType.meta)
                                    .foregroundStyle(ForgeColor.ink3)
                            }
                        }
                        Spacer()
                        if item.exercise?.isBodyweight == true { Chip("BW") }
                        if item.exercise?.isUnilateral == true { Chip("×2") }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
            }
            .card(padding: 0)
        }
    }

    private func attemptStart() {
        Haptics.tick()
        guard !controller.hasActiveSession else {
            showActiveConflict = true
            return
        }
        guard let session = try? controller.start(from: routine) else { return }
        path.append(.activeWorkout(session))
    }
}
