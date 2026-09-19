import Testing
@testable import Forge

@Suite
struct NumericTextFieldTests {
    /// A grouping separator turns the field's own text into something the user
    /// can't keep typing into, which is how "110" once became "11".
    @Test func formatsWithoutAGroupingSeparator() {
        #expect(NumericTextField.format(1000) == "1000")
        #expect(NumericTextField.format(110.5) == "110.5")
        #expect(NumericTextField.format(100) == "100")
    }

    @Test func roundsAwayFloatingPointNoiseFromUnitConversion() {
        #expect(NumericTextField.format(220.46226218487757) == "220.46")
    }

    @Test func parsesBothDecimalSeparators() {
        #expect(NumericTextField.parse("110.5") == 110.5)
        #expect(NumericTextField.parse("110,5") == 110.5)
    }

    @Test func parsesPartialAndEmptyInputWithoutCrashing() {
        #expect(NumericTextField.parse("") == nil)
        #expect(NumericTextField.parse("kg") == nil)
        #expect(NumericTextField.parse("1.") == 1)
    }
}
