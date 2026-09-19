import Testing
@testable import Forge

@Suite @MainActor
struct SetNumberingTests {
    private func sets(_ warmupFlags: [Bool]) -> [ExerciseSet] {
        warmupFlags.enumerated().map { index, isWarmup in
            ExerciseSet(order: index, weightKg: 100, reps: 5, isWarmup: isWarmup)
        }
    }

    @Test func numbersWorkingSetsFromOne() {
        let labels = SetNumbering.number(sets([false, false, false])).map(\.label)
        #expect(labels == ["1", "2", "3"])
    }

    /// The bug: labels came from the stored `order`, so deleting the middle set
    /// of three left 0 and 2 behind and the card read "1, 3".
    @Test func numbersByPositionSoAGapInOrderDoesNotShow() {
        let first = ExerciseSet(order: 0, weightKg: 100, reps: 5)
        let third = ExerciseSet(order: 2, weightKg: 100, reps: 5)

        let labels = SetNumbering.number([first, third]).map(\.label)

        #expect(labels == ["1", "2"])
    }

    @Test func warmupsAreLabelledInsteadOfNumbered() {
        let labels = SetNumbering.number(sets([true, true, false, false])).map(\.label)
        #expect(labels == ["W", "W", "1", "2"])
    }

    @Test func aWarmupBetweenWorkingSetsDoesNotConsumeANumber() {
        let labels = SetNumbering.number(sets([false, true, false])).map(\.label)
        #expect(labels == ["1", "W", "2"])
    }

    @Test func handlesNoSets() {
        #expect(SetNumbering.number([]).isEmpty)
    }
}
