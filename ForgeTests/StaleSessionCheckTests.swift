import Foundation
import Testing
@testable import Forge

@Suite @MainActor
struct StaleSessionCheckTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func session(startedHoursAgo hours: Double, finished: Bool = false) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: now.addingTimeInterval(-hours * 3600),
            sourceRoutine: nil,
            sourceRoutineName: "Push"
        )
        session.endedAt = finished ? now : nil
        return session
    }

    @Test func anActiveSessionOlderThanTheThresholdIsStale() {
        #expect(StaleSessionCheck.isStale(session(startedHoursAgo: 7), now: now))
    }

    @Test func aSessionInsideTheThresholdIsLeftAlone() {
        #expect(!StaleSessionCheck.isStale(session(startedHoursAgo: 2), now: now))
    }

    @Test func aFinishedSessionIsNeverStale() {
        #expect(!StaleSessionCheck.isStale(session(startedHoursAgo: 48, finished: true), now: now))
    }

    @Test func theThresholdIsConfigurable() {
        let recent = session(startedHoursAgo: 2)
        #expect(StaleSessionCheck.isStale(recent, now: now, threshold: 3600))
    }
}
