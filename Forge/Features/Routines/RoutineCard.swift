import SwiftUI

/// One tile in the Workout tab grid: name, the exercises inside, and a small
/// Start button. Tapping the tile opens the routine; the button starts it.
struct RoutineCard: View {
    let routine: Routine
    var isArchived: Bool = false
    /// `nil` for an archived routine — it has to be restored before it can run.
    let onStart: (() -> Void)?

    private var items: [RoutineItem] {
        routine.orderedItems.filter { $0.exercise != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(routine.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onStart {
                    Button { Haptics.tick(); onStart() } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(ForgeColor.accentFill, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(routine.name)")
                }
            }

            // Every exercise, not a preview: the grid doubles as a shareable
            // overview of the whole programme.
            VStack(alignment: .leading, spacing: 4) {
                if items.isEmpty {
                    Text("No exercises yet")
                        .foregroundStyle(ForgeColor.ink3)
                }
                ForEach(items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(item.exercise?.name ?? "")
                            .foregroundStyle(ForgeColor.ink2)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let sets = item.targetSets {
                            Text("\(sets)×")
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(ForgeColor.ink3)
                        }
                    }
                }
            }
            .font(.system(size: 13, weight: .medium))

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("~\(routine.estimatedMinutes) min")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(ForgeColor.ink3)
                Spacer()
                if isArchived { Chip("Archived") }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .card(padding: 14, radius: 18)
        .opacity(isArchived ? 0.6 : 1)
    }
}
