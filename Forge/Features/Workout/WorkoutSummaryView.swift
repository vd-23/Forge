import SwiftUI

/// Shown once, right after finishing: the numbers for the session just logged.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Duration", value: summary.durationLabel)
                    LabeledContent("Volume", value: WeightFormatting.display(
                        summary.totalVolumeKg, unit: unit, fractionDigits: 0
                    ))
                    LabeledContent("Working sets", value: "\(summary.workingSetCount)")
                    if !summary.bodyParts.isEmpty {
                        LabeledContent("Trained", value: summary.bodyParts
                            .map(\.displayName)
                            .joined(separator: ", "))
                    }
                }

                if !summary.prHits.isEmpty {
                    Section("Personal records") {
                        ForEach(summary.prHits) { hit in
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hit.exerciseName)
                                    Text(hit.kind.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Workout complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
