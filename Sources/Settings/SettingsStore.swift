import Foundation

public final class SettingsStore {
    private enum Keys {
        static let selectedLocale = "settings.selectedLocale"
        static let isLLMRefinementEnabled = "settings.isLLMRefinementEnabled"
        static let llmConfiguration = "settings.llmConfiguration"
        static let textOrganizationSettings = "settings.textOrganizationSettings"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var selectedLocale: RecognitionLocale {
        get { RecognitionLocale.persisted(userDefaults.string(forKey: Keys.selectedLocale)) }
        set { userDefaults.set(newValue.rawValue, forKey: Keys.selectedLocale) }
    }

    public var isLLMRefinementEnabled: Bool {
        get { textOrganizationSettings.isEnabled }
        set {
            var settings = textOrganizationSettings
            settings.isEnabled = newValue
            if newValue, settings.openAICompatibleConfiguration.isConfigured {
                settings.preferredProvider = .openAICompatible
            }
            textOrganizationSettings = settings
        }
    }

    public var llmConfiguration: LLMConfiguration {
        get { textOrganizationSettings.openAICompatibleConfiguration }
        set {
            var settings = textOrganizationSettings
            settings.openAICompatibleConfiguration = newValue.normalized()
            if settings.openAICompatibleConfiguration.isConfigured {
                settings.preferredProvider = .openAICompatible
            }
            textOrganizationSettings = settings
        }
    }

    public var textOrganizationSettings: TextOrganizationSettings {
        get {
            if let settings = loadTextOrganizationSettings() {
                return settings
            }

            let legacyEnabled = legacyLLMRefinementEnabled()
            let legacyConfiguration = legacyLLMConfiguration()
            return TextOrganizationSettings.fromLegacy(
                isEnabled: legacyEnabled,
                openAICompatibleConfiguration: legacyConfiguration
            )
        }
        set {
            let normalized = newValue.normalized()
            if let data = try? encoder.encode(normalized) {
                userDefaults.set(data, forKey: Keys.textOrganizationSettings)
            }
            syncLegacyLLMSettings(from: normalized)
        }
    }

    public var settings: AppSettings {
        get {
            AppSettings(
                selectedLocale: selectedLocale,
                textOrganizationSettings: textOrganizationSettings
            )
        }
        set {
            selectedLocale = newValue.selectedLocale
            textOrganizationSettings = newValue.textOrganizationSettings
        }
    }

    private func loadTextOrganizationSettings() -> TextOrganizationSettings? {
        guard
            let data = userDefaults.data(forKey: Keys.textOrganizationSettings),
            let settings = try? decoder.decode(TextOrganizationSettings.self, from: data)
        else {
            return nil
        }
        return settings.normalized()
    }

    private func legacyLLMRefinementEnabled() -> Bool {
        guard userDefaults.object(forKey: Keys.isLLMRefinementEnabled) != nil else {
            return false
        }
        return userDefaults.bool(forKey: Keys.isLLMRefinementEnabled)
    }

    private func legacyLLMConfiguration() -> LLMConfiguration {
        guard
            let data = userDefaults.data(forKey: Keys.llmConfiguration),
            let config = try? decoder.decode(LLMConfiguration.self, from: data)
        else {
            return .empty
        }
        return config.normalized()
    }

    private func syncLegacyLLMSettings(from settings: TextOrganizationSettings) {
        userDefaults.set(
            settings.isEnabled && settings.preferredProvider == .openAICompatible,
            forKey: Keys.isLLMRefinementEnabled
        )

        if let data = try? encoder.encode(settings.openAICompatibleConfiguration.normalized()) {
            userDefaults.set(data, forKey: Keys.llmConfiguration)
        }
    }
}
