import Carbon.HIToolbox
import CoreGraphics
import Foundation

public enum FnSemanticEvent: Equatable {
    case pressed
    case released
}

public final class FnEventInterpreter {
    private let functionKeyCode: CGKeyCode
    private var isFnDown = false

    public init(functionKeyCode: CGKeyCode = CGKeyCode(kVK_Function)) {
        self.functionKeyCode = functionKeyCode
    }

    public func reset() {
        isFnDown = false
    }

    public func interpret(event: CGEvent, type: CGEventType) -> (event: FnSemanticEvent?, shouldSuppress: Bool) {
        interpret(
            type: type,
            keyCode: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags
        )
    }

    public func interpret(
        type: CGEventType,
        keyCode: CGKeyCode?,
        flags: CGEventFlags
    ) -> (event: FnSemanticEvent?, shouldSuppress: Bool) {
        guard type == .flagsChanged else {
            return (nil, false)
        }

        let nextState = flags.contains(.maskSecondaryFn)
        let isFunctionKeyEvent = keyCode.map { $0 == functionKeyCode } ?? (nextState != isFnDown)
        guard isFunctionKeyEvent else {
            return (nil, false)
        }

        guard nextState != isFnDown else {
            return (nil, true)
        }

        isFnDown = nextState
        return (nextState ? .pressed : .released, true)
    }
}
