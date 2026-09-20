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
        ScrollView {
            LazyVStack(spacing: 12) {
                facts
                ForEach(session.orderedExercises) { workoutExercise in
                    WorkoutExerciseCard(
                        workoutExercise: workoutExercise,
                        sessionID: session.id,
                        controller: controller,
                        unit: unit,
                        isExpanded: true,
                        highlightsCurrent: false
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .numericKeyboardDoneButton()
        .forgeBackground()
        .navigationTitle(session.sourceRoutineName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var facts: some View {
        let setCount = session.exercises.reduce(0) { $0 + $1.sets.filter(\.isWorkingSet).count }

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(ForgeColor.accentInk)
                    SectionLabel("Completed")
                }
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute()))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
            }

            Rectangle().fill(ForgeColor.accentLine).frame(height: 1)

            HStack(alignment: .top, spacing: 0) {
                fact("Duration", value: session.durationSeconds.map(Self.clock) ?? "—")
                fact("Volume", value: WeightFormatting.number(sessionVolumeKg(session.coreInput), unit: unit, fractionDigits: 0), unit: unit.rawValue)
                fact("Sets", value: "\(setCount)")
            }

            if let notes = session.notes, !notes.isEmpty {
                Text(notes).font(.body).foregroundStyle(ForgeColor.ink2)
            }
        }
        .card(fill: ForgeColor.accentSoft)
    }

    private func fact(_ label: String, value: String, unit: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(label)
            MeasureText(value: value, unit: unit, valueFont: .system(size: 22, weight: .bold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func clock(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)m"
    }
}
