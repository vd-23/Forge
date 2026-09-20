import SwiftUI
import SwiftData

/// Searchable list of the exercise library, used when adding an exercise to a
/// routine or mid-workout. Also offers inline creation of a new exercise.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var search = ""
    @State private var creating = false

    let onPick: (Exercise) -> Void

    private var filtered: [Exercise] {
        search.isEmpty
            ? exercises
            : exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            Section {
                Button("New exercise", systemImage: "plus") { creating = true }
            }
            Section {
                ForEach(filtered) { exercise in
                    Button {
                        onPick(exercise)
                        dismiss()
                    } label: {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Text(exercise.primaryBodyPart.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
        }
        .searchable(text: $search)
        .forgeForm()
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { ExerciseEditorView(exercise: nil) }
        }
    }
}
