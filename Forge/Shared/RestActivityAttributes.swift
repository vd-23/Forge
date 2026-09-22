import ActivityKit
import Foundation

/// Shared between the app and the widget extension: what the rest-timer Live
/// Activity shows. The end date lets the system count down without updates.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endsAt: Date
        var note: String?
    }

    var routineName: String
}
