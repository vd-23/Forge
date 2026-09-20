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

    private let calendar = Calendar.forge

    /// Recomputing on every body evaluation would mean re-walking history for
    /// `recentPRs`, so the summary is rebuilt only when history actually moves.
    private var revision: Int {
        var hasher = Hasher()
        hasher.combine(sessions.count)
        for session in sessions {
            hasher.combine(session.endedAt)
            hasher.combine(session.exercises.reduce(0) { $0 + $1.sets.count })
        }
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
            .forgeBackground()
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(ForgeType.meta)
                        .foregroundStyle(ForgeColor.ink2)
                }
                .sharedBackgroundVisibility(.hidden)
            }
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
            VStack(alignment: .leading, spacing: 14) {
                streaks
                consistency
                SectionLabel("This week").padding(.top, 8)
                thisWeek
                volumeChart
                if !summary.recentPRs.isEmpty {
                    SectionLabel("Recent records").padding(.top, 8)
                    records
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: Streak

    private var streaks: some View {
        HStack(spacing: 12) {
            StreakTile(
                title: "Current streak",
                days: summary.currentStreak,
                systemImage: "flame.fill",
                tint: .orange
            )
            StreakTile(
                title: "Longest streak",
                days: summary.longestStreak,
                systemImage: "trophy.fill",
                tint: .yellow
            )
        }
    }

    // MARK: Consistency

    private var consistency: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Consistency").font(ForgeType.cardTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                Text("\(summary.weeks.count) weeks").font(ForgeType.meta).foregroundStyle(ForgeColor.ink3)
            }
            HeatmapView(weeks: summary.weeks) { day in
                selected = session(on: day)
            }
            HeatmapLegend()
        }
        .card()
    }

    // MARK: This week

    private var thisWeek: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Workouts")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(summary.thisWeekWorkouts)")
                        .font(ForgeType.stat)
                        .foregroundStyle(ForgeColor.ink)
                    let delta = summary.thisWeekWorkouts - summary.lastWeekWorkouts
                    if delta != 0 {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.system(size: 13, weight: .bold).monospacedDigit())
                            .foregroundStyle(delta > 0 ? ForgeColor.accentInk : ForgeColor.ink3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle().fill(ForgeColor.divider).frame(width: 1, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Volume")
                MeasureText(
                    value: WeightFormatting.number(summary.thisWeekVolumeKg, unit: unit, fractionDigits: 0),
                    unit: unit.rawValue
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 18)
        }
        .card()
    }

    // MARK: Volume

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily volume").font(ForgeType.cardTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                Text("Last 30 days").font(ForgeType.meta).foregroundStyle(ForgeColor.ink3)
            }
            if summary.dailyVolume.isEmpty {
                Text("No workouts in the last 30 days.")
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.ink3)
            } else {
                let latest = summary.dailyVolume.last?.date
                let window = HomeSummaryBuilder.window(ofLastDays: 30, endingOn: .now, calendar: calendar)
                Chart(summary.dailyVolume, id: \.date) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Volume", WeightFormatting.editableValue(point.value, unit: unit)),
                        width: .ratio(0.55)
                    )
                    .cornerRadius(2)
                    .foregroundStyle(point.date == latest ? ForgeColor.accent : ForgeColor.accent.opacity(0.52))
                }
                .chartXScale(domain: window.start...window.end)
                .chartXAxis {
                    AxisMarks(values: weekLabelDates(in: window)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ForgeColor.ink3)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(ForgeColor.hairline)
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Self.compact(v))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ForgeColor.ink3)
                            }
                        }
                    }
                }
                .frame(height: 140)
            }
        }
        .card()
    }

    /// One label a week, starting a couple of days in so the first and last
    /// labels sit inside the plot instead of clipping at its edges.
    private func weekLabelDates(in window: DateInterval) -> [Date] {
        guard let first = calendar.date(byAdding: .day, value: 2, to: window.start) else { return [] }
        return stride(from: 0, to: 4, by: 1).compactMap {
            calendar.date(byAdding: .day, value: 7 * $0, to: first)
        }
    }

    private static func compact(_ value: Double) -> String {
        value >= 1000 ? "\(Int((value / 1000).rounded()))k" : "\(Int(value))"
    }

    // MARK: Records

    private var records: some View {
        VStack(spacing: 0) {
            ForEach(Array(summary.recentPRs.enumerated()), id: \.element.id) { index, record in
                if index > 0 { CardDivider() }
                HStack(spacing: 12) {
                    Text("PR")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(ForgeColor.accentInk)
                        .frame(width: 30, height: 22)
                        .background(ForgeColor.accentSoft, in: .rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.exerciseName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ForgeColor.ink)
                        HStack(spacing: 0) {
                            Text(record.kind.shortName)
                            Text(" · ")
                            RelativeDateText(date: record.date, style: .compact)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ForgeColor.ink3)
                    }
                    Spacer()
                    recordValue(record)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 18)
            }
        }
        .card(padding: 0)
    }

    private func recordValue(_ record: HomePRRow) -> some View {
        let value: String
        let unitLabel: String?
        switch record.kind {
        case .reps:
            value = "\(Int(record.value))"
            unitLabel = "reps"
        case .weight, .e1rm:
            value = WeightFormatting.number(record.value, unit: unit, fractionDigits: 0)
            unitLabel = unit.rawValue
        }
        return MeasureText(
            value: value,
            unit: unitLabel,
            valueFont: .system(size: 17, weight: .bold).monospacedDigit(),
            unitFont: .system(size: 12, weight: .medium)
        )
    }

    /// The heatmap knows dates; the navigation needs the model object.
    private func session(on day: Date) -> WorkoutSession? {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .max { $0.startedAt < $1.startedAt }
    }
}

private struct StreakTile: View {
    let title: String
    let days: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint)
            // The inflection markup only resolves in a string literal.
            Text("^[\(days) day](inflect: true)")
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(ForgeColor.ink)
        }
        .card(padding: 16)
    }
}

extension PRKind {
    var shortName: String {
        switch self {
        case .weight: "Heaviest weight"
        case .reps: "Most reps"
        case .e1rm: "Best est. 1RM"
        }
    }
}
