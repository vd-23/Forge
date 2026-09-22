import SwiftUI

/// How a set row is drawn. The set being worked gets big boxed fields and a
/// tinted background; everything else is a quiet table row.
enum SetEmphasis {
    case done, current, upcoming
}

/// Column widths shared by the header row and every set row, so the table
/// lines up. Weight and reps flex; the rest are fixed.
enum SetColumns {
    static let index: CGFloat = 26
    static let rpe: CGFloat = 54
    static let check: CGFloat = 40
    static let spacing: CGFloat = 8
}

/// Caps column headers above a set table.
struct SetTableHeader: View {
    let isBodyweight: Bool
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: SetColumns.spacing) {
            header("Set").frame(width: SetColumns.index, alignment: .leading)
            header(isBodyweight ? "+\(unit.rawValue)" : unit.rawValue).frame(maxWidth: .infinity, alignment: .leading)
            header("Reps").frame(maxWidth: .infinity, alignment: .leading)
            header("RPE").frame(width: SetColumns.rpe, alignment: .leading)
            Color.clear.frame(width: SetColumns.check, height: 1)
        }
        .padding(.bottom, 2)
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(ForgeColor.ink3)
    }
}

/// One editable row inside an exercise card: load, reps, RPE, and the tick that
/// marks the set done. Weight is stored in kilograms and shown in the user's
/// preferred unit, so both directions go through `WeightFormatting`.
struct SetEntryRow: View {
    @Bindable var set: ExerciseSet

    /// Positional label from `SetNumbering` — "2" or "W".
    let label: String
    let isBodyweight: Bool
    let unit: WeightUnit
    let emphasis: SetEmphasis
    let onToggleComplete: () -> Void
    let onDelete: () -> Void

    private static let rpeOptions: [Double] = Array(stride(from: 6.0, through: 10.0, by: 0.5))

    private var isCurrent: Bool { emphasis == .current }
    private var textTint: Color { emphasis == .upcoming ? ForgeColor.ink3 : ForgeColor.ink }

    var body: some View {
        HStack(spacing: SetColumns.spacing) {
            indexMenu

            NumericTextField(
                placeholder: isBodyweight ? "BW" : "0",
                text: weightText(isBodyweight ? set.addedWeightKg : set.weightKg),
                suffix: isBodyweight ? "+\(unit.rawValue)" : unit.rawValue,
                style: isCurrent ? .boxed : .plain,
                tint: textTint
            ) { input in
                if isBodyweight { set.addedWeightKg = kilograms(from: input) } else { set.weightKg = kilograms(from: input) }
            }

            NumericTextField(
                placeholder: "0",
                text: set.reps > 0 ? "\(set.reps)" : "",
                suffix: "reps",
                style: isCurrent ? .boxed : .plain,
                allowsDecimals: false,
                tint: textTint
            ) { set.reps = Limits.clampReps(Int($0) ?? 0) }

            rpeMenu
                .frame(width: SetColumns.rpe, alignment: .leading)

            checkButton
                .frame(width: SetColumns.check)
        }
        .padding(.vertical, isCurrent ? 10 : 8)
        .padding(.horizontal, isCurrent ? 10 : 0)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 16)
                    .fill(ForgeColor.accentSoft)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ForgeColor.accentLine, lineWidth: 1))
            }
        }
        .padding(.horizontal, isCurrent ? -10 : 0)
    }

    // MARK: Pieces

    /// The set number doubles as the row's menu — there is no room for separate
    /// warm-up and delete controls, and this screen is a scroll view rather than
    /// a `List`, so swipe actions aren't available.
    private var indexMenu: some View {
        Menu {
            Button(set.isWarmup ? "Make working set" : "Mark as warm-up") {
                Haptics.selection()
                set.isWarmup.toggle()
            }
            Button("Delete set", role: .destructive) {
                Haptics.heavy()
                onDelete()
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(indexForeground)
                .frame(width: SetColumns.index, height: SetColumns.index)
                .background(indexBackground, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var indexForeground: Color {
        if set.isWarmup { return .orange }
        return isCurrent ? .white : ForgeColor.ink2
    }

    private var indexBackground: Color {
        if set.isWarmup { return Color.orange.opacity(0.15) }
        return isCurrent ? ForgeColor.accentFill : ForgeColor.sunken
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
            if isCurrent {
                VStack(spacing: 1) {
                    Text(set.rpe.map(Self.rpeLabel) ?? "—")
                        .font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .foregroundStyle(set.rpe == nil ? ForgeColor.ink3 : ForgeColor.ink)
                    Text("RPE")
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.6)
                        .foregroundStyle(ForgeColor.ink3)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(ForgeColor.surface, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(ForgeColor.hairline, lineWidth: 1))
            } else {
                Text(set.rpe.map { "@\(Self.rpeLabel($0))" } ?? "—")
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(set.rpe == nil ? ForgeColor.ink3 : ForgeColor.accentInk)
            }
        }
    }

    private var checkButton: some View {
        Button {
            if set.isComplete { Haptics.tap() } else { Haptics.tick() }
            onToggleComplete()
        } label: {
            Group {
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: SetColumns.check, height: 46)
                        .background(ForgeColor.accentFill, in: .rect(cornerRadius: 12))
                } else if set.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(ForgeColor.accentFill, in: .circle)
                } else {
                    Circle()
                        .strokeBorder(ForgeColor.hairline, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(set.isComplete ? "Mark set incomplete" : "Mark set complete")
    }

    // MARK: Conversion

    private func weightText(_ kilograms: Double?) -> String {
        guard let kilograms else { return "" }
        return NumericTextField.format(WeightFormatting.editableValue(kilograms, unit: unit))
    }

    /// An empty or unparseable field means "not entered", not zero.
    private func kilograms(from input: String) -> Double? {
        guard let entered = NumericTextField.parse(input) else { return nil }
        return Limits.clampWeightKg(WeightFormatting.kilograms(from: entered, unit: unit))
    }

    private static func rpeLabel(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
