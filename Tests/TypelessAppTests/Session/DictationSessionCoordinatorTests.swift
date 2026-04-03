import Testing
@testable import Typeless

struct DictationSessionCoordinatorTests {
    @Test func pressMovesIdleToRecording() {
        let reducer = DictationSessionReducer()
        let state = reducer.reduce(.idle, event: .fnPressed)
        #expect(state == .recording)
    }

    @Test func releaseMovesRecordingToFinalizing() {
        let reducer = DictationSessionReducer()
        let state = reducer.reduce(.recording, event: .fnReleased)
        #expect(state == .finalizingASR)
    }

    @Test func refineFailureFallsBackToInjecting() {
        let reducer = DictationSessionReducer()
        let state = reducer.reduce(.refining, event: .refinementFailed)
        #expect(state == .injecting)
    }

    @Test func terminalErrorsMoveToFailed() {
        let reducer = DictationSessionReducer()
        let state = reducer.reduce(.injecting, event: .failureOccurred)
        #expect(state == .failed)
    }
}
