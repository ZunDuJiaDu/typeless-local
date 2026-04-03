import Testing
@testable import WuZi

struct WaveformModelTests {
    @Test func higherLevelProducesTallerCenterBar() {
        var smoother = EnvelopeSmoother(attackFactor: 0.4, releaseFactor: 0.15)
        let model = WaveformModel(randomSource: { 0 })
        let low = model.barHeights(for: smoother.process(level: 0.1))
        let high = model.barHeights(for: smoother.process(level: 0.9))
        #expect(low[2] < high[2])
    }

    @Test func centerHighSideLowWeighting() {
        let model = WaveformModel(randomSource: { 0 })
        let values = model.barHeights(for: 1.0)
        #expect(values[2] > values[1])
        #expect(values[1] > values[0])
        #expect(values[2] > values[3])
        #expect(values[3] > values[4])
    }

    @Test func widthClampRespectsBounds() {
        #expect(WaveformModel.clampedWidth(for: "") == 160)
        #expect(WaveformModel.clampedWidth(for: String(repeating: "a", count: 500)) == 560)
    }

    @Test func jitterStaysWithinFourPercent() {
        let model = WaveformModel(randomSource: { 1.0 })
        let heights = model.barHeights(for: 1.0)
        #expect(heights.max()! <= 1.04)
    }
}
