import SwiftUI

/// The countdown strip pinned above the keyboard-safe area during a workout.
/// It renders nothing while no rest is running, and hides itself when the
/// countdown reaches zero — the `TimelineView` tick is what notices, since
/// `RestTimer` only stores an end date and never mutates as time passes.
struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if timer.isRunning(at: context.date) {
                bar(remaining: timer.remaining(at: context.date))
            }
        }
    }

    private func bar(remaining: Int) -> some View {
        HStack(spacing: 16) {
            Button("−30") { timer.addSeconds(-30) }

            Text(Self.clock(remaining))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 72)

            Button("+30") { timer.addSeconds(30) }

            Divider().frame(height: 22)

            Button("Skip") { timer.skip() }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
