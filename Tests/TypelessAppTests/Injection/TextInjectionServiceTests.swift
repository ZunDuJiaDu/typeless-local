import Foundation
import Testing
@testable import Typeless

@MainActor
struct TextInjectionServiceTests {
    @Test func cleanupRunsInRestoreInputSourceThenPasteboardOrder() async throws {
        let recorder = CleanupRecorder()
        let service = TextInjectionService(
            pasteboardService: FakePasteboardService(recorder: recorder),
            inputSourceService: FakeInputSourceService(recorder: recorder, currentIdentifier: "com.apple.inputmethod.SCIM.ITABC"),
            keyboardPastePerformer: FakeKeyboardPastePerformer(recorder: recorder)
        )

        try await service.inject(text: "hello")

        #expect(recorder.events == [
            "capturePasteboard",
            "readInputSource",
            "switchToASCII",
            "setPasteboardString",
            "performPaste",
            "restoreInputSource",
            "restorePasteboard"
        ])
    }

    @Test func cjkInjectionWaitsLongEnoughForSwitchAndPasteToSettle() async throws {
        let recorder = CleanupRecorder()
        let service = TextInjectionService(
            pasteboardService: FakePasteboardService(recorder: recorder),
            inputSourceService: FakeInputSourceService(recorder: recorder, currentIdentifier: "com.apple.inputmethod.SCIM.ITABC"),
            keyboardPastePerformer: FakeKeyboardPastePerformer(recorder: recorder)
        )

        let clock = ContinuousClock()
        let start = clock.now

        try await service.inject(text: "hello")

        let elapsed = start.duration(to: clock.now)
        #expect(elapsed >= .milliseconds(150))
        #expect(recorder.events.suffix(2) == ["restoreInputSource", "restorePasteboard"])
    }

    @Test func cleanupFailuresAreSurfacedAfterRestoringRemainingState() async throws {
        let recorder = CleanupRecorder()
        let service = TextInjectionService(
            pasteboardService: FakePasteboardService(recorder: recorder),
            inputSourceService: FakeInputSourceService(
                recorder: recorder,
                currentIdentifier: "com.apple.inputmethod.SCIM.ITABC",
                restoreError: FakeTestError.restoreInputSource
            ),
            keyboardPastePerformer: FakeKeyboardPastePerformer(recorder: recorder)
        )

        var capturedError: (any Error)?

        do {
            try await service.inject(text: "hello")
        } catch {
            capturedError = error
        }

        #expect(capturedError != nil)
        #expect(recorder.events == [
            "capturePasteboard",
            "readInputSource",
            "switchToASCII",
            "setPasteboardString",
            "performPaste",
            "restoreInputSource",
            "restorePasteboard"
        ])
    }
}

final class CleanupRecorder: @unchecked Sendable { var events: [String] = [] }

enum FakeTestError: Error {
    case restoreInputSource
    case restorePasteboard
    case performPaste
}

final class FakePasteboardService: PasteboardSnapshotting {
    let recorder: CleanupRecorder
    var restoreError: FakeTestError?

    init(recorder: CleanupRecorder, restoreError: FakeTestError? = nil) {
        self.recorder = recorder
        self.restoreError = restoreError
    }

    func capture() async throws -> PasteboardSnapshot {
        recorder.events.append("capturePasteboard")
        return PasteboardSnapshot(items: [])
    }
    func set(string: String) async throws { recorder.events.append("setPasteboardString") }
    func restore(snapshot: PasteboardSnapshot) async throws {
        recorder.events.append("restorePasteboard")
        if let restoreError {
            throw restoreError
        }
    }
}

final class FakeInputSourceService: InputSourceManaging {
    let recorder: CleanupRecorder
    let currentIdentifier: String
    var shouldSwitch = true
    var restoreError: FakeTestError?

    init(recorder: CleanupRecorder, currentIdentifier: String) {
        self.recorder = recorder
        self.currentIdentifier = currentIdentifier
    }

    convenience init(
        recorder: CleanupRecorder,
        currentIdentifier: String,
        shouldSwitch: Bool = true,
        restoreError: FakeTestError? = nil
    ) {
        self.init(recorder: recorder, currentIdentifier: currentIdentifier)
        self.shouldSwitch = shouldSwitch
        self.restoreError = restoreError
    }

    func currentInputSource() async throws -> InputSourceDescriptor {
        recorder.events.append("readInputSource")
        return InputSourceDescriptor(identifier: currentIdentifier)
    }
    func selectASCIISourceIfNeeded(from source: InputSourceDescriptor) async throws -> Bool {
        recorder.events.append("switchToASCII")
        return shouldSwitch
    }
    func restoreInputSource(_ descriptor: InputSourceDescriptor) async throws {
        recorder.events.append("restoreInputSource")
        if let restoreError {
            throw restoreError
        }
    }
}

final class FakeKeyboardPastePerformer: KeyboardPastePerforming {
    let recorder: CleanupRecorder
    var pasteError: FakeTestError?

    init(recorder: CleanupRecorder, pasteError: FakeTestError? = nil) {
        self.recorder = recorder
        self.pasteError = pasteError
    }

    func performPaste() async throws {
        recorder.events.append("performPaste")
        if let pasteError {
            throw pasteError
        }
    }
}
