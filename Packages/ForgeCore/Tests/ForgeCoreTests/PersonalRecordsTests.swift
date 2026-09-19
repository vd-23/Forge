import Foundation
import Testing
@testable import ForgeCore

@Suite struct PersonalRecordsTests {
    let benchID = UUID()

    func finished(_ sets: [SetInput], daysAgo: Int) -> SessionInput {
        let ex = ExerciseInput(id: benchID, isBodyweight: false, isUnilateral: false)
        let day = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
        return SessionInput(id: UUID(), startedAt: day, endedAt: day,
                            exercises: [WorkoutExerciseInput(exercise: ex, sets: sets)])
    }

    @Test func aggregatesMaxWeightRepsAndE1RMOverHistory() {
        let history = [
            finished([SetInput(weightKg: 80, reps: 8)], daysAgo: 20),
            finished([SetInput(weightKg: 100, reps: 3), SetInput(weightKg: 60, reps: 15)], daysAgo: 10),
        ]
        let pr = personalRecords(history, exerciseID: benchID)
        #expect(pr.maxWeightKg == 100)
        #expect(pr.maxReps == 15)
        // best e1rm: 100*(1+3/30)=110 vs 80*(1+8/30)=101.3 vs 60*(1+15/30)=90
        #expect(abs((pr.bestE1RM ?? 0) - 110) < 0.001)
    }

    @Test func warmupsAndUnfinishedSessionsAreIgnored() {
        var unfinished = finished([SetInput(weightKg: 200, reps: 1)], daysAgo: 1)
        unfinished = SessionInput(id: unfinished.id, startedAt: unfinished.startedAt,
                                  endedAt: nil, exercises: unfinished.exercises)
        let pr = personalRecords(
            [unfinished, finished([SetInput(weightKg: 90, reps: 5, isWarmup: true)], daysAgo: 3)],
            exerciseID: benchID
        )
        #expect(pr.maxWeightKg == nil)
        #expect(pr.bestE1RM == nil)
    }

    @Test func newPersonalRecordsReportsOnlyBeatenCategories() {
        let history = [finished([SetInput(weightKg: 100, reps: 5)], daysAgo: 7)] // e1rm 116.67, wt 100, reps 5
        let today = finished([SetInput(weightKg: 105, reps: 5)], daysAgo: 0)     // e1rm 122.5, wt 105, reps 5
        let hits = newPersonalRecords(in: today, history: history)
        let kinds = Set(hits.map(\.kind))
        #expect(kinds == [.weight, .e1rm])   // reps tied, not beaten
        #expect(hits.first(where: { $0.kind == .weight })?.value == 105)
    }

    @Test func noHistoryMeansEveryCategoryIsAPR() {
        let today = finished([SetInput(weightKg: 60, reps: 10)], daysAgo: 0)
        let hits = newPersonalRecords(in: today, history: [])
        #expect(Set(hits.map(\.kind)) == [.weight, .reps, .e1rm])
    }
}
