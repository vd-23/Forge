import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ForgeWidgets: WidgetBundle {
    var body: some Widget {
        RestActivityWidget()
    }
}

/// Rest countdown on the Lock Screen and in the Dynamic Island. The end date
/// is in the state, so `Text(timerInterval:)` counts down on its own.
struct RestActivityWidget: Widget {
    private let blue = Color(red: 0.24, green: 0.51, blue: 0.97)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REST")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1)
                            .foregroundStyle(.secondary)
                        Text(context.attributes.routineName)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 30)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let note = context.state.note {
                        Text(note)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(blue)
            } compactTrailing: {
                countdown(context, size: 14)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(blue)
            }
            .keylineTint(blue)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<RestActivityAttributes>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("REST")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(.secondary)
                Text(context.attributes.routineName)
                    .font(.system(size: 16, weight: .semibold))
                if let note = context.state.note {
                    Text(note)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            countdown(context, size: 36)
        }
        .padding(16)
    }

    private func countdown(_ context: ActivityViewContext<RestActivityAttributes>, size: CGFloat) -> some View {
        Text(timerInterval: Date.now...context.state.endsAt, countsDown: true)
            .font(.system(size: size, weight: .bold).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .foregroundStyle(blue)
    }
}
