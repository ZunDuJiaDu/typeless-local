import Foundation

public enum DictationSessionState: Equatable {
    case idle
    case recording
    case finalizingASR
    case refining
    case injecting
    case recovering
    case failed
}

public enum DictationSessionEvent: Equatable {
    case fnPressed
    case fnReleased
    case finalTranscriptReady
    case refinementStarted
    case refinementFinished
    case refinementFailed
    case injectionStarted
    case recoveryFinished
    case failureOccurred
}

public struct DictationSessionReducer {
    public init() {}

    public func reduce(_ state: DictationSessionState, event: DictationSessionEvent) -> DictationSessionState {
        switch (state, event) {
        case (.idle, .fnPressed):
            return .recording
        case (.recording, .fnReleased):
            return .finalizingASR
        case (.finalizingASR, .refinementStarted):
            return .refining
        case (.finalizingASR, .finalTranscriptReady):
            return .injecting
        case (.refining, .refinementFinished), (.refining, .refinementFailed):
            return .injecting
        case (.injecting, .recoveryFinished), (.recovering, .recoveryFinished), (.failed, .recoveryFinished):
            return .idle
        case (_, .failureOccurred):
            return .failed
        default:
            return state
        }
    }
}
