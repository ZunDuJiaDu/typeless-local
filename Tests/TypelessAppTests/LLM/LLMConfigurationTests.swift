import Testing
@testable import WuZi

struct LLMConfigurationTests {
    @Test func enabledConfigurationRequiresBaseURLAndModel() {
        let config = LLMConfiguration(baseURL: "", apiKey: "secret", model: "")
        let errors = config.validationErrors(isEnabled: true)
        #expect(errors.contains(.missingBaseURL))
        #expect(errors.contains(.missingModel))
    }

    @Test func disabledConfigurationAllowsEmptyAPIKey() {
        let config = LLMConfiguration(baseURL: "https://example.com", apiKey: "", model: "gpt-4o-mini")
        #expect(config.validationErrors(isEnabled: false).isEmpty)
    }
}
