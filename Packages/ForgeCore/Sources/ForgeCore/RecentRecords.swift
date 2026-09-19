import Foundation

/// A personal record plus the day it was set.
public struct DatedPRHit: Sendable, Equatable {
    public let hit: PRHit
    public let date: Date

    public init(hit: PRHit, date: Date) {
        self.hit = hit
        self.date = date
    }
}

/// Records in the order they were set, newest first.
///
/// Each session is scored against everything that came before it, so this walks
/// history once per session. That is quadratic, which is fine for one person's
/// training log and keeps the result exact — a running tally would have to
/// re-derive itself anyway whenever a past session is edited or deleted.
public func recentPRs(_ sessions: [SessionInput], limit: Int = 10) -> [DatedPRHit] {
    let chronological = sessions.filter(\.isFinished).sorted { $0.startedAt < $1.startedAt }

    var dated: [DatedPRHit] = []
    for (index, session) in chronological.enumerated() {
        let history = Array(chronological[..<index])
        for hit in newPersonalRecords(in: session, history: history) {
            dated.append(DatedPRHit(hit: hit, date: session.startedAt))
        }
    }

    return Array(dated.reversed().prefix(limit))
}
