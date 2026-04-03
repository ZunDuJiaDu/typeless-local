import Foundation

public enum LLMRefinementResult: Equatable, Sendable {
    case refined(String)
    case skipped(String)
}

public final class LLMRefinementService: @unchecked Sendable {
    private let client: OpenAICompatibleClient

    public init(client: OpenAICompatibleClient = OpenAICompatibleClient()) {
        self.client = client
    }

    public func refine(
        transcript: String,
        configuration: LLMConfiguration,
        isEnabled: Bool,
        timeoutNanoseconds: UInt64 = 3_000_000_000
    ) async -> LLMRefinementResult {
        guard isEnabled, configuration.validationErrors(isEnabled: true).isEmpty else {
            return .skipped(transcript)
        }

        do {
            let refined = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await self.client.refine(transcript: transcript, configuration: configuration)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutNanoseconds)
                    throw CancellationError()
                }
                let result = try await group.next() ?? transcript
                group.cancelAll()
                return result
            }
            return .refined(refined.isEmpty ? transcript : refined)
        } catch {
            return .skipped(transcript)
        }
    }

    public func testConnection(configuration: LLMConfiguration) async throws {
        try await client.test(configuration: configuration)
    }
}
