import Foundation
import ForgeCore

enum HistorySort: String, CaseIterable, Identifiable {
    case newest, oldest, mostVolume, longest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .mostVolume: "Most volume"
        case .longest: "Longest"
        }
    }

    /// Month headings only make sense when the list is in date order.
    var groupsByMonth: Bool {
        self == .newest || self == .oldest
    }
}

enum HistoryFiltering {
    /// A `routine` of `nil` means every routine.
    static func apply(
        to sessions: [WorkoutSession],
        sort: HistorySort,
        routine: String? = nil
    ) -> [WorkoutSession] {
        let matching = routine.map { name in
            sessions.filter { $0.sourceRoutineName == name }
        } ?? sessions

        switch sort {
        case .newest:
            return matching.sorted { $0.startedAt > $1.startedAt }
        case .oldest:
            return matching.sorted { $0.startedAt < $1.startedAt }
        case .mostVolume:
            // Volume is computed once per session rather than on every comparison.
            return matching
                .map { (session: $0, volume: sessionVolumeKg($0.coreInput)) }
                .sorted { $0.volume > $1.volume }
                .map(\.session)
        case .longest:
            return matching.sorted { ($0.durationSeconds ?? 0) > ($1.durationSeconds ?? 0) }
        }
    }

    /// Routine names that actually appear in history, for the filter menu.
    static func routineNames(in sessions: [WorkoutSession]) -> [String] {
        Set(sessions.map(\.sourceRoutineName)).sorted()
    }
}
