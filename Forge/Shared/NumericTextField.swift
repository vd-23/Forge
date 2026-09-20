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
    enum Style {
        /// Bordered box for the set being worked.
        case boxed
        /// Bare text for logged and upcoming sets.
        case plain
    }

    let placeholder: String
    /// The model's current value, already formatted for display.
    let text: String
    var suffix: String?
    var style: Style = .plain
    var allowsDecimals: Bool = true
    var tint: Color = ForgeColor.ink
    let onEdit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            TextField(placeholder, text: $draft)
                .keyboardType(allowsDecimals ? .decimalPad : .numberPad)
                .multilineTextAlignment(style == .boxed ? .center : .leading)
                .font(style == .boxed
                    ? .system(size: 22, weight: .semibold).monospacedDigit()
                    : .system(size: 17, weight: .medium).monospacedDigit())
                .foregroundStyle(tint)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: draft) { _, newDraft in
                    if isFocused { onEdit(newDraft) }
                }
                .onChange(of: text, initial: true) { _, newText in
                    if !isFocused { draft = newText }
                }
            if let suffix, style == .boxed {
                Text(suffix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ForgeColor.ink3)
            }
        }
        .padding(.horizontal, style == .boxed ? 8 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: style == .boxed ? 46 : nil)
        .background(style == .boxed ? ForgeColor.surface : .clear, in: .rect(cornerRadius: 12))
        .overlay {
            if style == .boxed {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isFocused ? ForgeColor.accentFill : ForgeColor.hairline, lineWidth: isFocused ? 1.5 : 1)
            }
        }
        .contentShape(.rect)
        .onTapGesture { isFocused = true }
    }

    /// No grouping separator: "1,000" is not something you can keep typing into.
    static func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    static func parse(_ input: String) -> Double? {
        Double(input.replacingOccurrences(of: ",", with: "."))
    }
}

extension View {
    /// Number pads have no Return key, so screens holding `NumericTextField`s
    /// need their own way to dismiss the keyboard. Applied once per screen:
    /// attaching it to each field would stack one Done button per field.
    func numericKeyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                    )
                }
            }
        }
    }
}
