import SwiftUI

/// "2 days ago" / "Today" / "Never" — used on routine rows and history.
/// `.compact` gives "14h ago" / "3d ago" for dense rows.
struct RelativeDateText: View {
    enum Style { case full, compact }

    let date: Date?
    var prefix: String = ""
    var style: Style = .full

    var body: some View {
        Text(formatted)
    }

    private var formatted: String {
        guard let date else { return "\(prefix)Never".trimmingCharacters(in: .whitespaces) }
        switch style {
        case .full:
            if Calendar.current.isDateInToday(date) { return "\(prefix)Today".trimmingCharacters(in: .whitespaces) }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "\(prefix)\(formatter.localizedString(for: date, relativeTo: .now))"
        case .compact:
            return "\(prefix)\(Self.compact(date))".trimmingCharacters(in: .whitespaces)
        }
    }

    static func compact(_ date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let days = Int(seconds / 86400)
        if minutes < 60 { return minutes < 1 ? "just now" : "\(minutes)m ago" }
        if hours < 24 { return "\(hours)h ago" }
        if days < 7 { return "\(days)d ago" }
        if days < 60 { return "\(days / 7)w ago" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}
