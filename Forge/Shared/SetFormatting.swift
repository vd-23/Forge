import Foundation

/// How a logged set reads wherever it is printed rather than edited: the
/// "last time" line on a workout card, and the history detail screen.
enum SetFormatting {
    /// "100 kg", "BW", "BW + 10 kg", or "—" when no load was entered.
    static func loadLabel(_ set: ExerciseSet, isBodyweight: Bool, unit: WeightUnit) -> String {
        if isBodyweight {
            guard let added = set.addedWeightKg, added > 0 else { return "BW" }
            return "BW + " + WeightFormatting.display(added, unit: unit)
        }
        guard let weight = set.weightKg else { return "—" }
        return WeightFormatting.display(weight, unit: unit)
    }

    /// "100 kg × 8"
    static func line(_ set: ExerciseSet, isBodyweight: Bool, unit: WeightUnit) -> String {
        "\(loadLabel(set, isBodyweight: isBodyweight, unit: unit)) × \(set.reps)"
    }
}
