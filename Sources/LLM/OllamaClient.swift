import Foundation

public struct OllamaChatMessage: Codable, Sendable {
    public var role: String
    public var content: String
}

public struct OllamaChatRequest: Codable, Sendable {
    public struct Options: Codable, Sendable {
        public var temperature: Double
    }

    public var model: String
    public var messages: [OllamaChatMessage]
    public var stream: Bool
    public var options: Options
}

public struct OllamaChatResponse: Codable, Sendable {
    public struct Message: Codable, Sendable {
        public var role: String
        public var content: String
    }

    public var message: Message
}

public final class OllamaClient: @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func organize(
        text: String,
        configuration: OllamaConfiguration,
        options: TextOrganizationOptions
    ) async throws -> String {
        let endpoint = configuration.normalizedHost.hasSuffix("/api/chat")
            ? configuration.normalizedHost
            : configuration.normalizedHost + "/api/chat"
        guard let url = URL(string: endpoint) else {
            return text
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = OllamaChatRequest(
            model: configuration.normalizedModel,
            messages: [
                .init(role: "system", content: TextOrganizationPromptBuilder.systemPrompt(options: options)),
                .init(role: "user", content: TextOrganizationPromptBuilder.userPrompt(for: text))
            ],
            stream: false,
            options: .init(temperature: 0)
        )

        request.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return response.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func test(
        configuration: OllamaConfiguration,
        options: TextOrganizationOptions
    ) async throws {
        _ = try await organize(
            text: "请帮我整理这段包含 JSON 和 Python 的混合语音转录",
            configuration: configuration,
            options: options
        )
    }
}
