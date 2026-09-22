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
    /// What comes after the rest — "next: set 4" — shown beside the countdown.
    private(set) var note: String?
    private let notifier: RestNotifying
    private let presenter: RestActivityPresenting

    init(notifier: RestNotifying = LocalRestNotifier(), presenter: RestActivityPresenting = NoRestActivity()) {
        self.notifier = notifier
        self.presenter = presenter
    }

    var isRunning: Bool { isRunning(at: .now) }

    func isRunning(at now: Date) -> Bool { (endsAt ?? .distantPast) > now }

    func start(seconds: Int, note: String? = nil, now: Date = .now) {
        let wasRunning = isRunning(at: now)
        // A countdown that ran out while nothing was ticking still owns a
        // presenter entry; clear it so the new one doesn't stack on top.
        if !wasRunning, endsAt != nil { presenter.dismiss() }
        let end = now.addingTimeInterval(TimeInterval(seconds))
        endsAt = end
        self.note = note
        notifier.schedule(after: seconds)
        if wasRunning { presenter.update(endsAt: end, note: note) } else { presenter.show(endsAt: end, note: note) }
    }

    /// Called by the ticking view once the countdown reaches zero, so observers
    /// keyed on `endsAt` (the tab accessory) see it end.
    func expireIfNeeded(at now: Date = .now) {
        guard let endsAt, endsAt <= now else { return }
        self.endsAt = nil
        note = nil
        presenter.dismiss()
    }

    /// Extends or trims a running countdown. Trimming past zero just ends it.
    func addSeconds(_ delta: Int, now: Date = .now) {
        let end = (endsAt ?? now).addingTimeInterval(TimeInterval(delta))
        endsAt = end
        notifier.schedule(after: remaining(at: now))
        if end > now { presenter.update(endsAt: end, note: note) } else { presenter.dismiss() }
    }

    func skip() {
        endsAt = nil
        note = nil
        notifier.cancel()
        presenter.dismiss()
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
