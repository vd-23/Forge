import Foundation
import SwiftData

/// A body part is its raw string. Built-ins keep the raw values the store has
/// always used ("chest", "fullBody"); custom ones are prefixed so they can
/// never collide with a built-in and can be told apart when displayed.
struct BodyPart: Hashable, Codable, Identifiable, RawRepresentable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }

    var id: String { rawValue }

    static let customPrefix = "custom:"

    static let chest = BodyPart(rawValue: "chest")
    static let back = BodyPart(rawValue: "back")
    static let shoulders = BodyPart(rawValue: "shoulders")
    static let biceps = BodyPart(rawValue: "biceps")
    static let triceps = BodyPart(rawValue: "triceps")
    static let forearms = BodyPart(rawValue: "forearms")
    static let core = BodyPart(rawValue: "core")
    static let quads = BodyPart(rawValue: "quads")
    static let hamstrings = BodyPart(rawValue: "hamstrings")
    static let glutes = BodyPart(rawValue: "glutes")
    static let calves = BodyPart(rawValue: "calves")
    static let traps = BodyPart(rawValue: "traps")
    static let cardio = BodyPart(rawValue: "cardio")
    static let fullBody = BodyPart(rawValue: "fullBody")
    static let other = BodyPart(rawValue: "other")

    static let builtIn: [BodyPart] = [
        .chest, .back, .shoulders, .biceps, .triceps, .forearms, .core,
        .quads, .hamstrings, .glutes, .calves, .traps,
        .cardio, .fullBody, .other,
    ]

    static func custom(named name: String) -> BodyPart {
        BodyPart(rawValue: customPrefix + name)
    }

    var isCustom: Bool { rawValue.hasPrefix(Self.customPrefix) }

    var displayName: String {
        if isCustom { return String(rawValue.dropFirst(Self.customPrefix.count)) }
        return self == .fullBody ? "Full Body" : rawValue.capitalized
    }
}

/// The built-in body parts plus whatever the user has added in Settings.
/// Custom parts are a name list in `UserDefaults`; the exercise store only
/// ever holds the raw string, so nothing migrates.
struct BodyPartCatalog {
    enum Error: Swift.Error, Equatable {
        case emptyName
        case duplicate
        case inUse(count: Int)
    }

    static let key = "customBodyParts"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = Preferences.defaults) {
        self.defaults = defaults
    }

    var custom: [BodyPart] {
        (defaults.stringArray(forKey: Self.key) ?? []).map(BodyPart.custom(named:))
    }

    var all: [BodyPart] { BodyPart.builtIn + custom }

    @discardableResult
    func add(_ name: String) throws -> BodyPart {
        let cleaned = try validated(name, excluding: nil)
        write(customNames + [cleaned])
        return .custom(named: cleaned)
    }

    /// Exercises tagged with the old part are moved over, so nothing is orphaned.
    @discardableResult
    func rename(_ part: BodyPart, to name: String, in context: ModelContext) throws -> BodyPart {
        let cleaned = try validated(name, excluding: part)
        let renamed = BodyPart.custom(named: cleaned)
        write(customNames.map { $0 == part.displayName ? cleaned : $0 })
        for exercise in exercises(tagged: part, in: context) {
            exercise.primaryBodyPart = renamed
        }
        try? context.save()
        return renamed
    }

    func remove(_ part: BodyPart, in context: ModelContext) throws {
        let users = exercises(tagged: part, in: context).count
        guard users == 0 else { throw Error.inUse(count: users) }
        write(customNames.filter { $0 != part.displayName })
    }

    func usageCount(of part: BodyPart, in context: ModelContext) -> Int {
        exercises(tagged: part, in: context).count
    }

    // MARK: Helpers

    private var customNames: [String] { defaults.stringArray(forKey: Self.key) ?? [] }

    private func write(_ names: [String]) { defaults.set(names, forKey: Self.key) }

    private func validated(_ name: String, excluding current: BodyPart?) throws -> String {
        guard let cleaned = Limits.cleanName(name) else { throw Error.emptyName }
        let taken = all.filter { $0 != current }.map { $0.displayName.lowercased() }
        guard !taken.contains(cleaned.lowercased()) else { throw Error.duplicate }
        return cleaned
    }

    private func exercises(tagged part: BodyPart, in context: ModelContext) -> [Exercise] {
        let raw = part.rawValue
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.primaryBodyPartRaw == raw })
        return (try? context.fetch(descriptor)) ?? []
    }
}
