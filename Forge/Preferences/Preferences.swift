import Foundation

enum Preferences {
    private static var store: UserDefaults {
        UserDefaults(suiteName: PersistenceController.appGroupID) ?? .standard
    }

    private enum Key {
        static let weightUnit = "weightUnit"
        static let defaultRestSeconds = "defaultRestSeconds"
    }

    static var weightUnit: WeightUnit {
        get { store.string(forKey: Key.weightUnit).flatMap(WeightUnit.init) ?? .kg }
        set { store.set(newValue.rawValue, forKey: Key.weightUnit) }
    }

    static var defaultRestSeconds: Int {
        get {
            let stored = store.integer(forKey: Key.defaultRestSeconds)
            return stored == 0 ? 120 : stored
        }
        set { store.set(newValue, forKey: Key.defaultRestSeconds) }
    }
}
