import Foundation
import Testing
@testable import ForgeCore

@Suite struct OneRepMaxTests {
    @Test func singleRepReturnsTheWeight() {
        #expect(estimatedOneRepMax(weightKg: 100, reps: 1) == 100)
    }

    @Test func epleyFormulaForMultipleReps() {
        // 100 * (1 + 5/30) = 116.666...
        #expect(abs(estimatedOneRepMax(weightKg: 100, reps: 5) - 116.6667) < 0.001)
    }

    @Test func zeroOrNegativeRepsReturnsZero() {
        #expect(estimatedOneRepMax(weightKg: 100, reps: 0) == 0)
        #expect(estimatedOneRepMax(weightKg: 100, reps: -3) == 0)
    }

    @Test func zeroWeightReturnsZero() {
        #expect(estimatedOneRepMax(weightKg: 0, reps: 8) == 0)
    }
}
