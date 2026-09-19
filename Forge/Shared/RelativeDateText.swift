import SwiftUI

/// "2 days ago" / "Today" / "Never" — used on routine rows and history.
struct RelativeDateText: View {
    let date: Date?
    var prefix: String = ""

    var body: some View {
        Text(formatted)
    }

    private var formatted: String {
        guard let date else { return "\(prefix)Never".trimmingCharacters(in: .whitespaces) }
        if Calendar.current.isDateInToday(date) { return "\(prefix)Today".trimmingCharacters(in: .whitespaces) }
        let style = RelativeDateTimeFormatter()
        style.unitsStyle = .full
        return "\(prefix)\(style.localizedString(for: date, relativeTo: .now))"
    }
}
