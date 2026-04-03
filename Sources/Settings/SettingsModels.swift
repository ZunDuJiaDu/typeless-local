import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedLocale: RecognitionLocale
    public var textOrganizationSettings: TextOrganizationSettings

    public init(
        selectedLocale: RecognitionLocale = .default,
        textOrganizationSettings: TextOrganizationSettings = .default
    ) {
        self.selectedLocale = selectedLocale
        self.textOrganizationSettings = textOrganizationSettings
    }

    public init(
        selectedLocale: RecognitionLocale = .default,
        isLLMRefinementEnabled: Bool = false,
        llmConfiguration: LLMConfiguration = .empty
    ) {
        self.selectedLocale = selectedLocale
        self.textOrganizationSettings = TextOrganizationSettings.fromLegacy(
            isEnabled: isLLMRefinementEnabled,
            openAICompatibleConfiguration: llmConfiguration
        )
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
