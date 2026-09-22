import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var weightUnit: WeightUnit = .kg
    @AppStorage(Preferences.Key.defaultRestSeconds, store: Preferences.defaults)
    private var restSeconds: Int = Preferences.fallbackRestSeconds

    @State private var storage = StoreHealth(bytes: 0)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weight unit", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    SectionLabel("Units").textCase(nil)
                }
                Section {
                    Stepper(value: $restSeconds, in: 30...600, step: 15) {
                        LabeledContent("Default rest", value: RestTimerBar.clock(restSeconds))
                    }
                } header: {
                    SectionLabel("Rest timer").textCase(nil)
                }
                Section {
                    NavigationLink("Body parts") { BodyPartsView() }
                    NavigationLink("Backup and restore") { DataView() }
                } header: {
                    SectionLabel("Library and data").textCase(nil)
                }
                Section {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("Storage used", value: storage.label)
                    if storage.isOverBudget {
                        Label("Larger than expected — export a backup and consider deleting old workouts.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    SectionLabel("About").textCase(nil)
                } footer: {
                    Text("Free personal signing: don't delete the app. Re-run from Xcode (⌘R) when it stops launching.")
                        .font(.footnote)
                        .foregroundStyle(ForgeColor.ink3)
                }
            }
            .forgeForm()
            .navigationTitle("Settings")
            .task {
                if let url = try? PersistenceController.storeURL() {
                    storage = StoreHealth.measure(storeURL: url)
                }
            }
        }
    }
}
