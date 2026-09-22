import ActivityKit
import Foundation

/// The Live Activity side of the rest timer, abstracted so `RestTimer` can be
/// tested without ActivityKit.
@MainActor
protocol RestActivityPresenting {
    func show(endsAt: Date, note: String?)
    func update(endsAt: Date, note: String?)
    func dismiss()
}

/// Drives one `Activity` for the current rest. Failures (activities disabled
/// in Settings, too many live activities) are swallowed: the in-app bar is
/// the source of truth and the island is a bonus.
@MainActor
final class LiveRestActivity: RestActivityPresenting {
    private var activity: Activity<RestActivityAttributes>?
    private let routineName: () -> String

    init(routineName: @escaping () -> String) {
        self.routineName = routineName
    }

    func show(endsAt: Date, note: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil { dismiss() }
        let state = RestActivityAttributes.ContentState(endsAt: endsAt, note: note)
        activity = try? Activity.request(
            attributes: RestActivityAttributes(routineName: routineName()),
            content: ActivityContent(state: state, staleDate: endsAt.addingTimeInterval(60)),
            pushType: nil
        )
    }

    func update(endsAt: Date, note: String?) {
        guard let id = activity?.id else { return show(endsAt: endsAt, note: note) }
        let state = RestActivityAttributes.ContentState(endsAt: endsAt, note: note)
        // `Activity` isn't Sendable, so look it up again off the main actor.
        Task.detached {
            guard let live = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
            await live.update(ActivityContent(state: state, staleDate: endsAt.addingTimeInterval(60)))
        }
    }

    func dismiss() {
        guard let id = activity?.id else { return }
        activity = nil
        Task.detached {
            guard let live = Activity<RestActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
            await live.end(nil, dismissalPolicy: .immediate)
        }
    }
}

/// No-op for previews and contexts without a controller.
@MainActor
struct NoRestActivity: RestActivityPresenting {
    func show(endsAt: Date, note: String?) {}
    func update(endsAt: Date, note: String?) {}
    func dismiss() {}
}
