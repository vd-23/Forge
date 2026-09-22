import SwiftUI
import ForgeCore

/// GitHub-style consistency grid: one column per week, one cell per day, sized
/// to fill the card so the whole window is visible at once.
struct HeatmapView: View {
    let weeks: [HeatmapWeek]
    let onSelect: (Date) -> Void

    private let gap: CGFloat = 3.5
    private let labelHeight: CGFloat = 14

    /// Measured, so the cell size follows the card width and the grid keeps
    /// its intrinsic height.
    @State private var width: CGFloat = 0

    private var cell: CGFloat {
        let columns = CGFloat(max(weeks.count, 1))
        return max(0, (width - gap * (columns - 1)) / columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            monthLabels(cell: cell)
            HStack(alignment: .top, spacing: gap) {
                ForEach(weeks) { week in
                    VStack(spacing: gap) {
                        ForEach(week.days) { day in
                            cellView(day, size: cell)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    private var visibleLabels: [Date: String] {
        HeatmapLabels.visible(weeks.map { ($0.id, $0.monthLabel) })
    }

    private func monthLabels(cell: CGFloat) -> some View {
        let labels = visibleLabels
        return HStack(spacing: gap) {
            ForEach(weeks) { week in
                Text((labels[week.id] ?? "").uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(ForgeColor.ink3)
                    .fixedSize()
                    .frame(width: cell, alignment: .leading)
            }
        }
        .frame(height: labelHeight)
    }

    @ViewBuilder
    private func cellView(_ day: HeatmapDay, size: CGFloat) -> some View {
        if day.isFuture {
            Color.clear.frame(width: size, height: size)
        } else {
            Button { onSelect(day.date) } label: {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(HeatPalette.colour(for: day.level))
                    .frame(width: size, height: size)
            }
            .buttonStyle(.plain)
            .disabled(day.level == .none)
            .accessibilityLabel(
                "\(day.date.formatted(date: .abbreviated, time: .omitted)), \(HeatPalette.describe(day.level))"
            )
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
                    .fill(HeatPalette.colour(for: level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(ForgeColor.ink3)
    }
}

enum HeatPalette {
    /// A rest day stays visible as a flat neutral square rather than a gap —
    /// the shape of the grid is what makes the streaks readable.
    static func colour(for level: HeatLevel) -> Color {
        switch level {
        case .none: ForgeColor.heatEmpty
        case .light: ForgeColor.accent.opacity(0.3)
        case .moderate: ForgeColor.accent.opacity(0.5)
        case .heavy: ForgeColor.accent.opacity(0.75)
        case .maximal: ForgeColor.accent
        }
    }

    static func describe(_ level: HeatLevel) -> String {
        switch level {
        case .none: "rest day"
        case .light: "light session"
        case .moderate: "moderate session"
        case .heavy: "heavy session"
        case .maximal: "very heavy session"
        }
    }
}

/// Which month labels fit above the grid. A label needs about three columns
/// of room, so one that would run into its neighbour is dropped — a month that
/// begins in the window's first column or two, or two short months in a row.
enum HeatmapLabels {
    static let minimumSpacing = 3

    static func visible<ID: Hashable>(_ columns: [(id: ID, label: String?)]) -> [ID: String] {
        let labelled = columns.enumerated().compactMap { index, column in
            column.label.map { (index: index, id: column.id, label: $0) }
        }
        var result: [ID: String] = [:]
        var lastKept: Int?
        for (position, entry) in labelled.enumerated() {
            if let lastKept, entry.index - lastKept < minimumSpacing { continue }
            let next = position + 1 < labelled.count ? labelled[position + 1].index : columns.count
            let isLast = position == labelled.count - 1
            guard next - entry.index >= minimumSpacing || isLast else { continue }
            result[entry.id] = entry.label
            lastKept = entry.index
        }
        return result
    }
}
