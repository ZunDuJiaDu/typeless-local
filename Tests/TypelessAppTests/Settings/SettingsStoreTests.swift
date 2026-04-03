import Foundation
import Testing
@testable import Typeless

struct SettingsStoreTests {
    @Test func defaultsToSimplifiedChinese() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        #expect(store.selectedLocale == .simplifiedChinese)
        #expect(store.isLLMRefinementEnabled == false)
    }

    @Test func persistsLocaleAndLLMState() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(userDefaults: defaults)
        store.selectedLocale = .japanese
        store.isLLMRefinementEnabled = true
        let reloaded = SettingsStore(userDefaults: defaults)
        #expect(reloaded.selectedLocale == .japanese)
        #expect(reloaded.isLLMRefinementEnabled)
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
