import Testing
@testable import Forge

@Suite @MainActor
struct ExerciseFilteringTests {
    private let library: [Exercise] = [
        Exercise(name: "Bench Press", primaryBodyPart: .chest),
        Exercise(name: "Cable Fly", primaryBodyPart: .chest),
        Exercise(name: "Squat", primaryBodyPart: .quads),
        Exercise(name: "Curl", primaryBodyPart: .biceps),
    ]

    @Test func bodyPartPillNarrowsTheList() {
        let chest = ExerciseFiltering.filter(library, search: "", bodyPart: .chest)
        #expect(chest.map(\.name) == ["Bench Press", "Cable Fly"])
        #expect(ExerciseFiltering.filter(library, search: "", bodyPart: nil).count == 4)
    }

    @Test func searchAndPillCombine() {
        let hit = ExerciseFiltering.filter(library, search: "fly", bodyPart: .chest)
        #expect(hit.map(\.name) == ["Cable Fly"])
        #expect(ExerciseFiltering.filter(library, search: "fly", bodyPart: .quads).isEmpty)
    }

    @Test func pillsOnlyListBodyPartsPresentInTheLibrary() {
        let parts = ExerciseFiltering.bodyParts(in: library)
        #expect(parts == [.biceps, .chest, .quads])
    }
}
