import SwiftUI

/// The palette from the design sheet. Neutral greys and iOS system blue, which does
/// three jobs: `accent` for graphics, `accentFill` for filled controls and
/// ticks, `accentInk` for blue text on a surface.
enum ForgeColor {
    static let bg = Color("Bg")
    static let surface = Color("Surface")
    static let sunken = Color("Sunken")
    static let hairline = Color("Hairline")
    static let divider = Color("Divider")
    static let ink = Color("Ink")
    static let ink2 = Color("Ink2")
    static let ink3 = Color("Ink3")
    static let accent = Color("Accent")
    static let accentFill = Color("AccentFill")
    static let accentInk = Color("AccentFill")
    static let accentSoft = Color("AccentSoft")
    static let accentLine = Color("AccentLine")
    static let heatEmpty = Color("HeatEmpty")
}
