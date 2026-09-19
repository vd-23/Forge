import Foundation

enum Preferences {
    /// Exposed because views bind to these keys with `@AppStorage`, which is
    /// what makes a unit change take effect everywhere at once.
    ///
    /// Standard defaults rather than an App Group suite: the group entitlement
    /// needs a paid developer account, and an unprovisioned suite silently
    /// fails to persist rather than returning nil.
    static var defaults: UserDefaults { .standard }

    enum Key {
        static let weightUnit = "weightUnit"
        static let defaultRestSeconds = "defaultRestSeconds"
    }

    static let fallbackRestSeconds = 120

    static var weightUnit: WeightUnit {
        get { defaults.string(forKey: Key.weightUnit).flatMap(WeightUnit.init) ?? .kg }
        set { defaults.set(newValue.rawValue, forKey: Key.weightUnit) }
    }

    static var defaultRestSeconds: Int {
        get {
            let stored = defaults.integer(forKey: Key.defaultRestSeconds)
            return stored == 0 ? fallbackRestSeconds : stored
        }
        set { defaults.set(newValue, forKey: Key.defaultRestSeconds) }
    }
}
