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
            .forgeBackground()
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
                    Section {
                        rows(section.sessions)
                    } header: {
                        SectionLabel(section.title, trailing: summary(of: section.sessions)).textCase(nil)
                    }
                }
            } else {
                Section {
                    rows(visible)
                } header: {
                    SectionLabel(sort.displayName, trailing: summary(of: visible)).textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func summary(of sessions: [WorkoutSession]) -> String {
        let volume = sessions.reduce(0) { $0 + sessionVolumeKg($1.coreInput) }
        let count = sessions.count
        return "\(count) workout\(count == 1 ? "" : "s") · \(WeightFormatting.number(volume, unit: unit, fractionDigits: 0)) \(unit.rawValue)"
    }

    private func rows(_ sessions: [WorkoutSession]) -> some View {
        let maxVolume = sessions.map { sessionVolumeKg($0.coreInput) }.max() ?? 0
        return ForEach(sessions) { session in
            NavigationLink(value: session) {
                HistoryRow(session: session, unit: unit, maxVolumeKg: maxVolume)
            }
            .listRowBackground(ForgeColor.surface)
            .listRowSeparatorTint(ForgeColor.divider)
            .swipeActions(edge: .trailing) {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    pendingDeletion = session
                }
                .tint(.red)
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
    /// Largest volume in the same section, so the bar under each figure reads
    /// relative to its neighbours.
    let maxVolumeKg: Double

    var body: some View {
        let volume = sessionVolumeKg(session.coreInput)

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.sourceRoutineName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink)
                HStack(spacing: 5) {
                    Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    if let seconds = session.durationSeconds {
                        Text("·")
                        Text(DurationFormatting.short(seconds: seconds))
                    }
                }
                .font(ForgeType.meta)
                .foregroundStyle(ForgeColor.ink3)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                MeasureText(
                    value: WeightFormatting.number(volume, unit: unit, fractionDigits: 0),
                    unit: unit.rawValue,
                    valueFont: .system(size: 17, weight: .bold).monospacedDigit(),
                    unitFont: .system(size: 11, weight: .medium)
                )
                Capsule()
                    .fill(ForgeColor.hairline)
                    .frame(width: 72, height: 3)
                    .overlay(alignment: .trailing) {
                        Capsule()
                            .fill(ForgeColor.accent)
                            .frame(width: maxVolumeKg > 0 ? 72 * volume / maxVolumeKg : 0)
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
