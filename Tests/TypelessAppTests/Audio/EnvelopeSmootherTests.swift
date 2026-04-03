import Testing
@testable import WuZi

struct EnvelopeSmootherTests {
    @Test func attackRespondsFasterThanRelease() {
        var smoother = EnvelopeSmoother(attackFactor: 0.4, releaseFactor: 0.15)
        let rising = smoother.process(level: 1.0)
        let falling = smoother.process(level: 0.0)
        #expect(rising > 0.39)
        #expect(falling > 0.0)
        #expect(falling < rising)
    }
}
