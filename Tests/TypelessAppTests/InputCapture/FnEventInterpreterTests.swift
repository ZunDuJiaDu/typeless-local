import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import Typeless

struct FnEventInterpreterTests {
    @Test func functionKeyTransitionsEmitSemanticEventsAndStaySuppressed() {
        let interpreter = FnEventInterpreter()

        let press = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: .maskSecondaryFn
        )
        #expect(press.event == .pressed)
        #expect(press.shouldSuppress)

        let release = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: []
        )
        #expect(release.event == .released)
        #expect(release.shouldSuppress)
    }

    @Test func duplicateFunctionFlagChangesStaySuppressedWithoutDuplicateTransitions() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: .maskSecondaryFn
        )
        let duplicatePress = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: .maskSecondaryFn
        )
        #expect(duplicatePress.event == nil)
        #expect(duplicatePress.shouldSuppress)

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: []
        )
        let duplicateRelease = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: []
        )
        #expect(duplicateRelease.event == nil)
        #expect(duplicateRelease.shouldSuppress)
    }

    @Test func nonFunctionModifierChangesWhileFnIsHeldAreNotSuppressed() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: .maskSecondaryFn
        )

        let shiftTransition = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Shift),
            flags: [.maskSecondaryFn, .maskShift]
        )
        #expect(shiftTransition.event == nil)
        #expect(!shiftTransition.shouldSuppress)
    }
}
