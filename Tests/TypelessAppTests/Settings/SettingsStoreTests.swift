import Foundation
import Testing
@testable import Typeless

struct SettingsStoreTests {
    @Test func defaultsToSimplifiedChineseAndOllamaPrimary() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        #expect(store.selectedLocale == .simplifiedChinese)
        #expect(store.isLLMRefinementEnabled == false)
        #expect(store.textOrganizationSettings.preferredProvider == .ollama)
        #expect(store.textOrganizationSettings.ollamaConfiguration.host == "http://127.0.0.1:11434")
    }

    @Test func persistsLocaleAndOllamaOrganizationState() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        store.selectedLocale = .japanese
        store.textOrganizationSettings = TextOrganizationSettings(
            isEnabled: true,
            preferredProvider: .ollama,
            ollamaConfiguration: .init(host: "http://localhost:11434", model: "llama3.2"),
            openAICompatibleConfiguration: .empty,
            options: .init(strength: .strong, preserveTone: false, preserveStructureIntent: true)
        )
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.selectedLocale == .japanese)
        #expect(reloaded.textOrganizationSettings.isEnabled)
        #expect(reloaded.textOrganizationSettings.preferredProvider == .ollama)
        #expect(reloaded.textOrganizationSettings.options.strength == .strong)
        #expect(reloaded.textOrganizationSettings.options.preserveTone == false)
    }

    @Test func legacyOpenAIConfigurationBecomesSecondaryPath() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        store.llmConfiguration = .init(baseURL: "https://example.com", apiKey: "secret", model: "gpt-4o-mini")
        store.isLLMRefinementEnabled = true

        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.textOrganizationSettings.isEnabled)
        #expect(reloaded.textOrganizationSettings.preferredProvider == .openAICompatible)
        #expect(reloaded.textOrganizationSettings.openAICompatibleConfiguration.baseURL == "https://example.com")
        #expect(reloaded.textOrganizationSettings.openAICompatibleConfiguration.apiKey == "secret")
    }

    @Test func apiKeyCanBeFullyCleared() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        store.llmConfiguration = .init(baseURL: "https://example.com", apiKey: "secret", model: "gpt")
        store.llmConfiguration = .init(baseURL: "https://example.com", apiKey: "", model: "gpt")
        #expect(SettingsStore(userDefaults: defaults).llmConfiguration.apiKey == "")
    }
}
