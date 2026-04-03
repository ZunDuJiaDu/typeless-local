import Foundation

public protocol TextOrganizationProvider: Sendable {
    var kind: TextOrganizationProviderKind { get }
    func organize(text: String, settings: TextOrganizationSettings) async throws -> String
    func testConnection(settings: TextOrganizationSettings) async throws
}

public final class OllamaOrganizationProvider: @unchecked Sendable, TextOrganizationProvider {
    public let kind: TextOrganizationProviderKind = .ollama

    private let client: OllamaClient

    public init(client: OllamaClient = OllamaClient()) {
        self.client = client
    }

    public func organize(text: String, settings: TextOrganizationSettings) async throws -> String {
        let normalized = settings.normalized()
        return try await client.organize(
            text: text,
            configuration: normalized.ollamaConfiguration,
            options: normalized.options
        )
    }

    public func testConnection(settings: TextOrganizationSettings) async throws {
        let normalized = settings.normalized()
        try await client.test(
            configuration: normalized.ollamaConfiguration,
            options: normalized.options
        )
    }
}

public final class OpenAICompatibleOrganizationProvider: @unchecked Sendable, TextOrganizationProvider {
    public let kind: TextOrganizationProviderKind = .openAICompatible

    private let client: OpenAICompatibleClient

    public init(client: OpenAICompatibleClient = OpenAICompatibleClient()) {
        self.client = client
    }

    public func organize(text: String, settings: TextOrganizationSettings) async throws -> String {
        let normalized = settings.normalized()
        return try await client.organize(
            text: text,
            configuration: normalized.openAICompatibleConfiguration,
            options: normalized.options
        )
    }

    public func testConnection(settings: TextOrganizationSettings) async throws {
        let normalized = settings.normalized()
        try await client.test(
            configuration: normalized.openAICompatibleConfiguration,
            options: normalized.options
        )
    }
}
