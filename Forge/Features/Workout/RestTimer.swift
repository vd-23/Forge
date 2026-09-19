import Foundation
import Observation
import UserNotifications

/// Schedules (and cancels) the alert that fires when rest is over. Abstracted so
/// the timer's arithmetic can be tested without touching the notification centre.
@MainActor
protocol RestNotifying {
    func schedule(after seconds: Int)
    func cancel()
}

/// Counts down between sets. The timer stores only an end date, so it stays
/// correct across view rebuilds and while the app is backgrounded — the views
/// derive the remaining seconds from `Date` as they tick.
@Observable
@MainActor
final class RestTimer {
    private(set) var endsAt: Date?
    private let notifier: RestNotifying

    init(notifier: RestNotifying = LocalRestNotifier()) {
        self.notifier = notifier
    }

    var isRunning: Bool { isRunning(at: .now) }

    func isRunning(at now: Date) -> Bool { (endsAt ?? .distantPast) > now }

    func start(seconds: Int, now: Date = .now) {
        endsAt = now.addingTimeInterval(TimeInterval(seconds))
        notifier.schedule(after: seconds)
    }

    /// Extends or trims a running countdown. Trimming past zero just ends it.
    func addSeconds(_ delta: Int, now: Date = .now) {
        endsAt = (endsAt ?? now).addingTimeInterval(TimeInterval(delta))
        notifier.schedule(after: remaining(at: now))
    }

    func skip() {
        endsAt = nil
        notifier.cancel()
    }

    func remaining(at now: Date = .now) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded()))
    }
}

/// Posts a single local notification so the alert still lands when the phone is
/// locked mid-workout. A fixed identifier means every reschedule replaces the
/// previous request instead of stacking up.
@MainActor
final class LocalRestNotifier: RestNotifying {
    private static let identifier = "forge.rest-timer"
    private var didRequestAuthorization = false

    func schedule(after seconds: Int) {
        guard seconds > 0 else {
            cancel()
            return
        }

        let needsAuthorization = !didRequestAuthorization
        didRequestAuthorization = true

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            if needsAuthorization {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }

            let content = UNMutableNotificationContent()
            content.title = "Rest is over"
            content.body = "Time for the next set."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: Self.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(
                    timeInterval: TimeInterval(seconds),
                    repeats: false
                )
            )
            center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            try? await center.add(request)
        }
    }

    func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
