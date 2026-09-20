import UIKit

/// One place for every haptic, so the vocabulary stays small: `tap` for
/// ordinary presses and navigation, `tick` for logging a set, `success` and
/// `warning` for finishing and destructive confirms, `selection` for pickers
/// and tab changes.
@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func tick() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// Tab switches: a touch firmer than a selection tick.
    static func dock() { UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
