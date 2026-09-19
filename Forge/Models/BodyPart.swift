import Foundation

enum BodyPart: String, CaseIterable, Codable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, core
    case quads, hamstrings, glutes, calves, traps
    case cardio, fullBody, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody: "Full Body"
        default: rawValue.capitalized
        }
    }
}
