import SwiftUI

/// Small caps tag: "BW", "×2", "PR", a body part.
struct Chip: View {
    let text: String
    var tint: Color = ForgeColor.ink2
    var fill: Color = ForgeColor.sunken

    init(_ text: String, tint: Color = ForgeColor.ink2, fill: Color = ForgeColor.sunken) {
        self.text = text
        self.tint = tint
        self.fill = fill
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .kerning(0.4)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(fill, in: .rect(cornerRadius: 7))
    }
}

/// Toggleable pill for a horizontal filter row: "All", "Chest", "Back".
struct FilterPill: View {
    let text: String
    let isOn: Bool
    let action: () -> Void

    init(_ text: String, isOn: Bool, action: @escaping () -> Void) {
        self.text = text
        self.isOn = isOn
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .white : ForgeColor.ink2)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(isOn ? ForgeColor.accentFill : ForgeColor.sunken, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

/// Eyebrow + figure + a quiet sub-line: "HEAVIEST / 172 / kg × 3".
struct StatTile: View {
    let label: String
    let value: String
    var unit: String?
    var detail: String?
    var fill: Color = ForgeColor.surface

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(label)
            MeasureText(value: value, unit: unit)
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ForgeColor.ink3)
            }
        }
        .card(padding: 14, radius: 16, fill: fill)
    }
}

/// Dashed outline button for secondary "add" actions.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ForgeColor.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(ForgeColor.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Inline text button in the accent ink: "+ Add set".
struct InlineAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ForgeColor.accentInk)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Thin progress bar split into one segment per unit of work.
struct SegmentedProgress: View {
    /// Fraction complete for each segment, 0...1.
    let segments: [Double]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, fraction in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ForgeColor.hairline)
                        Capsule().fill(ForgeColor.accent)
                            .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                    }
                }
                .frame(height: 3)
            }
        }
    }
}
