import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// nil → creating a new routine.
    let routine: Routine?

    @State private var name: String
    @State private var draft: Routine?
    @State private var pickingExercise = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _draft = State(initialValue: routine)
    }

    private var items: [RoutineItem] { draft?.orderedItems ?? [] }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section {
                TextField("Routine name", text: $name)
            }

            Section("Exercises") {
                ForEach(items) { item in
                    NavigationLink {
                        RoutineItemEditorView(item: item)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise?.name ?? "—")
                            if let target = RepRange.targetLabel(
                                sets: item.targetSets,
                                repMin: item.targetRepMin,
                                repMax: item.targetRepMax
                            ) {
                                Text(target)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button("Add exercise", systemImage: "plus") { pickingExercise = true }
            }
        }
        .forgeForm()
        .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(trimmedName.isEmpty)
            }
        }
        .sheet(isPresented: $pickingExercise) {
            NavigationStack {
                ExercisePickerView { addExercise($0) }
            }
        }
    }

    // MARK: Editing

    /// The routine only exists once something is actually added to it, so a
    /// cancelled "new routine" leaves nothing behind.
    private func ensureDraft() -> Routine {
        if let draft { return draft }
        let new = Routine(name: trimmedName)
        context.insert(new)
        draft = new
        return new
    }

    private func addExercise(_ exercise: Exercise) {
        let target = ensureDraft()
        target.items.append(RoutineItem(exercise: exercise, order: target.items.count))
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var ordered = items
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.order = index
        }
    }

    private func delete(_ offsets: IndexSet) {
        let ordered = items
        for index in offsets {
            context.delete(ordered[index])
        }
        for (index, item) in items.enumerated() {
            item.order = index
        }
    }

    private func save() {
        let target = ensureDraft()
        target.name = trimmedName
        try? context.save()
        dismiss()
    }

    private func cancel() {
        // Roll back a routine created during this editing session.
        if routine == nil, let draft {
            context.delete(draft)
            try? context.save()
        }
        dismiss()
    }
}

#Preview {
    NavigationStack { RoutineEditorView(routine: nil) }
        .modelContainer(PersistenceController.makeInMemoryContainer())
}
