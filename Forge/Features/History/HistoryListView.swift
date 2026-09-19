import SwiftUI
import SwiftData
import ForgeCore

struct HistoryListView: View {
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil })
    private var sessions: [WorkoutSession]

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    @State private var sort: HistorySort = .newest
    @State private var routineFilter: String?
    @State private var pendingDeletion: WorkoutSession?

    private var visible: [WorkoutSession] {
        HistoryFiltering.apply(to: sessions, sort: sort, routine: routineFilter)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No workouts yet", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Finished workouts show up here.")
                    }
                } else if visible.isEmpty {
                    ContentUnavailableView {
                        Label("No matching workouts", systemImage: "line.3.horizontal.decrease.circle")
                    } actions: {
                        Button("Show all routines") { routineFilter = nil }
                    }
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !sessions.isEmpty {
                    ToolbarItem(placement: .primaryAction) { sortAndFilterMenu }
                }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
            .alert("Delete this workout?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), presenting: pendingDeletion) { session in
                Button("Delete", role: .destructive) { delete(session) }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { session in
                Text("\"\(session.sourceRoutineName)\" and every set logged in it will be removed. This can't be undone.")
            }
        }
    }

    /// Nothing else refers to a session, so unlike exercises and routines it has
    /// no archived state — deleting cascades to its exercises and sets.
    private func delete(_ session: WorkoutSession) {
        pendingDeletion = nil
        context.delete(session)
        try? context.save()
    }

    private var list: some View {
        List {
            if sort.groupsByMonth {
                ForEach(MonthGrouping.sections(visible, newestFirst: sort == .newest)) { section in
                    Section(section.title) { rows(section.sessions) }
                }
            } else {
                Section { rows(visible) }
            }
        }
    }

    private func rows(_ sessions: [WorkoutSession]) -> some View {
        ForEach(sessions) { session in
            NavigationLink(value: session) {
                HistoryRow(session: session, unit: unit)
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingDeletion = session
                }
            }
        }
    }

    private var sortAndFilterMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(HistorySort.allCases) { Text($0.displayName).tag($0) }
            }

            Picker("Routine", selection: $routineFilter) {
                Text("All routines").tag(String?.none)
                ForEach(HistoryFiltering.routineNames(in: sessions), id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
        } label: {
            Label(
                "Sort and filter",
                systemImage: routineFilter == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}

private struct HistoryRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.sourceRoutineName)
                .font(.headline)

            HStack(spacing: 6) {
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                if let seconds = session.durationSeconds {
                    Text("·")
                    Text(DurationFormatting.short(seconds: seconds))
                }
                Text("·")
                Text(WeightFormatting.display(
                    sessionVolumeKg(session.coreInput), unit: unit, fractionDigits: 0
                ))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
