import SwiftUI
import ForgeCore

/// GitHub-style consistency grid: one column per week, one cell per day.
/// Scrolls horizontally and starts scrolled to the present.
struct HeatmapView: View {
    let weeks: [HeatmapWeek]
    let onSelect: (Date) -> Void

    private let cell: CGFloat = 15
    private let gap: CGFloat = 3

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(weeks) { week in
                    column(week)
                        .id(week.id)
                }
            }
            .padding(.vertical, 2)
            .scrollTargetLayout()
        }
        .defaultScrollAnchor(.trailing)
    }

    private func column(_ week: HeatmapWeek) -> some View {
        VStack(alignment: .leading, spacing: gap) {
            Text(week.monthLabel ?? " ")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(height: 12, alignment: .leading)
                .fixedSize()
                // Labels are wider than a column, so they must not stretch it.
                .frame(width: cell, alignment: .leading)

            ForEach(week.days) { day in
                cellView(day)
            }
        }
    }

    @ViewBuilder
    private func cellView(_ day: HeatmapDay) -> some View {
        if day.isFuture {
            Color.clear.frame(width: cell, height: cell)
        } else {
            Button { onSelect(day.date) } label: {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(colour(for: day.level))
                    .frame(width: cell, height: cell)
            }
            .buttonStyle(.plain)
            .disabled(day.level == .none)
            .accessibilityLabel(
                "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(describe(day.level))"
            )
        }
    }

    /// A rest day stays visible as a flat neutral square rather than a gap —
    /// the shape of the grid is what makes the streaks readable.
    private func colour(for level: HeatLevel) -> Color {
        switch level {
        case .none: Color.secondary.opacity(0.15)
        case .light: Color.accentColor.opacity(0.3)
        case .moderate: Color.accentColor.opacity(0.5)
        case .heavy: Color.accentColor.opacity(0.75)
        case .maximal: Color.accentColor
        }
    }

    private func describe(_ level: HeatLevel) -> String {
        switch level {
        case .none: "rest day"
        case .light: "light session"
        case .moderate: "moderate session"
        case .heavy: "heavy session"
        case .maximal: "very heavy session"
        }
    }
}

/// The colour key under the grid.
struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Less")
            ForEach(HeatLevel.allCases, id: \.rawValue) { level in
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(colour(for: level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func colour(for level: HeatLevel) -> Color {
        switch level {
        case .none: Color.secondary.opacity(0.15)
        case .light: Color.accentColor.opacity(0.3)
        case .moderate: Color.accentColor.opacity(0.5)
        case .heavy: Color.accentColor.opacity(0.75)
        case .maximal: Color.accentColor
        }
    }
}
