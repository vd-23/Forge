import SwiftUI

/// The rest countdown, drawn inside the tab bar's bottom accessory so it floats
/// on system glass and follows the user across tabs. `RestTimer` stores only an
/// end date, so a `TimelineView` tick derives the remaining seconds and tells
/// the timer when it has run out. Tapping the clock (not the −30/+30/Skip
/// controls) jumps back to the workout that's resting.
struct RestTimerBar: View {
    let timer: RestTimer
    let onTap: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remaining(at: context.date)
            Group {
                if placement == .inline {
                    compact(remaining: remaining)
                } else {
                    expanded(remaining: remaining)
                }
            }
            .onChange(of: context.date) { _, now in
                timer.expireIfNeeded(at: now)
            }
        }
    }

    private func expanded(remaining: Int) -> some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 0) {
                    SectionLabel("Rest")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Self.clock(remaining))
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                            .foregroundStyle(ForgeColor.ink)
                        if let note = timer.note {
                            Text(note)
                                .font(ForgeType.meta)
                                .foregroundStyle(ForgeColor.ink2)
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)
            Button("−30") { Haptics.tap(); timer.addSeconds(-30) }
            Button("+30") { Haptics.tap(); timer.addSeconds(30) }
            Button("Skip") { Haptics.tap(); timer.skip() }
                .buttonStyle(.glassProminent)
        }
        .buttonStyle(.glass)
        .font(.system(size: 14, weight: .semibold))
        .padding(.leading, 18)
        .padding(.trailing, 10)
    }

    private func compact(remaining: Int) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "timer").font(.system(size: 13, weight: .semibold))
                Text(Self.clock(remaining))
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                if let note = timer.note {
                    Text(note).font(ForgeType.meta).foregroundStyle(ForgeColor.ink2)
                }
            }
            .foregroundStyle(ForgeColor.ink)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
