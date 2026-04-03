import Foundation

public enum TextOrganizationProviderKind: String, Codable, CaseIterable, Sendable {
    case ollama
    case openAICompatible

    public var displayName: String {
        switch self {
        case .ollama:
            return "Ollama"
        case .openAICompatible:
            return "OpenAI-Compatible"
        }
    }
}

public enum OrganizationStrength: String, Codable, CaseIterable, Sendable {
    case light
    case balanced
    case strong

    public var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .balanced:
            return "Balanced"
        case .strong:
            return "Strong"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .light:
            return "只做最小必要整理：修复明显识别错误，补足必要标点。"
        case .balanced:
            return "做适度整理：修复明显识别错误，补足标点，并在必要时分段。"
        case .strong:
            return "做较强整理：在不改变含义的前提下，允许重组句子、分段或项目符号让文本更清晰。"
        }
    }
}

public enum TextOrganizationValidationError: Error, Equatable, Sendable {
    case missingOllamaHost
    case missingOllamaModel
    case missingOpenAIBaseURL
    case missingOpenAIModel

    public var debugDescription: String {
        switch self {
        case .missingOllamaHost:
            return "Ollama Host"
        case .missingOllamaModel:
            return "Ollama Model"
        case .missingOpenAIBaseURL:
            return "OpenAI-Compatible Base URL"
        case .missingOpenAIModel:
            return "OpenAI-Compatible Model"
        }
    }
}

public struct TextOrganizationOptions: Codable, Equatable, Sendable {
    public var strength: OrganizationStrength
    public var preserveTone: Bool
    public var preserveStructureIntent: Bool

    public init(
        strength: OrganizationStrength = .balanced,
        preserveTone: Bool = true,
        preserveStructureIntent: Bool = true
    ) {
        self.strength = strength
        self.preserveTone = preserveTone
        self.preserveStructureIntent = preserveStructureIntent
    }

    public static let `default` = TextOrganizationOptions()
}

public struct OllamaConfiguration: Codable, Equatable, Sendable {
    public var host: String
    public var model: String

    public init(
        host: String = "http://127.0.0.1:11434",
        model: String = "qwen2.5:7b-instruct"
    ) {
        self.host = host
        self.model = model
    }

    public static let empty = OllamaConfiguration(host: "", model: "")
    public static let recommendedDefault = OllamaConfiguration()

    public var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isConfigured: Bool {
        !normalizedHost.isEmpty && !normalizedModel.isEmpty
    }

    public func normalized() -> OllamaConfiguration {
        OllamaConfiguration(
            host: normalizedHost,
            model: normalizedModel
        )
    }

    public func validationErrors(isEnabled: Bool) -> [TextOrganizationValidationError] {
        guard isEnabled else { return [] }
        var errors: [TextOrganizationValidationError] = []
        if normalizedHost.isEmpty { errors.append(.missingOllamaHost) }
        if normalizedModel.isEmpty { errors.append(.missingOllamaModel) }
        return errors
    }
}

public struct TextOrganizationSettings: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var preferredProvider: TextOrganizationProviderKind
    public var ollamaConfiguration: OllamaConfiguration
    public var openAICompatibleConfiguration: LLMConfiguration
    public var options: TextOrganizationOptions

    public init(
        isEnabled: Bool = false,
        preferredProvider: TextOrganizationProviderKind = .ollama,
        ollamaConfiguration: OllamaConfiguration = .recommendedDefault,
        openAICompatibleConfiguration: LLMConfiguration = .empty,
        options: TextOrganizationOptions = .default
    ) {
        self.isEnabled = isEnabled
        self.preferredProvider = preferredProvider
        self.ollamaConfiguration = ollamaConfiguration
        self.openAICompatibleConfiguration = openAICompatibleConfiguration
        self.options = options
    }

    public static let `default` = TextOrganizationSettings()

    public var activeProviderDisplayName: String {
        preferredProvider.displayName
    }

    public func normalized() -> TextOrganizationSettings {
        TextOrganizationSettings(
            isEnabled: isEnabled,
            preferredProvider: preferredProvider,
            ollamaConfiguration: ollamaConfiguration.normalized(),
            openAICompatibleConfiguration: openAICompatibleConfiguration.normalized(),
            options: options
        )
    }

    public func validationErrors() -> [TextOrganizationValidationError] {
        guard isEnabled else { return [] }
        let normalized = normalized()
        switch normalized.preferredProvider {
        case .ollama:
            return normalized.ollamaConfiguration.validationErrors(isEnabled: true)
        case .openAICompatible:
            return normalized.openAICompatibleConfiguration.validationErrors(isEnabled: true).map { error in
                switch error {
                case .missingBaseURL:
                    return .missingOpenAIBaseURL
                case .missingModel:
                    return .missingOpenAIModel
                }
            }
        }
    }

    public static func fromLegacy(
        isEnabled: Bool,
        openAICompatibleConfiguration: LLMConfiguration
    ) -> TextOrganizationSettings {
        let normalizedConfiguration = openAICompatibleConfiguration.normalized()
        return TextOrganizationSettings(
            isEnabled: isEnabled,
            preferredProvider: normalizedConfiguration.isConfigured || isEnabled ? .openAICompatible : .ollama,
            ollamaConfiguration: .recommendedDefault,
            openAICompatibleConfiguration: normalizedConfiguration,
            options: .default
        )
    }
}
