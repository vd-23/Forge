import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var controller

    /// Both scopes come from one query and are split in Swift: `@Query`'s
    /// predicate is fixed at declaration, and a personal library is small.
    @Query(sort: \Routine.name) private var allRoutines: [Routine]

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var finishedSessions: [WorkoutSession]

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    @State private var scope: ArchiveScope = .active
    @State private var editingRoutine: Routine?
    @State private var creatingRoutine = false
    @Binding var path: [RoutineDestination]

    private var routines: [Routine] {
        allRoutines.filter { $0.isArchived == scope.isArchived }
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

    // MARK: List

    private var list: some View {
        List {
            if let active = controller.activeSession {
                ResumeBanner(session: active) {
                    path.append(.activeWorkout(active))
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(routines) { routine in
                    row(routine)
                        .card(padding: 16)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !scope.isArchived {
                    Button("New routine", systemImage: "plus") { creatingRoutine = true }
                        .buttonStyle(GhostButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Label("Tap a row for detail · swipe for edit, duplicate, delete", systemImage: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ForgeColor.ink3)
                        .listRowInsets(EdgeInsets(top: 2, leading: 18, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            } header: {
                SectionLabel(scope.isArchived ? "Archived routines" : "Routines")
                    .textCase(nil)
                    .padding(.leading, -2)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListHeaderHeight, 0)
    }

    // MARK: Rows

    @ViewBuilder
    private func row(_ routine: Routine) -> some View {
        let last = finishedSessions.first { $0.sourceRoutine?.id == routine.id }
        if scope.isArchived {
            RoutineRow(routine: routine, lastSession: last, isArchived: true, unit: unit, onStart: nil)
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deleteOrArchive(routine)
                    }
                    .tint(.red)
                    Button("Unarchive", systemImage: "arrow.uturn.backward") {
                        routine.isArchived = false
                        try? context.save()
                    }
                    .tint(.green)
                }
        } else {
            RoutineRow(routine: routine, lastSession: last, unit: unit) {
                path.append(.detail(routine, autoStart: true))
            }
            .contentShape(.rect)
            .onTapGesture {
                Haptics.tap()
                path.append(.detail(routine, autoStart: false))
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deleteOrArchive(routine)
                }
                .tint(.red)
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
