import Foundation

enum WeightUnit: String, CaseIterable, Codable, Identifiable {
    case kg, lb
    var id: String { rawValue }
    var displayName: String { rawValue }
}
