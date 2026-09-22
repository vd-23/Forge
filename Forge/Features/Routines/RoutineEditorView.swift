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
    @State private var editingItem: RoutineItem?

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _draft = State(initialValue: routine)
    }

    private var items: [RoutineItem] { draft?.orderedItems ?? [] }

    private var trimmedName: String {
        Limits.cleanName(name) ?? ""
    }

    var body: some View {
        Form {
            Section {
                TextField("Routine name", text: $name)
                    .limitedLength($name)
            }

            Section {
                ForEach(items) { item in
                    itemRow(item)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)

                Button("Add exercises", systemImage: "plus") { pickingExercise = true }
            } header: {
                Text("Exercises")
            } footer: {
                if !items.isEmpty {
                    Text("Tap an exercise for rep and rest targets.")
                }
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
        .navigationDestination(item: $editingItem) { item in
            RoutineItemEditorView(item: item)
        }
        .sheet(isPresented: $pickingExercise) {
            NavigationStack {
                ExercisePickerView(onPickMany: addExercises)
            }
        }
    }

    /// Name on the left opens the target editor; the stepper on the right
    /// sets the set count without leaving the list.
    private func itemRow(_ item: RoutineItem) -> some View {
        HStack(spacing: 12) {
            Button {
                editingItem = item
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise?.name ?? "—")
                        .foregroundStyle(ForgeColor.ink)
                    if let target = RepRange.targetLabel(
                        sets: nil,
                        repMin: item.targetRepMin,
                        repMax: item.targetRepMax
                    ) {
                        Text(target)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Stepper(
                value: Binding(
                    get: { item.targetSets ?? RoutineEditing.defaultTargetSets },
                    set: { Haptics.selection(); RoutineEditing.setTargetSets(item, to: $0) }
                ),
                in: 1...Limits.maxSetsPerExercise
            ) {
                Text("^[\(item.targetSets ?? RoutineEditing.defaultTargetSets) set](inflect: true)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(ForgeColor.ink2)
            }
            .fixedSize()
        }
    }

    // MARK: Editing

    /// The routine only exists once something is actually added to it, so a
    /// cancelled "new routine" leaves nothing behind.
    private func ensureDraft() -> Routine {
        if let draft { return draft }
        let new = Routine(name: trimmedName)
        new.sortOrder = RoutineOrdering.nextSortOrder(in: context)
        context.insert(new)
        draft = new
        return new
    }

    private func addExercises(_ exercises: [Exercise]) {
        RoutineEditing.add(exercises, to: ensureDraft())
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
        guard !trimmedName.isEmpty else { return }
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
