import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var controller

    /// Both scopes come from one query and are split in Swift: `@Query`'s
    /// predicate is fixed at declaration, and a personal library is small.
    @Query private var allRoutines: [Routine]

    @State private var scope: ArchiveScope = .active
    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false
    @State private var reordering = false
    @Binding var path: [RoutineDestination]

    private var routines: [Routine] {
        RoutineOrdering.ordered(allRoutines.filter { $0.isArchived == scope.isArchived })
    }

    private var hasArchived: Bool {
        allRoutines.contains(where: \.isArchived)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if routines.isEmpty && controller.activeSession == nil {
                    emptyState
                } else {
                    list
                }
            }
            .forgeBackground()
            .navigationTitle("Workout")
            .toolbar {
                if hasArchived {
                    ToolbarItem(placement: .topBarLeading) { scopeMenu }
                }
                if routines.count > 1, !scope.isArchived {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Reorder", systemImage: "arrow.up.arrow.down") { reordering = true }
                    }
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
            .sheet(isPresented: $reordering) {
                NavigationStack { RoutineReorderView(routines: routines) }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: Grid

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let active = controller.activeSession {
                    ResumeBanner(session: active) {
                        path.append(.activeWorkout(active))
                    }
                }

                SectionLabel(scope.isArchived ? "Archived routines" : "Routines")
                    .padding(.leading, 2)
                    .padding(.top, controller.activeSession == nil ? 0 : 6)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(routines) { routine in
                        tile(routine)
                    }
                }

                if !scope.isArchived {
                    Button("New routine", systemImage: "plus") { creatingRoutine = true }
                        .buttonStyle(GhostButtonStyle())
                        .padding(.top, 4)

                    Label("Tap a tile for detail · hold for edit, duplicate, delete", systemImage: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ForgeColor.ink3)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    // MARK: Tiles

    @ViewBuilder
    private func tile(_ routine: Routine) -> some View {
        if scope.isArchived {
            RoutineCard(routine: routine, isArchived: true, onStart: nil)
                .contextMenu {
                    Button("Unarchive", systemImage: "arrow.uturn.backward") {
                        routine.isArchived = false
                        try? context.save()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteOrArchive(routine)
                    }
                }
        } else {
            RoutineCard(routine: routine) {
                path.append(.detail(routine, autoStart: true))
            }
            .contentShape(.rect)
            .onTapGesture {
                Haptics.tap()
                path.append(.detail(routine, autoStart: false))
            }
            .contextMenu {
                Button("Edit", systemImage: "pencil") { editingRoutine = routine }
                Button("Duplicate", systemImage: "plus.square.on.square") {
                    RoutineDuplication.duplicate(routine, into: context)
                    try? context.save()
                }
                Button("Reorder", systemImage: "arrow.up.arrow.down") { reordering = true }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteOrArchive(routine)
                }
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
                    .buttonStyle(.glassProminent)
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

/// Shown above the routines while a workout is open, so getting back to it
/// never requires starting another and hitting the conflict alert.
private struct ResumeBanner: View {
    let session: WorkoutSession
    let onResume: () -> Void

    var body: some View {
        let total = session.exercises.reduce(0) { $0 + $1.sets.count }
        let done = session.exercises.reduce(0) { $0 + $1.sets.filter(\.isComplete).count }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(ForgeColor.accent).frame(width: 6, height: 6)
                        SectionLabel("In progress")
                    }
                    Text(session.sourceRoutineName)
                        .font(ForgeType.cardTitle)
                        .foregroundStyle(ForgeColor.ink)
                    HStack(spacing: 4) {
                        Text(session.startedAt, style: .timer).monospacedDigit()
                        Text("elapsed · \(done) of \(total) sets")
                    }
                    .font(ForgeType.meta)
                    .foregroundStyle(ForgeColor.ink2)
                }
                Spacer()
                Button("Resume") { Haptics.tick(); onResume() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.regular)
            }
            SegmentedProgress(segments: session.orderedExercises.map { exercise in
                let sets = exercise.sets
                guard !sets.isEmpty else { return 0 }
                return Double(sets.filter(\.isComplete).count) / Double(sets.count)
            })
        }
        .card(fill: ForgeColor.accentSoft)
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
    return RoutineListView(path: .constant([]))
        .modelContainer(container)
        .environment(WorkoutController(context: container.mainContext))
}
