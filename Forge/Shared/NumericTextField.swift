import SwiftUI

/// A number entry field whose text lives in local state.
///
/// `TextField(value:format:)` re-derives its text from the bound value every
/// time the view rebuilds. In a set row each keystroke writes through to
/// SwiftData, and the resulting refresh rebuilt the row mid-edit: the field
/// reformatted itself, moved the cursor, and silently dropped characters —
/// typing "110" into a field showing "0" landed as "11".
///
/// Keeping the draft local and syncing it from the model only while the field
/// is unfocused means edits still save as you type, but nothing rewrites what
/// you are in the middle of typing.
struct NumericTextField: View {
    let placeholder: String
    /// The model's current value, already formatted for display.
    let text: String
    let width: CGFloat
    var allowsDecimals: Bool = true
    let onEdit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .focused($isFocused)
            .onChange(of: draft) { _, newDraft in
                if isFocused { onEdit(newDraft) }
            }
            .onChange(of: text, initial: true) { _, newText in
                if !isFocused { draft = newText }
            }
    }

    /// No grouping separator: "1,000" is not something you can keep typing into.
    static func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    static func parse(_ input: String) -> Double? {
        Double(input.replacingOccurrences(of: ",", with: "."))
    }
}
