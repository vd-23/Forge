import SwiftUI
import SwiftData
import Charts
import ForgeCore

/// One exercise: what it is, what you've done on it, and how it's trending.
struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil })
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

        return List {
            Section { about(progress) }
            if progress.hasHistory {
                Section("Records") { records(progress.records) }
                Section("Trend") { trend(progress) }
            } else {
                Section {
                    Text("No finished workouts with this exercise yet.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { editing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if exercise.isArchived {
                        Button("Unarchive", systemImage: "arrow.uturn.backward") { setArchived(false) }
                    } else {
                        Button("Archive", systemImage: "archivebox") { setArchived(true) }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { delete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
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

    // MARK: Sections

    @ViewBuilder
    private func about(_ progress: ExerciseProgress) -> some View {
        LabeledContent("Body part", value: exercise.primaryBodyPart.displayName)
        if exercise.isBodyweight {
            LabeledContent("Type", value: "Bodyweight")
        }
        if exercise.isUnilateral {
            LabeledContent("Counting", value: "Per side, doubled")
        }
        LabeledContent("Sessions", value: "\(progress.sessionCount)")
        LabeledContent("Last performed") {
            RelativeDateText(date: progress.lastPerformed)
        }
    }

    /// A bodyweight exercise has no load records worth showing — its 1RM would
    /// be meaningless and its heaviest weight is always nothing.
    @ViewBuilder
    private func records(_ records: PRSet) -> some View {
        if !exercise.isBodyweight, let weight = records.maxWeightKg {
            LabeledContent("Heaviest weight", value: WeightFormatting.display(weight, unit: unit))
        }
        if let reps = records.maxReps {
            LabeledContent("Most reps", value: "\(reps)")
        }
        if !exercise.isBodyweight, let e1rm = records.bestE1RM {
            LabeledContent("Best estimated 1RM", value: WeightFormatting.display(e1rm, unit: unit, fractionDigits: 0))
        }
    }

    @ViewBuilder
    private func trend(_ progress: ExerciseProgress) -> some View {
        if metricOptions.count > 1 {
            Picker("Metric", selection: Binding(
                get: { selectedMetric },
                set: { metric = $0 }
            )) {
                ForEach(metricOptions) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        }

        Picker("Range", selection: $range) {
            ForEach(ChartRange.allCases) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)

        if progress.points.isEmpty {
            Text("Nothing logged in this range.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            chart(progress.points)
                .frame(height: 190)
                .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func chart(_ points: [SeriesPoint]) -> some View {
        Chart(points, id: \.date) { point in
            let value = selectedMetric.isWeight
                ? WeightFormatting.editableValue(point.value, unit: unit)
                : point.value

            if selectedMetric == .volume {
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(selectedMetric.displayName, value)
                )
                .foregroundStyle(Color.accentColor)
            } else {
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, value)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value(selectedMetric.displayName, value)
                )
                .foregroundStyle(Color.accentColor)
            }
        }
        // A single session is a dot, not a line — without a padded domain the
        // chart collapses to a sliver.
        .chartYScale(domain: .automatic(includesZero: selectedMetric == .volume))
        .chartXAxis {
            AxisMarks(preset: .aligned) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
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
