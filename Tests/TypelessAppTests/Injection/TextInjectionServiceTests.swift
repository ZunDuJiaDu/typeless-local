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
}

final class CleanupRecorder: @unchecked Sendable { var events: [String] = [] }

final class FakePasteboardService: PasteboardSnapshotting {
    let recorder: CleanupRecorder
    init(recorder: CleanupRecorder) { self.recorder = recorder }
    func capture() async throws -> PasteboardSnapshot {
        recorder.events.append("capturePasteboard")
        return PasteboardSnapshot(items: [])
    }
    func set(string: String) async throws { recorder.events.append("setPasteboardString") }
    func restore(snapshot: PasteboardSnapshot) async throws { recorder.events.append("restorePasteboard") }
}

final class FakeInputSourceService: InputSourceManaging {
    let recorder: CleanupRecorder
    let currentIdentifier: String
    init(recorder: CleanupRecorder, currentIdentifier: String) {
        self.recorder = recorder
        self.currentIdentifier = currentIdentifier
    }
    func currentInputSource() async throws -> InputSourceDescriptor {
        recorder.events.append("readInputSource")
        return InputSourceDescriptor(identifier: currentIdentifier)
    }
    func selectASCIISourceIfNeeded(from source: InputSourceDescriptor) async throws -> Bool {
        recorder.events.append("switchToASCII")
        return true
    }
    func restoreInputSource(_ descriptor: InputSourceDescriptor) async throws {
        recorder.events.append("restoreInputSource")
    }
}

final class FakeKeyboardPastePerformer: KeyboardPastePerforming {
    let recorder: CleanupRecorder
    init(recorder: CleanupRecorder) { self.recorder = recorder }
    func performPaste() async throws { recorder.events.append("performPaste") }
}
