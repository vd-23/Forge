import Testing
@testable import Forge

@Suite struct RepRangeTests {
    @Test func formatsRanges() {
        #expect(RepRange.label(min: 8, max: 12) == "8–12")
        #expect(RepRange.label(min: 5, max: 5) == "5")
        #expect(RepRange.label(min: nil, max: nil) == nil)
        #expect(RepRange.label(min: 6, max: nil) == "6+")
        #expect(RepRange.label(min: nil, max: 10) == "≤10")
    }

    @Test func combinesSetsAndReps() {
        #expect(RepRange.targetLabel(sets: 3, repMin: 8, repMax: 12) == "3 × 8–12")
        #expect(RepRange.targetLabel(sets: 3, repMin: nil, repMax: nil) == "3 sets")
        #expect(RepRange.targetLabel(sets: nil, repMin: 5, repMax: 5) == "reps 5")
        #expect(RepRange.targetLabel(sets: nil, repMin: nil, repMax: nil) == nil)
    }
}
