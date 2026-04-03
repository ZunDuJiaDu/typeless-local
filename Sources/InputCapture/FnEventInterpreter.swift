import CoreGraphics
import Foundation

public enum FnSemanticEvent: Equatable {
    case pressed
    case released
}

public final class FnEventInterpreter {
    private var isFnDown = false

    public init() {}

    public func interpret(event: CGEvent, type: CGEventType) -> (event: FnSemanticEvent?, shouldSuppress: Bool) {
        guard type == .flagsChanged else {
            return (nil, false)
        }
        let nextState = event.flags.contains(.maskSecondaryFn)
        guard nextState != isFnDown else {
            return (nil, false)
        }
        isFnDown = nextState
        return (nextState ? .pressed : .released, true)
    }
}
