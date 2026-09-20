import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context

    /// Both scopes come from one query and are split in Swift: `@Query`'s
    /// predicate is fixed at declaration, and a personal library is small.
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var scope: ArchiveScope = .active
    @State private var search = ""
    @State private var creating = false
    @State private var deleteError: String?

    private var filtered: [Exercise] {
        let inScope = allExercises.filter { $0.isArchived == scope.isArchived }
        guard !search.isEmpty else { return inScope }
        return inScope.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(bodyPart: BodyPart, items: [Exercise])] {
        Dictionary(grouping: filtered, by: \.primaryBodyPart)
            .map { (bodyPart: $0.key, items: $0.value) }
            .sorted { $0.bodyPart.displayName < $1.bodyPart.displayName }
    }

    private var hasArchived: Bool {
        allExercises.contains(where: \.isArchived)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.bodyPart) { group in
                    Section {
                        ForEach(group.items) { exercise in
                            NavigationLink(value: exercise) { row(exercise) }
                                .swipeActions(edge: .trailing) { actions(for: exercise) }
                                .listRowBackground(ForgeColor.surface)
                                .listRowSeparatorTint(ForgeColor.divider)
                        }
                    } header: {
                        SectionLabel(group.bodyPart.displayName).textCase(nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .forgeBackground()
            .navigationTitle("Exercises")
            .searchable(text: $search)
            .overlay {
                if filtered.isEmpty { emptyState }
            }
            .toolbar {
                if hasArchived {
                    ToolbarItem(placement: .topBarLeading) { scopeMenu }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add", systemImage: "plus") { creating = true }
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
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
    }

    // MARK: Rows

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 8) {
            Text(exercise.name)
                .font(.body)
                .foregroundStyle(ForgeColor.ink)
            Spacer()
            if exercise.isBodyweight { Chip("BW") }
            if exercise.isUnilateral { Chip("×2") }
        }
        .padding(.vertical, 4)
        .opacity(scope.isArchived ? 0.6 : 1)
    }

    @ViewBuilder
    private func actions(for exercise: Exercise) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            delete(exercise)
        }
        .tint(.red)
        if scope.isArchived {
            Button("Unarchive", systemImage: "arrow.uturn.backward") {
                exercise.isArchived = false
                try? context.save()
            }
            .tint(.green)
        } else {
            Button("Archive", systemImage: "archivebox") {
                exercise.isArchived = true
                try? context.save()
            }
            .tint(.orange)
        }
    }

    // MARK: Chrome

    private var scopeMenu: some View {
        Menu {
            Picker("Show", selection: $scope) {
                ForEach(ArchiveScope.allCases) { Text($0.displayName).tag($0) }
            }
        } label: {
            Label("Show", systemImage: scope.isArchived ? "archivebox.fill" : "archivebox")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !search.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "dumbbell",
                description: Text("Nothing matches “\(search)”.")
            )
        } else if scope.isArchived {
            ContentUnavailableView {
                Label("No archived exercises", systemImage: "archivebox")
            } actions: {
                Button("Show active") { scope = .active }
            }
        } else {
            ContentUnavailableView(
                "No exercises",
                systemImage: "dumbbell",
                description: Text("Add your first exercise with the + button.")
            )
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


#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    PersistenceController.seedIfEmpty(container.mainContext)
    return ExerciseLibraryView()
        .modelContainer(container)
}
