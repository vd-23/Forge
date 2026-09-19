import SwiftUI

struct SettingsView: View {
    @State private var weightUnit = Preferences.weightUnit
    @State private var restSeconds = Preferences.defaultRestSeconds

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Rest timer") {
                    Stepper("Default rest: \(restSeconds)s", value: $restSeconds, in: 30...600, step: 15)
                }
                Section {
                    NavigationLink("Manage exercises") { ExerciseLibraryView() }
                }
                Section("About") {
                    LabeledContent("Version", value: "0.1.0")
                    Text("Free personal signing: don't delete the app. Re-run from Xcode (⌘R) when it stops launching.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onChange(of: weightUnit) { Preferences.weightUnit = weightUnit }
            .onChange(of: restSeconds) { Preferences.defaultRestSeconds = restSeconds }
        }
    }
}
