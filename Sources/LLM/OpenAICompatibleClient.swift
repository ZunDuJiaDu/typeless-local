import Foundation

public struct OpenAIChatMessage: Codable, Sendable {
    public var role: String
    public var content: String
}

public struct OpenAIChatCompletionRequest: Codable, Sendable {
    public var model: String
    public var messages: [OpenAIChatMessage]
    public var temperature: Double
}

public struct OpenAIChatCompletionResponse: Codable, Sendable {
    public struct Choice: Codable, Sendable {
        public struct Message: Codable, Sendable {
            public var role: String
            public var content: String
        }
        public var message: Message
    }
    public var choices: [Choice]
}

public final class OpenAICompatibleClient: @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func organize(
        text: String,
        configuration: LLMConfiguration,
        options: TextOrganizationOptions
    ) async throws -> String {
        let endpoint = configuration.normalizedBaseURL.hasSuffix("/chat/completions")
            ? configuration.normalizedBaseURL
            : configuration.normalizedBaseURL + "/chat/completions"
        guard let url = URL(string: endpoint) else {
            return text
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        let payload = OpenAIChatCompletionRequest(
            model: configuration.normalizedModel,
            messages: [
                .init(role: "system", content: TextOrganizationPromptBuilder.systemPrompt(options: options)),
                .init(role: "user", content: TextOrganizationPromptBuilder.userPrompt(for: text))
            ],
            temperature: 0
        )
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        return response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? text
    }

    public func test(
        configuration: LLMConfiguration,
        options: TextOrganizationOptions = .default
    ) async throws {
        _ = try await organize(
            text: "请帮我整理这段包含 JSON 和 Python 的混合语音转录",
            configuration: configuration,
            options: options
        )
    }

    public func refine(transcript: String, configuration: LLMConfiguration) async throws -> String {
        try await organize(text: transcript, configuration: configuration, options: .default)
    }
}
