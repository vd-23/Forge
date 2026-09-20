import SwiftUI
import ForgeCore

struct RoutineRow: View {
    let routine: Routine
    /// The most recent finished session from this routine, for the volume line.
    var lastSession: WorkoutSession?
    var isArchived: Bool = false
    let unit: WeightUnit
    /// `nil` for an archived routine — it has to be restored before it can run.
    let onStart: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink)
                Text("^[\(routine.orderedItems.count) exercise](inflect: true) · ~\(routine.estimatedMinutes) min")
                    .font(ForgeType.meta)
                    .foregroundStyle(ForgeColor.ink2)
                lastLine
            }

            Spacer(minLength: 8)

            if let onStart {
                Button { Haptics.tick(); onStart() } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "play.fill").font(.system(size: 13, weight: .bold))
                        Text("Start").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(ForgeColor.accentFill, in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            } else {
                Chip("Archived")
            }
        }
        .opacity(isArchived ? 0.6 : 1)
    }

    @ViewBuilder
    private var lastLine: some View {
        if let lastSession {
            HStack(spacing: 5) {
                Text(lastSession.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                Text("•")
                Text(WeightFormatting.display(sessionVolumeKg(lastSession.coreInput), unit: unit, fractionDigits: 0))
            }
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(ForgeColor.ink3)
        } else {
            Text("Not performed yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ForgeColor.ink3)
        }
    }
}
