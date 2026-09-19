import SwiftUI
import SwiftData

struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil → creating a new exercise.
    let exercise: Exercise?

    @State private var name: String
    @State private var bodyPart: BodyPart
    @State private var isBodyweight: Bool
    @State private var isUnilateral: Bool
    @State private var usesCustomRest: Bool
    @State private var restSeconds: Int

    init(exercise: Exercise?) {
        self.exercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _bodyPart = State(initialValue: exercise?.primaryBodyPart ?? .chest)
        _isBodyweight = State(initialValue: exercise?.isBodyweight ?? false)
        _isUnilateral = State(initialValue: exercise?.isUnilateral ?? false)
        _usesCustomRest = State(initialValue: exercise?.defaultRestSeconds != nil)
        _restSeconds = State(initialValue: exercise?.defaultRestSeconds ?? 120)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                Picker("Body part", selection: $bodyPart) {
                    ForEach(BodyPart.allCases) { Text($0.displayName).tag($0) }
                }
            }

            Section {
                Toggle("Bodyweight exercise", isOn: $isBodyweight)
                Toggle("Unilateral (counts volume ×2)", isOn: $isUnilateral)
            } footer: {
                Text(isBodyweight
                     ? "Only reps are logged; added weight is optional."
                     : "Weight and reps are logged.")
            }

            Section("Rest") {
                Toggle("Custom default rest", isOn: $usesCustomRest)
                if usesCustomRest {
                    Stepper("\(restSeconds)s", value: $restSeconds, in: 30...600, step: 15)
                }
            }
        }
        .navigationTitle(exercise == nil ? "New Exercise" : "Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(trimmedName.isEmpty)
            }
        }
    }

    private func save() {
        let target: Exercise
        if let exercise {
            target = exercise
        } else {
            let new = Exercise(name: trimmedName, primaryBodyPart: bodyPart)
            context.insert(new)
            target = new
        }
        target.name = trimmedName
        target.primaryBodyPart = bodyPart
        target.isBodyweight = isBodyweight
        target.isUnilateral = isUnilateral
        target.defaultRestSeconds = usesCustomRest ? restSeconds : nil
        try? context.save()
        dismiss()
    }
}

#Preview {
    NavigationStack { ExerciseEditorView(exercise: nil) }
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
