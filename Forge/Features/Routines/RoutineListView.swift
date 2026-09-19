import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var controller
    @Query(filter: #Predicate<Routine> { !$0.isArchived }, sort: \Routine.name)
    private var routines: [Routine]

    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false
    @State private var path: [RoutineDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No routines yet", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a routine to start logging workouts.")
                    } actions: {
                        Button("New Routine") { creatingRoutine = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(routines) { routine in
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
                }
            }
            .navigationTitle("Workout")
            .toolbar {
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
