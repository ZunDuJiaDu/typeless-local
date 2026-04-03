import Testing
@testable import Typeless

struct RecognitionLocaleTests {
    @Test func supportedIdentifiersRoundTrip() {
        #expect(RecognitionLocale(rawValue: "zh-CN") == .simplifiedChinese)
        #expect(RecognitionLocale(rawValue: "zh-TW") == .traditionalChinese)
        #expect(RecognitionLocale(rawValue: "en") == .english)
        #expect(RecognitionLocale(rawValue: "ja") == .japanese)
        #expect(RecognitionLocale(rawValue: "ko") == .korean)
    }

    @Test func invalidPersistedLocaleFallsBackToSimplifiedChinese() {
        #expect(RecognitionLocale.persisted("nope") == .simplifiedChinese)
    }
}
