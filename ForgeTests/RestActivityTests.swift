import Foundation
import Testing
@testable import Forge

@MainActor
private final class SpyPresenter: RestActivityPresenting {
    enum Call: Equatable { case show(Date, String?), update(Date, String?), dismiss }
    private(set) var calls: [Call] = []

    func show(endsAt: Date, note: String?) { calls.append(.show(endsAt, note)) }
    func update(endsAt: Date, note: String?) { calls.append(.update(endsAt, note)) }
    func dismiss() { calls.append(.dismiss) }
}

@MainActor
private final class NullNotifier: RestNotifying {
    func schedule(after seconds: Int) {}
    func cancel() {}
}

@Suite @MainActor
struct RestActivityTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func startShowsTheActivityWithTheEndDateAndNote() {
        let spy = SpyPresenter()
        let timer = RestTimer(notifier: NullNotifier(), presenter: spy)

        timer.start(seconds: 90, note: "next: set 2", now: now)

        #expect(spy.calls == [.show(now.addingTimeInterval(90), "next: set 2")])
    }

    @Test func adjustingUpdatesRatherThanRestarting() {
        let spy = SpyPresenter()
        let timer = RestTimer(notifier: NullNotifier(), presenter: spy)
        timer.start(seconds: 90, note: "next: set 2", now: now)

        timer.addSeconds(30, now: now)

        #expect(spy.calls.last == .update(now.addingTimeInterval(120), "next: set 2"))
    }

    @Test func skipAndExpiryDismiss() {
        let spy = SpyPresenter()
        let timer = RestTimer(notifier: NullNotifier(), presenter: spy)

        timer.start(seconds: 10, note: nil, now: now)
        timer.skip()
        #expect(spy.calls.last == .dismiss)

        timer.start(seconds: 10, note: nil, now: now)
        timer.expireIfNeeded(at: now.addingTimeInterval(11))
        #expect(spy.calls.last == .dismiss)
        #expect(spy.calls.filter { $0 == .dismiss }.count == 2)
    }

    @Test func startAfterAnUnnoticedExpiryDismissesBeforeShowing() {
        // The bar stopped ticking (app backgrounded), so nobody called
        // expireIfNeeded. The next start must not stack a second activity.
        let spy = SpyPresenter()
        let timer = RestTimer(notifier: NullNotifier(), presenter: spy)
        timer.start(seconds: 10, note: "a", now: now)
        timer.start(seconds: 60, note: "b", now: now.addingTimeInterval(30))
        #expect(spy.calls == [.show(now.addingTimeInterval(10), "a"), .dismiss, .show(now.addingTimeInterval(90), "b")])
    }

    @Test func startingAgainWhileRunningReplacesTheActivity() {
        let spy = SpyPresenter()
        let timer = RestTimer(notifier: NullNotifier(), presenter: spy)
        timer.start(seconds: 60, note: "a", now: now)
        timer.start(seconds: 120, note: "b", now: now)
        // Second start reuses the live activity instead of stacking a new one.
        #expect(spy.calls == [.show(now.addingTimeInterval(60), "a"), .update(now.addingTimeInterval(120), "b")])
    }
}
