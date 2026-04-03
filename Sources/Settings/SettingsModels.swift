import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedLocale: RecognitionLocale
    public var isLLMRefinementEnabled: Bool
    public var llmConfiguration: LLMConfiguration

    public init(
        selectedLocale: RecognitionLocale = .default,
        isLLMRefinementEnabled: Bool = false,
        llmConfiguration: LLMConfiguration = .empty
    ) {
        self.selectedLocale = selectedLocale
        self.isLLMRefinementEnabled = isLLMRefinementEnabled
        self.llmConfiguration = llmConfiguration
    }
}
