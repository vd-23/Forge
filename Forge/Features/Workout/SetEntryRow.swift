import SwiftUI

/// One editable row inside an exercise card: load, reps, RPE, and the tick that
/// marks the set done. Weight is stored in kilograms and shown in the user's
/// preferred unit, so both directions go through `WeightFormatting`.
struct SetEntryRow: View {
    @Bindable var set: ExerciseSet

    /// Positional label from `SetNumbering` — "2" or "W".
    let label: String
    let isBodyweight: Bool
    let unit: WeightUnit
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    private static let rpeOptions: [Double] = Array(stride(from: 6.0, through: 10.0, by: 0.5))

    var body: some View {
        HStack(spacing: 10) {
            indexMenu

            if isBodyweight {
                Text("BW")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                NumericTextField(
                    placeholder: "+",
                    text: weightText(set.addedWeightKg),
                    width: 62
                ) { set.addedWeightKg = kilograms(from: $0) }
            } else {
                NumericTextField(
                    placeholder: unit.displayName,
                    text: weightText(set.weightKg),
                    width: 72
                ) { set.weightKg = kilograms(from: $0) }
            }

            NumericTextField(
                placeholder: "reps",
                text: set.reps > 0 ? "\(set.reps)" : "",
                width: 56,
                allowsDecimals: false
            ) { set.reps = Int($0) ?? 0 }

            rpeMenu

            Spacer(minLength: 0)

            Button(action: onToggleComplete) {
                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isComplete ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isComplete ? "Mark set incomplete" : "Mark set complete")
        }
    }

    // MARK: Pieces

    /// The set number doubles as the row's menu — there is no room for separate
    /// warm-up and delete controls, and this screen is a scroll view rather than
    /// a `List`, so swipe actions aren't available.
    private var indexMenu: some View {
        Menu {
            Button(set.isWarmup ? "Make working set" : "Mark as warm-up") {
                set.isWarmup.toggle()
            }
            Button("Delete set", role: .destructive, action: onDelete)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                .frame(width: 26, height: 26)
                .background(
                    (set.isWarmup ? Color.orange : Color.secondary).opacity(0.15),
                    in: .circle
                )
        }
        .buttonStyle(.plain)
    }

    private var rpeMenu: some View {
        Menu {
            Picker("RPE", selection: $set.rpe) {
                Text("—").tag(Double?.none)
                ForEach(Self.rpeOptions, id: \.self) { value in
                    Text(Self.rpeLabel(value)).tag(Double?.some(value))
                }
            }
        } label: {
            Text(set.rpe.map { "@\(Self.rpeLabel($0))" } ?? "RPE")
                .font(.caption)
                .foregroundStyle(set.rpe == nil ? .secondary : .primary)
                .frame(width: 42)
        }
    }

    // MARK: Conversion

    private func weightText(_ kilograms: Double?) -> String {
        guard let kilograms else { return "" }
        return NumericTextField.format(WeightFormatting.editableValue(kilograms, unit: unit))
    }

    /// An empty or unparseable field means "not entered", not zero.
    private func kilograms(from input: String) -> Double? {
        guard let entered = NumericTextField.parse(input), entered > 0 else { return nil }
        return WeightFormatting.kilograms(from: entered, unit: unit)
    }

    private static func rpeLabel(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
