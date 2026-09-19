import Foundation

enum Preferences {
    /// The App Group suite, so the widget reads the same settings in M3.
    /// Exposed because views bind to these keys with `@AppStorage`, which is
    /// what makes a unit change take effect everywhere at once.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: PersistenceController.appGroupID) ?? .standard
    }

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
