import Foundation

/// Which half of a library a list is showing.
///
/// Archiving is how the app retires an exercise or routine that history still
/// references, but M1 hid archived rows with no way back to them. Every list
/// that can archive can now also show the archived rows and restore one.
enum ArchiveScope: String, CaseIterable, Identifiable {
    case active, archived

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: "Active"
        case .archived: "Archived"
        }
    }

    var isArchived: Bool { self == .archived }
}
