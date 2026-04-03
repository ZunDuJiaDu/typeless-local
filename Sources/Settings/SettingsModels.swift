import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedLocale: RecognitionLocale
    public var textOrganizationSettings: TextOrganizationSettings
    public var hasCompletedWelcome: Bool

    public init(
        selectedLocale: RecognitionLocale = .default,
        textOrganizationSettings: TextOrganizationSettings = .default,
        hasCompletedWelcome: Bool = false
    ) {
        self.selectedLocale = selectedLocale
        self.textOrganizationSettings = textOrganizationSettings
        self.hasCompletedWelcome = hasCompletedWelcome
    }

    public init(
        selectedLocale: RecognitionLocale = .default,
        isLLMRefinementEnabled: Bool = false,
        llmConfiguration: LLMConfiguration = .empty,
        hasCompletedWelcome: Bool = false
    ) {
        self.selectedLocale = selectedLocale
        self.textOrganizationSettings = TextOrganizationSettings.fromLegacy(
            isEnabled: isLLMRefinementEnabled,
            openAICompatibleConfiguration: llmConfiguration
        )
        self.hasCompletedWelcome = hasCompletedWelcome
    }

    public var isLLMRefinementEnabled: Bool {
        get { textOrganizationSettings.isEnabled }
        set { textOrganizationSettings.isEnabled = newValue }
    }

    public var llmConfiguration: LLMConfiguration {
        get { textOrganizationSettings.openAICompatibleConfiguration }
        set { textOrganizationSettings.openAICompatibleConfiguration = newValue.normalized() }
    }
}
