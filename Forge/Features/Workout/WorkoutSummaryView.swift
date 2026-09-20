import SwiftUI

/// Shown once, right after finishing: the numbers for the session just logged.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    /// Set when the workout's exercises no longer match the routine it came from.
    var routineDiff: RoutineSync.Diff? = nil
    var routineName: String? = nil
    var onUpdateRoutine: (() -> Void)? = nil
    let onDone: () -> Void

    @State private var routineUpdated = false

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero

                    if let routineDiff, let routineName {
                        routineChange(routineDiff, routineName: routineName)
                    }

                    if !summary.bodyParts.isEmpty {
                        SectionLabel("Trained").padding(.top, 4)
                        HStack(spacing: 6) {
                            ForEach(summary.bodyParts, id: \.self) { part in
                                Chip(part.displayName, tint: ForgeColor.accentInk, fill: ForgeColor.accentSoft)
                            }
                        }
                    }

                    if !summary.prHits.isEmpty {
                        SectionLabel("Personal records").padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(summary.prHits.enumerated()), id: \.element.id) { index, hit in
                                if index > 0 { CardDivider() }
                                HStack(spacing: 12) {
                                    Chip("PR", tint: ForgeColor.accentInk, fill: ForgeColor.accentSoft)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(hit.exerciseName)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(ForgeColor.ink)
                                        Text(hit.kind.shortName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(ForgeColor.ink3)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 11)
                                .padding(.horizontal, 16)
                            }
                        }
                        .card(padding: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .forgeBackground()
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { Haptics.tap(); onDone() }
                        .tint(ForgeColor.accentInk)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    /// The workout deviated from its routine — offer to make the routine match.
    private func routineChange(_ diff: RoutineSync.Diff, routineName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: routineUpdated ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ForgeColor.accentInk)
                SectionLabel(routineUpdated ? "Routine updated" : "Routine changed")
            }
            Text(diff.summary)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ForgeColor.ink)
            if !routineUpdated, let onUpdateRoutine {
                HStack(spacing: 10) {
                    Button("Update \(routineName)") {
                        onUpdateRoutine()
                        withAnimation(.snappy) { routineUpdated = true }
                    }
                    .buttonStyle(.glassProminent)
                    Text("or keep it as it was")
                        .font(ForgeType.meta)
                        .foregroundStyle(ForgeColor.ink3)
                }
                .padding(.top, 2)
            }
        }
        .card()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(ForgeColor.accentInk)
                SectionLabel("Logged")
            }
            HStack(alignment: .top, spacing: 0) {
                fact("Duration", value: summary.durationLabel)
                fact("Volume", value: WeightFormatting.number(summary.totalVolumeKg, unit: unit, fractionDigits: 0), unit: unit.rawValue)
                fact("Sets", value: "\(summary.workingSetCount)")
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
}
