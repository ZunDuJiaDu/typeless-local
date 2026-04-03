import Foundation

public enum LLMConfigurationValidationError: Error, Equatable, Sendable {
    case missingBaseURL
    case missingModel
}

public struct LLMConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var apiKey: String
    public var model: String

    public init(baseURL: String, apiKey: String, model: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
    }

    public static let empty = LLMConfiguration(baseURL: "", apiKey: "", model: "")

    public var normalizedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isConfigured: Bool {
        !normalizedBaseURL.isEmpty && !normalizedModel.isEmpty
    }

    public func validationErrors(isEnabled: Bool) -> [LLMConfigurationValidationError] {
        guard isEnabled else { return [] }
        var errors: [LLMConfigurationValidationError] = []
        if normalizedBaseURL.isEmpty { errors.append(.missingBaseURL) }
        if normalizedModel.isEmpty { errors.append(.missingModel) }
        return errors
    }
}
