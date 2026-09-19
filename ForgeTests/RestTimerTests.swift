import Foundation
import Testing
@testable import Forge

@MainActor
private final class SpyNotifier: RestNotifying {
    private(set) var scheduled: [Int] = []
    private(set) var cancelCount = 0

    func schedule(after seconds: Int) { scheduled.append(seconds) }
    func cancel() { cancelCount += 1 }
}

@Suite @MainActor
struct RestTimerTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func startCountsDownAndSchedulesTheNotification() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)

        timer.start(seconds: 120, now: now)

        #expect(timer.remaining(at: now) == 120)
        #expect(timer.remaining(at: now.addingTimeInterval(30)) == 90)
        #expect(timer.isRunning(at: now.addingTimeInterval(119)))
        #expect(spy.scheduled == [120])
    }

    @Test func remainingClampsToZeroOnceTheCountdownExpires() {
        let timer = RestTimer(notifier: SpyNotifier())
        timer.start(seconds: 60, now: now)

        let after = now.addingTimeInterval(90)
        #expect(timer.remaining(at: after) == 0)
        #expect(!timer.isRunning(at: after))
    }

    @Test func addSecondsExtendsTheEndDateAndReschedules() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        timer.start(seconds: 60, now: now)

        let tenSecondsIn = now.addingTimeInterval(10)
        timer.addSeconds(30, now: tenSecondsIn)

        #expect(timer.remaining(at: tenSecondsIn) == 80)
        #expect(spy.scheduled == [60, 80])
    }

    @Test func trimmingBelowZeroEndsTheCountdown() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        timer.start(seconds: 20, now: now)

        timer.addSeconds(-30, now: now)

        #expect(timer.remaining(at: now) == 0)
        #expect(!timer.isRunning(at: now))
        #expect(spy.scheduled == [20, 0])
    }

    @Test func skipStopsTheCountdownAndCancelsTheNotification() {
        let spy = SpyNotifier()
        let timer = RestTimer(notifier: spy)
        timer.start(seconds: 90, now: now)

        timer.skip()

        #expect(timer.endsAt == nil)
        #expect(!timer.isRunning(at: now))
        #expect(spy.cancelCount == 1)
    }
}
