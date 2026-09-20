import Foundation

extension Calendar {
    /// Training weeks run Monday to Sunday regardless of locale: a Sunday
    /// session belongs to the week it closes, not the one it opens.
    static let forge: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()
}
