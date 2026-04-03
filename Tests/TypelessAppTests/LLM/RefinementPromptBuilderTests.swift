import Testing
@testable import Typeless

struct RefinementPromptBuilderTests {
    @Test func systemPromptPreservesMeaningToneAndStructure() {
        let prompt = TextOrganizationPromptBuilder.systemPrompt(options: .default)
        #expect(prompt.contains("严格保持原意"))
        #expect(prompt.contains("保留说话者原本的语气"))
        #expect(prompt.contains("结构意图"))
    }

    @Test func userPromptCarriesRawTranscript() {
        let prompt = TextOrganizationPromptBuilder.userPrompt(for: "配森 杰森")
        #expect(prompt.contains("配森 杰森"))
    }
}
