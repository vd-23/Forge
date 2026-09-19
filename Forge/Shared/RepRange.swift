import Foundation

enum RepRange {
    /// "8–12", "5", "6+", "≤10", or nil when neither bound is set.
    static func label(min: Int?, max: Int?) -> String? {
        switch (min, max) {
        case let (m?, x?) where m == x: "\(m)"
        case let (m?, x?): "\(m)–\(x)"
        case let (m?, nil): "\(m)+"
        case let (nil, x?): "≤\(x)"
        case (nil, nil): nil
        }
    }

    /// The combined target shown on routine rows and workout cards,
    /// e.g. "3 × 8–12", "3 sets", "reps 5".
    static func targetLabel(sets: Int?, repMin: Int?, repMax: Int?) -> String? {
        let reps = label(min: repMin, max: repMax)
        switch (sets, reps) {
        case let (s?, r?): return "\(s) × \(r)"
        case let (s?, nil): return "\(s) sets"
        case let (nil, r?): return "reps \(r)"
        case (nil, nil): return nil
        }
    }
}
