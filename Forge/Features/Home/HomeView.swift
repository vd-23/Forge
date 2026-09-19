import SwiftUI
import SwiftData
import Charts
import ForgeCore

struct HomeView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil })
    private var sessions: [WorkoutSession]

    @AppStorage(Preferences.Key.weightUnit, store: Preferences.defaults)
    private var unit: WeightUnit = .kg

    @State private var summary: HomeSummary = .empty
    @State private var selected: WorkoutSession?

    private let calendar = Calendar.current

    /// Recomputing on every body evaluation would mean re-walking history for
    /// `recentPRs`, so the summary is rebuilt only when history actually moves.
    /// Editing sets in place (Checkpoint E) will need to feed this too.
    private var revision: Int {
        var hasher = Hasher()
        hasher.combine(sessions.count)
        for session in sessions { hasher.combine(session.endedAt) }
        return hasher.finalize()
    }

    var body: some View {
        NavigationStack {
            Group {
                if summary.hasHistory {
                    content
                } else {
                    ContentUnavailableView {
                        Label("No workouts yet", systemImage: "square.grid.3x3")
                    } description: {
                        Text("Finish a workout and your streak, heatmap and records will appear here.")
                    }
                }
            }
            .navigationTitle("Home")
            .navigationDestination(item: $selected) { session in
                SessionDetailView(session: session)
            }
        }
        .task(id: revision) {
            summary = HomeSummaryBuilder.build(sessions: sessions, calendar: calendar)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                streaks
                consistency
                thisWeek
                volumeChart
                if !summary.recentPRs.isEmpty { records }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Sections

    private var streaks: some View {
        HStack(spacing: 12) {
            // The inflection markup only resolves in a string literal, so the
            // `Text` is built here rather than inside `StatCard`.
            StatCard(
                title: "Current streak",
                value: Text("^[\(summary.currentStreak) day](inflect: true)"),
                systemImage: "flame.fill",
                tint: summary.currentStreak > 0 ? .orange : .secondary
            )
            StatCard(
                title: "Longest streak",
                value: Text("^[\(summary.longestStreak) day](inflect: true)"),
                systemImage: "trophy.fill",
                tint: .yellow
            )
        }
    }

    private var consistency: some View {
        Card(title: "Consistency") {
            VStack(alignment: .leading, spacing: 10) {
                HeatmapView(weeks: summary.weeks) { day in
                    selected = session(on: day)
                }
                HeatmapLegend()
            }
        }
    }

    private var thisWeek: some View {
        Card(title: "This week") {
            HStack {
                LabeledContent("Workouts", value: "\(summary.thisWeekWorkouts)")
                Spacer(minLength: 24)
                LabeledContent("Volume", value: WeightFormatting.display(
                    summary.thisWeekVolumeKg, unit: unit, fractionDigits: 0
                ))
            }
        }
    }

    private var volumeChart: some View {
        Card(title: "Last 30 days") {
            if summary.dailyVolume.isEmpty {
                Text("No workouts in the last 30 days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(summary.dailyVolume, id: \.date) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Volume", WeightFormatting.editableValue(point.value, unit: unit))
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private var records: some View {
        Card(title: "Recent records") {
            VStack(spacing: 0) {
                ForEach(Array(summary.recentPRs.enumerated()), id: \.element.id) { index, record in
                    if index > 0 { Divider() }
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.exerciseName)
                            Text(record.kind.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        RelativeDateText(date: record.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    /// The heatmap knows dates; the navigation needs the model object.
    private func session(on day: Date) -> WorkoutSession? {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .max { $0.startedAt < $1.startedAt }
    }
}

// MARK: Building blocks

private struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}

private struct StatCard: View {
    let title: String
    let value: Text
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
            value
                .font(.title2.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }
}
