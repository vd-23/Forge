import SwiftUI

/// One editable row inside an exercise card: load, reps, RPE, and the tick that
/// marks the set done. Weight is stored in kilograms and shown in the user's
/// preferred unit, so both directions go through `WeightFormatting`.
struct SetEntryRow: View {
    @Bindable var set: ExerciseSet

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
                numberField("+", value: addedWeightInUnit, width: 62)
            } else {
                numberField(unit.displayName, value: weightInUnit, width: 72)
            }

            TextField("reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)

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
            Text(set.isWarmup ? "W" : "\(set.order + 1)")
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

    private func numberField(_ placeholder: String, value: Binding<Double>, width: CGFloat) -> some View {
        TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
    }

    // MARK: Bindings

    /// Zero reads as "not entered", which keeps the field a plain `Double` and
    /// avoids an optional-formatted text field.
    private var weightInUnit: Binding<Double> {
        Binding(
            get: { WeightFormatting.editableValue(set.weightKg ?? 0, unit: unit) },
            set: { set.weightKg = $0 > 0 ? WeightFormatting.kilograms(from: $0, unit: unit) : nil }
        )
    }

    private var addedWeightInUnit: Binding<Double> {
        Binding(
            get: { WeightFormatting.editableValue(set.addedWeightKg ?? 0, unit: unit) },
            set: { set.addedWeightKg = $0 > 0 ? WeightFormatting.kilograms(from: $0, unit: unit) : nil }
        )
    }

    private static func rpeLabel(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
