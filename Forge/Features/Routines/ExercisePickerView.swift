import SwiftUI
import SwiftData

/// Searchable list of the exercise library, grouped by body part. In single
/// mode (mid-workout) a tap picks and dismisses; in multi mode (designing a
/// routine) taps toggle ticks and "Add" commits them all at once. Also offers
/// inline creation of a new exercise.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var search = ""
    @State private var creating = false
    @State private var selected: [Exercise] = []

    private let onPick: ([Exercise]) -> Void
    private let allowsMultiple: Bool

    init(onPick: @escaping (Exercise) -> Void) {
        self.onPick = { $0.first.map(onPick) }
        allowsMultiple = false
    }

    init(onPickMany: @escaping ([Exercise]) -> Void) {
        onPick = onPickMany
        allowsMultiple = true
    }

    private var filtered: [Exercise] {
        ExerciseFiltering.filter(exercises, search: search, bodyPart: nil)
    }

    private var grouped: [(bodyPart: BodyPart, items: [Exercise])] {
        Dictionary(grouping: filtered, by: \.primaryBodyPart)
            .map { (bodyPart: $0.key, items: $0.value) }
            .sorted { $0.bodyPart.displayName < $1.bodyPart.displayName }
    }

    var body: some View {
        List {
            Section {
                Button("New exercise", systemImage: "plus") { creating = true }
            }
            ForEach(grouped, id: \.bodyPart) { group in
                Section {
                    ForEach(group.items) { exercise in
                        Button { tap(exercise) } label: { row(exercise) }
                            .listRowBackground(ForgeColor.surface)
                    }
                } header: {
                    SectionLabel(group.bodyPart.displayName).textCase(nil)
                }
            }
        }
        .searchable(text: $search)
        .forgeForm()
        .navigationTitle(allowsMultiple ? "Add Exercises" : "Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            if allowsMultiple {
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.count > 1 ? "Add \(selected.count)" : "Add") {
                        Haptics.tick()
                        onPick(selected)
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { ExerciseEditorView(exercise: nil) }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let isSelected = selected.contains { $0 === exercise }
        return HStack(spacing: 8) {
            if allowsMultiple {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? ForgeColor.accentFill : ForgeColor.ink3)
                    .padding(.trailing, 2)
            }
            Text(exercise.name).foregroundStyle(ForgeColor.ink)
            Spacer()
            if exercise.isBodyweight { Chip("BW") }
            if exercise.isUnilateral { Chip("×2") }
        }
        .contentShape(.rect)
    }

    private func tap(_ exercise: Exercise) {
        guard allowsMultiple else {
            Haptics.tap()
            onPick([exercise])
            dismiss()
            return
        }
        Haptics.selection()
        if let index = selected.firstIndex(where: { $0 === exercise }) {
            selected.remove(at: index)
        } else {
            selected.append(exercise)
        }
    }
}
