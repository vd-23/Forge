import SwiftUI
import SwiftData
import Charts
import ForgeCore

/// One exercise: what it is, what you've done on it, and how it's trending.
struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    @State private var metric: ExerciseMetric?
    @State private var range: ChartRange = .sixMonths
    @State private var editing = false
    @State private var deleteError: String?

    private var metricOptions: [ExerciseMetric] {
        ExerciseMetric.options(bodyweight: exercise.isBodyweight)
    }

    private var selectedMetric: ExerciseMetric {
        metric ?? metricOptions[0]
    }

    private var progress: ExerciseProgress {
        ExerciseProgressBuilder.build(
            exerciseID: exercise.id,
            sessions: sessions,
            metric: selectedMetric,
            range: range
        )
    }

    var body: some View {
        let progress = progress

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hero(progress)
                if progress.hasHistory {
                    SectionLabel("Lifetime records").padding(.top, 4)
                    records(progress.records)
                    trend(progress)
                    SectionLabel("Recent sessions").padding(.top, 4)
                    recentSessions
                } else {
                    Text("No finished workouts with this exercise yet.")
                        .font(.body)
                        .foregroundStyle(ForgeColor.ink3)
                        .card()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .forgeBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    if exercise.isArchived {
                        Button("Unarchive", systemImage: "arrow.uturn.backward") { setArchived(false) }
                    } else {
                        Button("Archive", systemImage: "archivebox") { setArchived(true) }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis")
                }
                Button("Edit") { editing = true }
                    .tint(ForgeColor.accentInk)
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack { ExerciseEditorView(exercise: exercise) }
        }
        .alert("Can't delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: Hero

    private func hero(_ progress: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(ForgeColor.ink)
            HStack(spacing: 8) {
                Chip(exercise.primaryBodyPart.displayName, tint: ForgeColor.accentInk, fill: ForgeColor.accentSoft)
                if exercise.isBodyweight { Chip("BW") }
                if exercise.isUnilateral { Chip("×2") }
                if progress.hasHistory {
                    HStack(spacing: 4) {
                        Text("^[\(progress.sessionCount) session](inflect: true)")
                        Text("•")
                        RelativeDateText(date: progress.lastPerformed, style: .compact)
                    }
                    .font(ForgeType.meta)
                    .foregroundStyle(ForgeColor.ink2)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    // MARK: Records

    /// A bodyweight exercise has no load records worth showing — its 1RM would
    /// be meaningless and its heaviest weight is always nothing.
    private func records(_ records: PRSet) -> some View {
        HStack(spacing: 10) {
            if !exercise.isBodyweight, let weight = records.maxWeightKg {
                StatTile(label: "Heaviest", value: WeightFormatting.number(weight, unit: unit), unit: unit.rawValue)
            }
            if let reps = records.maxReps {
                StatTile(label: "Most reps", value: "\(reps)", unit: "reps")
            }
            if !exercise.isBodyweight, let e1rm = records.bestE1RM {
                StatTile(
                    label: "Est. 1RM",
                    value: WeightFormatting.number(e1rm, unit: unit, fractionDigits: 0),
                    unit: unit.rawValue,
                    fill: ForgeColor.accentSoft
                )
            }
        }
    }

    // MARK: Trend

    private func trend(_ progress: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if metricOptions.count > 1 {
                Picker("Metric", selection: Binding(
                    get: { selectedMetric },
                    set: { metric = $0 }
                )) {
                    ForEach(metricOptions) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack(alignment: .bottom) {
                headline(progress.points)
                Spacer()
                rangeControl
            }

            if progress.points.isEmpty {
                Text("Nothing logged in this range.")
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                chart(progress.points)
                    .frame(height: 170)
            }
        }
        .card()
    }

    /// Latest value in the range, with how far it moved since the range began.
    @ViewBuilder
    private func headline(_ points: [SeriesPoint]) -> some View {
        if let last = points.last {
            VStack(alignment: .leading, spacing: 2) {
                MeasureText(value: format(last.value), unit: selectedMetric.isWeight ? unit.rawValue : nil)
                if points.count > 1, let first = points.first {
                    let delta = last.value - first.value
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(delta >= 0 ? "+" : "−")\(format(abs(delta))) \(selectedMetric.isWeight ? unit.rawValue : "")")
                            .fontWeight(.semibold)
                        Text("in \(range.longName)")
                    }
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(delta >= 0 ? ForgeColor.accentInk : ForgeColor.ink3)
                }
            }
        }
    }

    private var rangeControl: some View {
        HStack(spacing: 14) {
            ForEach(ChartRange.allCases) { option in
                Button {
                    Haptics.selection()
                    withAnimation(.snappy) { range = option }
                } label: {
                    Text(option.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(option == range ? ForgeColor.accentInk : ForgeColor.ink3)
                        .padding(.bottom, 3)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(option == range ? ForgeColor.accentFill : .clear).frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func format(_ value: Double) -> String {
        selectedMetric.isWeight
            ? WeightFormatting.number(value, unit: unit, fractionDigits: selectedMetric == .e1rm ? 0 : 1)
            : "\(Int(value))"
    }

    /// Line charts sit in a padded band around their values; an area mark
    /// would otherwise drag the axis down to zero and flatten the trend.
    private func yDomain(_ points: [SeriesPoint]) -> ClosedRange<Double> {
        let values = points.map { selectedMetric.isWeight ? WeightFormatting.editableValue($0.value, unit: unit) : $0.value }
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if selectedMetric == .volume { return 0...max(high * 1.08, 1) }
        let pad = max((high - low) * 0.25, high * 0.05, 1)
        return max(0, low - pad)...(high + pad)
    }

    @ViewBuilder
    private func chart(_ points: [SeriesPoint]) -> some View {
        let last = points.last?.date
        let domain = yDomain(points)
        Chart(points, id: \.date) { point in
            let value = selectedMetric.isWeight
                ? WeightFormatting.editableValue(point.value, unit: unit)
                : point.value

            if selectedMetric == .volume {
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(selectedMetric.displayName, value)
                )
                .cornerRadius(2)
                .foregroundStyle(point.date == last ? ForgeColor.accent : ForgeColor.accent.opacity(0.52))
            } else {
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", domain.lowerBound),
                    yEnd: .value(selectedMetric.displayName, value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(colors: [ForgeColor.accent.opacity(0.22), ForgeColor.accent.opacity(0)], startPoint: .top, endPoint: .bottom)
                )
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, value)
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(ForgeColor.accent)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, value)
                )
                .symbolSize(point.date == last ? 70 : 20)
                .foregroundStyle(point.date == last ? ForgeColor.surface : ForgeColor.accent)
                if point.date == last {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(selectedMetric.displayName, value)
                    )
                    .symbol {
                        Circle().strokeBorder(ForgeColor.accent, lineWidth: 2.5).frame(width: 12, height: 12)
                    }
                }
            }
        }
        // A single session is a dot, not a line — without a padded domain the
        // chart collapses to a sliver.
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink3)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(ForgeColor.hairline)
                AxisValueLabel()
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink3)
            }
        }
    }

    // MARK: Recent sessions

    private var recentSessions: some View {
        let rows = sessions.compactMap { session -> RecentRow? in
            guard let workoutExercise = session.orderedExercises.first(where: { $0.exerciseID == exercise.id }) else { return nil }
            let input = workoutExercise.coreInput
            let working = workingSets(input.sets)
            guard !working.isEmpty else { return nil }
            let top = working.compactMap(\.weightKg).max()
            let e1rm = working.compactMap { set -> Double? in
                guard let weight = set.weightKg else { return nil }
                return estimatedOneRepMax(weightKg: weight, reps: set.reps)
            }.max()
            let reps = working.map(\.reps)
            let repsLabel = Set(reps).count == 1 ? "\(working.count) × \(reps[0])" : "\(working.count) sets · \(reps.map(String.init).joined(separator: ", "))"
            return RecentRow(id: session.id, date: session.startedAt, setsLabel: repsLabel, topKg: top, e1rmKg: e1rm)
        }.prefix(5)

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { CardDivider() }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ForgeColor.ink)
                        Text([row.setsLabel, row.topKg.map { "top \(WeightFormatting.display($0, unit: unit))" }].compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(ForgeColor.ink3)
                    }
                    Spacer()
                    if !exercise.isBodyweight, let e1rm = row.e1rmKg {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(WeightFormatting.number(e1rm, unit: unit, fractionDigits: 0))
                                .font(.system(size: 17, weight: .bold).monospacedDigit())
                                .foregroundStyle(ForgeColor.ink)
                            Text("EST. 1RM")
                                .font(.system(size: 9, weight: .bold))
                                .kerning(0.6)
                                .foregroundStyle(ForgeColor.ink3)
                        }
                    }
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 16)
            }
        }
        .card(padding: 0)
    }

    private struct RecentRow: Identifiable {
        let id: UUID
        let date: Date
        let setsLabel: String
        let topKg: Double?
        let e1rmKg: Double?
    }

    // MARK: Actions

    private func setArchived(_ archived: Bool) {
        exercise.isArchived = archived
        try? context.save()
    }

    private func delete() {
        guard ExerciseDeletion.canHardDelete(exercise) else {
            deleteError = "\(exercise.name) is used by a routine or a past workout. Archive it instead."
            return
        }
        // Pop before deleting: this view is built from the exercise, so removing
        // it while still on screen would leave the stack holding a dead model.
        dismiss()
        Task {
            context.delete(exercise)
            try? context.save()
        }
    }
}

extension ChartRange {
    var longName: String {
        switch self {
        case .eightWeeks: "8 weeks"
        case .sixMonths: "6 months"
        case .year: "a year"
        case .all: "all time"
        }
    }
}
