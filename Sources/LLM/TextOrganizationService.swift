import Foundation

public enum TextOrganizationResult: Equatable, Sendable {
    case organized(String)
    case skipped(String)
}

public enum TextOrganizationServiceError: LocalizedError, Equatable, Sendable {
    case invalidConfiguration([TextOrganizationValidationError])
    case providerUnavailable(TextOrganizationProviderKind)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let errors):
            return errors.map(\.debugDescription).joined(separator: ", ") + " is required."
        case .providerUnavailable(let provider):
            return "Provider unavailable: \(provider.displayName)"
        }
    }
}

public final class TextOrganizationService: @unchecked Sendable {
    private let providers: [TextOrganizationProviderKind: any TextOrganizationProvider]

    public init(
        providers: [any TextOrganizationProvider] = [
            OllamaOrganizationProvider(),
            OpenAICompatibleOrganizationProvider()
        ]
    ) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.kind, $0) })
    }

    public func organize(
        text: String,
        settings: TextOrganizationSettings,
        timeoutNanoseconds: UInt64 = 3_000_000_000
    ) async -> TextOrganizationResult {
        let normalized = settings.normalized()
        guard normalized.isEnabled else {
            return .skipped(text)
        }

        let validationErrors = normalized.validationErrors()
        guard validationErrors.isEmpty else {
            return .skipped(text)
        }

        guard let provider = providers[normalized.preferredProvider] else {
            return .skipped(text)
        }

        do {
            let organized = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await provider.organize(text: text, settings: normalized)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw CancellationError()
                }
                let result = try await group.next() ?? text
                group.cancelAll()
                return result
            }
            return .organized(organized.isEmpty ? text : organized)
        } catch {
            return .skipped(text)
        }
    }

    public func testConnection(settings: TextOrganizationSettings) async throws {
        let normalized = settings.normalized()
        let validationErrors = normalized.validationErrors()
        guard validationErrors.isEmpty else {
            throw TextOrganizationServiceError.invalidConfiguration(validationErrors)
        }

        guard let provider = providers[normalized.preferredProvider] else {
            throw TextOrganizationServiceError.providerUnavailable(normalized.preferredProvider)
        }

        try await provider.testConnection(settings: normalized)
    }
}
