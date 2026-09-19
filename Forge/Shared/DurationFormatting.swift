import Foundation

enum DurationFormatting {
    /// "45 min" below an hour, "1h 05m" above it.
    static func short(seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        guard minutes >= 60 else { return "\(minutes) min" }
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
}
