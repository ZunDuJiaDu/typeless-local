import Foundation

public final class SettingsStore {
    private enum Keys {
        static let selectedLocale = "settings.selectedLocale"
        static let isLLMRefinementEnabled = "settings.isLLMRefinementEnabled"
        static let llmConfiguration = "settings.llmConfiguration"
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
        get {
            if userDefaults.object(forKey: Keys.isLLMRefinementEnabled) == nil {
                return false
            }
            return userDefaults.bool(forKey: Keys.isLLMRefinementEnabled)
        }
        set { userDefaults.set(newValue, forKey: Keys.isLLMRefinementEnabled) }
    }

    public var llmConfiguration: LLMConfiguration {
        get {
            guard
                let data = userDefaults.data(forKey: Keys.llmConfiguration),
                let config = try? decoder.decode(LLMConfiguration.self, from: data)
            else {
                return .empty
            }
            return config
        }
        set {
            if let data = try? encoder.encode(newValue) {
                userDefaults.set(data, forKey: Keys.llmConfiguration)
            }
        }
    }

    public var settings: AppSettings {
        get {
            AppSettings(
                selectedLocale: selectedLocale,
                isLLMRefinementEnabled: isLLMRefinementEnabled,
                llmConfiguration: llmConfiguration
            )
        }
        set {
            selectedLocale = newValue.selectedLocale
            isLLMRefinementEnabled = newValue.isLLMRefinementEnabled
            llmConfiguration = newValue.llmConfiguration
        }
    }
}
