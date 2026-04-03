import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import WuZi

struct FnEventInterpreterTests {
    @Test func functionKeyTransitionsEmitSemanticEventsAndStaySuppressed() {
        let interpreter = FnEventInterpreter()

        let press = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
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
            flags: CGEventFlags.maskSecondaryFn
        )
        let duplicatePress = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
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

    @Test func resetClearsStaleFnStateAfterMissedRelease() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )

        interpreter.reset()

        let pressAfterReset = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )
        #expect(pressAfterReset.event == .pressed)
        #expect(pressAfterReset.shouldSuppress)
    }

    @Test func unknownStateStillEmitsReleaseAfterTapInterruption() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )

        interpreter.markStateUnknown()

        let releaseAfterInterruption = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: []
        )
        #expect(releaseAfterInterruption.event == .released)
        #expect(releaseAfterInterruption.shouldSuppress)
    }

    @Test func unknownStateAllowsNextPressAfterMissedRelease() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )

        interpreter.markStateUnknown()

        let nextPress = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )
        #expect(nextPress.event == .pressed)
        #expect(nextPress.shouldSuppress)
    }

    @Test func nonFunctionModifierChangesWhileFnIsHeldAreNotSuppressed() {
        let interpreter = FnEventInterpreter()

        _ = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Function),
            flags: CGEventFlags.maskSecondaryFn
        )

        let shiftTransition = interpreter.interpret(
            type: .flagsChanged,
            keyCode: CGKeyCode(kVK_Shift),
            flags: [CGEventFlags.maskSecondaryFn, CGEventFlags.maskShift]
        )
        #expect(shiftTransition.event == nil)
        #expect(!shiftTransition.shouldSuppress)
    }
}
