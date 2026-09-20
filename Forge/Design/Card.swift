import SwiftUI

/// Opaque content surface: 1pt hairline, 20pt radius, a whisper of shadow in
/// light mode. Never frosted — glass is for chrome.
struct CardStyle: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 20
    var fill: Color = ForgeColor.surface

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(ForgeColor.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.04), radius: 1, y: 1)
            .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 12, y: 8)
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 20, fill: Color = ForgeColor.surface) -> some View {
        modifier(CardStyle(padding: padding, radius: radius, fill: fill))
    }

    /// Screen background for every tab.
    func forgeBackground() -> some View {
        background(ForgeColor.bg.ignoresSafeArea())
    }

    /// Native `Form`/`List` on the warm background: system grouping and
    /// controls, our surface colour on the rows.
    func forgeForm() -> some View {
        scrollContentBackground(.hidden)
            .forgeBackground()
    }
}

/// Thin separator inside a card.
struct CardDivider: View {
    var body: some View {
        Rectangle()
            .fill(ForgeColor.divider)
            .frame(height: 1)
    }
}
