import Foundation

enum WeightFormatting {
    private static let kgPerLb = 0.45359237

    static func display(_ kg: Double, unit: WeightUnit, fractionDigits: Int = 1) -> String {
        let value = editableValue(kg, unit: unit)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        let number = formatter.string(from: value as NSNumber) ?? "\(value)"
        return "\(number) \(unit.rawValue)"
    }

    static func kilograms(from input: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: input
        case .lb: input * kgPerLb
        }
    }

    static func editableValue(_ kg: Double, unit: WeightUnit) -> Double {
        switch unit {
        case .kg: kg
        case .lb: kg / kgPerLb
        }
    }
}
