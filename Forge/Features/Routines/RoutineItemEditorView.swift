import SwiftUI
import SwiftData

/// Per-exercise targets within a routine. Every field is optional — leaving a
/// toggle off means "freestyle it" for that dimension.
struct RoutineItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: RoutineItem

    @State private var setsEnabled: Bool
    @State private var sets: Int
    @State private var repsEnabled: Bool
    @State private var repMin: Int
    @State private var repMax: Int
    @State private var restEnabled: Bool
    @State private var rest: Int

    init(item: RoutineItem) {
        self.item = item
        _setsEnabled = State(initialValue: item.targetSets != nil)
        _sets = State(initialValue: item.targetSets ?? 3)
        _repsEnabled = State(initialValue: item.targetRepMin != nil || item.targetRepMax != nil)
        _repMin = State(initialValue: item.targetRepMin ?? 8)
        _repMax = State(initialValue: item.targetRepMax ?? 12)
        _restEnabled = State(initialValue: item.targetRestSeconds != nil)
        _rest = State(initialValue: item.targetRestSeconds ?? 120)
    }

    var body: some View {
        Form {
            Section("Target sets") {
                Toggle("Set a target", isOn: $setsEnabled)
                if setsEnabled {
                    Stepper("\(sets) sets", value: $sets, in: 1...10)
                }
            }

            Section("Target reps") {
                Toggle("Set a target", isOn: $repsEnabled)
                if repsEnabled {
                    Stepper("Min \(repMin)", value: $repMin, in: 1...30)
                    Stepper("Max \(repMax)", value: $repMax, in: repMin...50)
                }
            }

            Section {
                Toggle("Override exercise default", isOn: $restEnabled)
                if restEnabled {
                    Stepper("\(rest)s", value: $rest, in: 30...600, step: 15)
                }
            } header: {
                Text("Rest")
            } footer: {
                if !restEnabled, let fallback = item.exercise?.defaultRestSeconds {
                    Text("Using the exercise default of \(fallback)s.")
                } else if !restEnabled {
                    Text("Using the app default of \(Preferences.defaultRestSeconds)s.")
                }
            }
        }
        .forgeForm()
        .navigationTitle(item.exercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: repMin) { if repMax < repMin { repMax = repMin } }
        .onDisappear(perform: persist)
    }

    private func persist() {
        item.targetSets = setsEnabled ? sets : nil
        item.targetRepMin = repsEnabled ? repMin : nil
        item.targetRepMax = repsEnabled ? repMax : nil
        item.targetRestSeconds = restEnabled ? rest : nil
        try? context.save()
    }
}
