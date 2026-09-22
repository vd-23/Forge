import Testing
@testable import Forge

struct HeatmapLabelsTests {
    private func columns(_ labels: [String?]) -> [(id: Int, label: String?)] {
        labels.enumerated().map { (id: $0.offset, label: $0.element) }
    }

    @Test func wellSpacedLabelsAllShow() {
        let cols = columns(["May", nil, nil, nil, "Jun", nil, nil, nil, "Jul", nil, nil, nil])
        #expect(HeatmapLabels.visible(cols) == [0: "May", 4: "Jun", 8: "Jul"])
    }

    @Test func aMonthWithOneColumnYieldsToTheNext() {
        // The crashing case from the device: May starts in column 0, Jun in column 1.
        let cols = columns(["May", "Jun", nil, nil, nil, "Jul", nil, nil, nil])
        #expect(HeatmapLabels.visible(cols) == [1: "Jun", 5: "Jul"])
    }

    @Test func aLastShortMonthStillShows() {
        let cols = columns(["May", nil, nil, nil, "Jun", nil, nil, nil, "Jul"])
        #expect(HeatmapLabels.visible(cols) == [0: "May", 4: "Jun", 8: "Jul"])
    }

    @Test func twoShortMonthsInARowDropTheSecond() {
        let cols = columns(["May", nil, nil, "Jun", "Jul", nil, nil, nil])
        #expect(HeatmapLabels.visible(cols) == [0: "May", 4: "Jul"])
    }

    @Test func emptyAndUnlabelledInputs() {
        #expect(HeatmapLabels.visible(columns([])).isEmpty)
        #expect(HeatmapLabels.visible(columns([nil, nil, nil])).isEmpty)
        #expect(HeatmapLabels.visible(columns(["May"])) == [0: "May"])
    }
}
