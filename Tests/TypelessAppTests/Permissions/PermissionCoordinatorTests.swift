import Testing
@testable import WuZi

struct AccessibilityPromptGateTests {
    @Test func deniedStatePromptsOnlyOnceUntilPermissionIsGranted() {
        var gate = AccessibilityPromptGate()

        let firstDenied = gate.shouldPrompt(accessibilityGranted: false)
        let secondDenied = gate.shouldPrompt(accessibilityGranted: false)
        let granted = gate.shouldPrompt(accessibilityGranted: true)
        let deniedAfterGrant = gate.shouldPrompt(accessibilityGranted: false)

        #expect(firstDenied)
        #expect(!secondDenied)
        #expect(!granted)
        #expect(deniedAfterGrant)
    }

    @Test func grantedStateDoesNotPrompt() {
        var gate = AccessibilityPromptGate()

        let firstGranted = gate.shouldPrompt(accessibilityGranted: true)
        let secondGranted = gate.shouldPrompt(accessibilityGranted: true)

        #expect(!firstGranted)
        #expect(!secondGranted)
    }
}
