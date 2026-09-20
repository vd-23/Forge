import SwiftUI
import SwiftData
import ForgeCore

/// One exercise in a workout. Expanded, it shows the reference line and the
/// set table; collapsed, a single summary row. `highlightsCurrent` is off for a
/// finished session in History, where the table reads as a record.
struct WorkoutExerciseCard: View {
    @Environment(\.modelContext) private var context

    let workoutExercise: WorkoutExercise
    let sessionID: UUID
    let controller: WorkoutController
    let unit: WeightUnit
    var isExpanded: Bool = true
    var highlightsCurrent: Bool = true
    var onToggleExpanded: (() -> Void)? = nil
    var onSetCompleted: ((WorkoutExercise, ExerciseSet) -> Void)? = nil
    /// Move up / move down / remove, offered from a long-press on the card.
    /// `nil` on a finished session, where the exercise list is a record.
    var onMove: ((Int) -> Void)? = nil
    var onRemove: (() -> Void)? = nil
    var canMoveUp: Bool = false
    var canMoveDown: Bool = false

    /// Resolved once on appear rather than in `body`: it runs a fetch.
    @State private var lastSets: [ExerciseSet] = []

    private var isBodyweight: Bool { workoutExercise.exercise?.isBodyweight ?? false }
    private var sets: [ExerciseSet] { workoutExercise.orderedSets }
    private var doneCount: Int { sets.filter(\.isComplete).count }
    private var currentSetID: PersistentIdentifier? {
        guard highlightsCurrent, isExpanded else { return nil }
        return sets.first { !$0.isComplete }?.persistentModelID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                if highlightsCurrent { toBeat }
                table
                Button("Add set", systemImage: "plus", action: addSet)
                    .buttonStyle(InlineAccentButtonStyle())
                    .padding(.top, 2)
            }
        }
        .card(padding: 16)
        .contextMenu {
            if onMove != nil || onRemove != nil {
                if let onMove {
                    if canMoveUp {
                        Button("Move up", systemImage: "arrow.up") { Haptics.tap(); onMove(-1) }
                    }
                    if canMoveDown {
                        Button("Move down", systemImage: "arrow.down") { Haptics.tap(); onMove(1) }
                    }
                }
                if let onRemove {
                    Button("Remove exercise", systemImage: "trash", role: .destructive) {
                        Haptics.heavy()
                        onRemove()
                    }
                }
            }
        }
        .task(id: unit) { loadLastPerformance() }
    }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        if let onToggleExpanded {
            Button { Haptics.tap(); onToggleExpanded() } label: { headerContent }
                .buttonStyle(.plain)
        } else {
            headerContent
        }
    }

    private var headerContent: some View {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workoutExercise.exercise?.name ?? "—")
                        .font(ForgeType.cardTitle)
                        .foregroundStyle(ForgeColor.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(ForgeType.meta)
                        .foregroundStyle(ForgeColor.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text("\(doneCount)/\(sets.count)")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(ForgeColor.ink2)
                    if isExpanded {
                        HStack(spacing: 3) {
                            ForEach(0..<min(sets.count, 6), id: \.self) { index in
                                Circle()
                                    .fill(index < doneCount ? ForgeColor.accent : ForgeColor.hairline)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    } else if onToggleExpanded != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ForgeColor.ink3)
                    }
                }
                .padding(.top, 4)
            }
            .contentShape(.rect)
    }

    private var subtitle: String {
        let target = RepRange.targetLabel(
            sets: workoutExercise.targetSets,
            repMin: workoutExercise.targetRepMin,
            repMax: workoutExercise.targetRepMax
        )
        if isExpanded {
            if highlightsCurrent {
                return target.map { "Target \($0)" } ?? "No target"
            }
            let input = workoutExercise.coreInput
            let volume = WeightFormatting.display(
                workingSets(input.sets).reduce(0) { $0 + setVolumeKg($1, exercise: input.exercise) },
                unit: unit, fractionDigits: 0
            )
            return "\(sets.count) sets · \(volume)"
        }
        let last = LastPerformance.summary(of: lastSets, isBodyweight: isBodyweight, unit: unit)
        return [target, last.map { "last \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: To beat

    @ViewBuilder
    private var toBeat: some View {
        HStack(spacing: 8) {
            Text("TO BEAT")
                .font(.system(size: 10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(ForgeColor.ink3)
            if let last = LastPerformance.summary(of: lastSets, isBodyweight: isBodyweight, unit: unit) {
                Text(last)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let when = lastSets.first?.workoutExercise?.session?.startedAt {
                    Text(when.formatted(.dateTime.weekday(.abbreviated)))
                        .font(ForgeType.meta)
                        .foregroundStyle(ForgeColor.ink3)
                }
            } else {
                Text("First time — set the bar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ForgeColor.ink2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(ForgeColor.sunken, in: .rect(cornerRadius: 12))
    }

    // MARK: Table

    private var table: some View {
        VStack(spacing: 0) {
            SetTableHeader(isBodyweight: isBodyweight, unit: unit)
            ForEach(Array(SetNumbering.number(sets).enumerated()), id: \.element.id) { index, numbered in
                let set = numbered.exerciseSet
                let emphasis: SetEmphasis = set.persistentModelID == currentSetID
                    ? .current
                    : (set.isComplete || !highlightsCurrent ? .done : .upcoming)
                if index > 0 && emphasis != .current { CardDivider() }
                SetEntryRow(
                    set: set,
                    label: numbered.label,
                    isBodyweight: isBodyweight,
                    unit: unit,
                    emphasis: emphasis,
                    onToggleComplete: {
                        controller.toggleComplete(set)
                        if set.isComplete { onSetCompleted?(workoutExercise, set) }
                    },
                    onDelete: { controller.deleteSet(set) }
                )
            }
        }
    }

    /// New sets copy the previous set's load and reps — the common case is
    /// repeating it, and editing down is quicker than typing from scratch.
    private func addSet() {
        Haptics.tap()
        let previous = sets.last
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
        lastSets = LastPerformance.mostRecentSets(
            ofExerciseID: workoutExercise.exerciseID,
            excludingSession: sessionID,
            in: context
        )
    }
}
