import SwiftUI

/// Type roles from the design sheet. Every figure is tabular so columns of
/// numbers line up.
enum ForgeType {
    /// 64pt hero metric — the streak, the rest countdown.
    static let hero = Font.system(size: 64, weight: .bold).monospacedDigit()
    /// 30pt stat-tile figure.
    static let stat = Font.system(size: 30, weight: .bold).monospacedDigit()
    /// 20pt card title.
    static let cardTitle = Font.system(size: 20, weight: .semibold)
    /// 17pt row label; the Dynamic Type anchor.
    static let body = Font.body
    /// 13pt secondary meta.
    static let meta = Font.system(size: 13, weight: .medium)
    /// 11pt caps eyebrow.
    static let eyebrow = Font.system(size: 11, weight: .bold)
}

/// Caps eyebrow that replaces grouped-list section headers.
struct SectionLabel: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(ForgeType.eyebrow)
                .kerning(1)
                .foregroundStyle(ForgeColor.ink3)
            if let trailing {
                Spacer()
                Text(trailing)
                    .font(ForgeType.meta)
                    .foregroundStyle(ForgeColor.ink3)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// A figure with its unit as a smaller, quieter token: "18,420 kg".
struct MeasureText: View {
    let value: String
    let unit: String?
    var valueFont: Font = ForgeType.stat
    var unitFont: Font = ForgeType.meta

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(valueFont)
                .foregroundStyle(ForgeColor.ink)
            if let unit {
                Text(unit)
                    .font(unitFont)
                    .foregroundStyle(ForgeColor.ink2)
            }
        }
    }
}
