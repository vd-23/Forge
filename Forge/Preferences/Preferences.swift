import Foundation

/// Settings live in `UserDefaults`. The static members read the app's
/// defaults; an instance can point at any suite (tests, backup restore).
///
/// Standard defaults rather than an App Group suite: the group entitlement
/// needs a paid developer account, and an unprovisioned suite silently
/// fails to persist rather than returning nil.
struct Preferences {
    /// Exposed because views bind to these keys with `@AppStorage`, which is
    /// what makes a unit change take effect everywhere at once.
    static var defaults: UserDefaults { .standard }

    enum Key {
        static let weightUnit = "weightUnit"
        static let defaultRestSeconds = "defaultRestSeconds"
    }

    static let fallbackRestSeconds = 120

    static var weightUnit: WeightUnit {
        get { Preferences().weightUnit }
        set { var p = Preferences(); p.weightUnit = newValue }
    }

    static var defaultRestSeconds: Int {
        get { Preferences().defaultRestSeconds }
        set { var p = Preferences(); p.defaultRestSeconds = newValue }
    }

    private let store: UserDefaults

    init(defaults: UserDefaults = Preferences.defaults) {
        self.store = defaults
    }

    var weightUnit: WeightUnit {
        get { store.string(forKey: Key.weightUnit).flatMap(WeightUnit.init) ?? .kg }
        nonmutating set { store.set(newValue.rawValue, forKey: Key.weightUnit) }
    }

    var defaultRestSeconds: Int {
        get {
            let stored = store.integer(forKey: Key.defaultRestSeconds)
            return stored == 0 ? Self.fallbackRestSeconds : stored
        }
        nonmutating set { store.set(newValue, forKey: Key.defaultRestSeconds) }
    }
}
