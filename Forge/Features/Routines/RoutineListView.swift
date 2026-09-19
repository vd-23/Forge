import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var controller

    /// Both scopes come from one query and are split in Swift: `@Query`'s
    /// predicate is fixed at declaration, and a personal library is small.
    @Query(sort: \Routine.name) private var allRoutines: [Routine]

    @State private var scope: ArchiveScope = .active
    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false
    @State private var path: [RoutineDestination] = []

    private var routines: [Routine] {
        allRoutines.filter { $0.isArchived == scope.isArchived }
    }

    private var hasArchived: Bool {
        allRoutines.contains(where: \.isArchived)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if routines.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(routines) { routine in
                            row(routine)
                        }
                    }
                }
            }
            .navigationTitle("Workout")
            .toolbar {
                if hasArchived {
                    ToolbarItem(placement: .topBarLeading) { scopeMenu }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Routine", systemImage: "plus") { creatingRoutine = true }
                }
            }
            .navigationDestination(for: RoutineDestination.self) { destination in
                switch destination {
                case let .detail(routine, autoStart):
                    RoutineDetailView(routine: routine, autoStart: autoStart, path: $path)
                case let .activeWorkout(session):
                    ActiveWorkoutView(session: session, controller: controller)
                }
            }
            .sheet(item: $editingRoutine) { routine in
                NavigationStack { RoutineEditorView(routine: routine) }
            }
            .sheet(isPresented: $creatingRoutine) {
                NavigationStack { RoutineEditorView(routine: nil) }
            }
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ routine: Routine) -> some View {
        if scope.isArchived {
            RoutineRow(routine: routine, isArchived: true, onStart: nil)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteOrArchive(routine)
                    }
                    Button("Unarchive", systemImage: "arrow.uturn.backward") {
                        routine.isArchived = false
                        try? context.save()
                    }
                    .tint(.green)
                }
        } else {
            RoutineRow(routine: routine) {
                path.append(.detail(routine, autoStart: true))
            }
            .contentShape(.rect)
            .onTapGesture {
                path.append(.detail(routine, autoStart: false))
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteOrArchive(routine)
                }
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    RoutineDuplication.duplicate(routine, into: context)
                    try? context.save()
                }
                .tint(.indigo)
                Button("Edit", systemImage: "pencil") {
                    editingRoutine = routine
                }
                .tint(.gray)
            }
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
        if scope.isArchived {
            ContentUnavailableView {
                Label("No archived routines", systemImage: "archivebox")
            } actions: {
                Button("Show active") { scope = .active }
            }
        } else {
            ContentUnavailableView {
                Label("No routines yet", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Create a routine to start logging workouts.")
            } actions: {
                Button("New Routine") { creatingRoutine = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    /// A routine referenced by a past session is archived instead, so that
    /// session keeps its context.
    private func deleteOrArchive(_ routine: Routine) {
        if RoutineDeletion.canHardDelete(routine) {
            context.delete(routine)
        } else {
            routine.isArchived = true
        }
        try? context.save()
    }
}

/// Typed navigation targets for the Workout tab. Every push in this tab goes
/// through here so the stack is declared in exactly one place.
enum RoutineDestination: Hashable {
    case detail(Routine, autoStart: Bool)
    case activeWorkout(WorkoutSession)
}

#Preview {
    let container = PersistenceController.makeInMemoryContainer()
    PersistenceController.seedIfEmpty(container.mainContext)
    return RoutineListView()
        .modelContainer(container)
        .environment(WorkoutController(context: container.mainContext))
}
