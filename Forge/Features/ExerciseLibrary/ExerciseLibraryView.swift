import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name)
    private var exercises: [Exercise]

    @State private var search = ""
    @State private var editing: Exercise?
    @State private var creating = false
    @State private var deleteError: String?

    private var filtered: [Exercise] {
        guard !search.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(bodyPart: BodyPart, items: [Exercise])] {
        Dictionary(grouping: filtered, by: \.primaryBodyPart)
            .map { (bodyPart: $0.key, items: $0.value) }
            .sorted { $0.bodyPart.displayName < $1.bodyPart.displayName }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.bodyPart) { group in
                Section(group.bodyPart.displayName) {
                    ForEach(group.items) { exercise in
                        Button { editing = exercise } label: { row(exercise) }
                            .tint(.primary)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    delete(exercise)
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    exercise.isArchived = true
                                    try? context.save()
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search)
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "No exercises" : "No matches",
                    systemImage: "dumbbell",
                    description: Text(search.isEmpty
                                      ? "Add your first exercise with the + button."
                                      : "Nothing matches “\(search)”.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") { creating = true }
            }
        }
        .sheet(item: $editing) { exercise in
            NavigationStack { ExerciseEditorView(exercise: exercise) }
        }
        .sheet(isPresented: $creating) {
            NavigationStack { ExerciseEditorView(exercise: nil) }
        }
        .alert("Can't delete", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack {
            Text(exercise.name)
            Spacer()
            if exercise.isBodyweight { FlagTag("BW") }
            if exercise.isUnilateral { FlagTag("×2") }
        }
    }

    private func delete(_ exercise: Exercise) {
        guard ExerciseDeletion.canHardDelete(exercise) else {
            deleteError = "\(exercise.name) is used by a routine or a past workout. Archive it instead."
            return
        }
        context.delete(exercise)
        try? context.save()
    }
}

private struct FlagTag: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    PersistenceController.seedIfEmpty(container.mainContext)
    return NavigationStack { ExerciseLibraryView() }
        .modelContainer(container)
}
