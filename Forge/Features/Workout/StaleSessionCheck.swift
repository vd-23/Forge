import Foundation

/// Nothing closes a workout automatically, so one forgotten on a locked phone
/// is still "active" the next morning and would block starting a new one.
enum StaleSessionCheck {
    /// Long enough that a genuinely long session — or a lunch break mid-workout —
    /// is never mistaken for an abandoned one.
    static let defaultThreshold: TimeInterval = 6 * 60 * 60

    static func isStale(
        _ session: WorkoutSession,
        now: Date = .now,
        threshold: TimeInterval = defaultThreshold
    ) -> Bool {
        session.endedAt == nil && now.timeIntervalSince(session.startedAt) > threshold
    }
}
