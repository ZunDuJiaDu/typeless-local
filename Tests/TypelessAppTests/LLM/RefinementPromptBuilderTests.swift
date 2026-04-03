import Testing
@testable import Typeless

struct RefinementPromptBuilderTests {
    @Test func systemPromptForbidsRewriting() {
        let prompt = RefinementPromptBuilder.systemPrompt
        #expect(prompt.contains("不要改写"))
        #expect(prompt.contains("必须原样返回"))
    }

    @Test func userPromptCarriesRawTranscript() {
        let prompt = RefinementPromptBuilder.userPrompt(for: "配森 杰森")
        #expect(prompt.contains("配森 杰森"))
    }
}
