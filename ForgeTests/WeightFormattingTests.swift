import Testing
@testable import Forge

@Suite struct WeightFormattingTests {
    @Test func displaysKilogramsWithoutTrailingZeros() {
        #expect(WeightFormatting.display(100, unit: .kg) == "100 kg")
        #expect(WeightFormatting.display(102.5, unit: .kg) == "102.5 kg")
    }

    @Test func displaysPoundsConvertedFromKilograms() {
        // 100 kg -> 220.462 lb -> "220.5 lb"
        #expect(WeightFormatting.display(100, unit: .lb) == "220.5 lb")
    }

    @Test func convertsEnteredPoundsToKilogramsForStorage() {
        #expect(abs(WeightFormatting.kilograms(from: 225, unit: .lb) - 102.058) < 0.001)
        #expect(WeightFormatting.kilograms(from: 100, unit: .kg) == 100)
    }

    @Test func editableValueRoundTripsWithinUnit() {
        let kg = WeightFormatting.kilograms(from: 135, unit: .lb)
        #expect(abs(WeightFormatting.editableValue(kg, unit: .lb) - 135) < 0.01)
    }
}
