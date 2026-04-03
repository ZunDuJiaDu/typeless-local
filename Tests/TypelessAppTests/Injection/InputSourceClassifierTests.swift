import Testing
@testable import WuZi

struct InputSourceClassifierTests {
    @Test func classifiesCommonCJKIdentifiers() {
        #expect(InputSourceClassifier.classify(identifier: "com.apple.inputmethod.SCIM.ITABC") == .cjk)
        #expect(InputSourceClassifier.classify(identifier: "com.apple.inputmethod.Kotoeri.Japanese") == .cjk)
        #expect(InputSourceClassifier.classify(identifier: "com.apple.inputmethod.Korean.2SetKorean") == .cjk)
    }

    @Test func classifiesASCIIFriendlyIdentifiers() {
        #expect(InputSourceClassifier.classify(identifier: "com.apple.keylayout.ABC") == .asciiCapable)
        #expect(InputSourceClassifier.classify(identifier: "com.apple.keylayout.US") == .asciiCapable)
    }
}
