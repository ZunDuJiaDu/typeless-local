import Testing
@testable import WuZi

private actor ProviderCallRecorder {
    private var providers: [TextOrganizationProviderKind] = []

    func record(_ provider: TextOrganizationProviderKind) {
        providers.append(provider)
    }

    func snapshot() -> [TextOrganizationProviderKind] {
        providers
    }
}

private final class SpyTextOrganizationProvider: @unchecked Sendable, TextOrganizationProvider {
    let kind: TextOrganizationProviderKind
    let result: String
    let recorder: ProviderCallRecorder

    init(kind: TextOrganizationProviderKind, result: String, recorder: ProviderCallRecorder) {
        self.kind = kind
        self.result = result
        self.recorder = recorder
    }

    func organize(text: String, settings: TextOrganizationSettings) async throws -> String {
        await recorder.record(kind)
        return result
    }

    func testConnection(settings: TextOrganizationSettings) async throws {
        await recorder.record(kind)
    }
}

struct TextOrganizationServiceTests {
    @Test func serviceRoutesToPreferredProvider() async {
        let recorder = ProviderCallRecorder()
        let service = TextOrganizationService(
            providers: [
                SpyTextOrganizationProvider(kind: .ollama, result: "organized by ollama", recorder: recorder),
                SpyTextOrganizationProvider(kind: .openAICompatible, result: "organized by openai", recorder: recorder)
            ]
        )

        let settings = TextOrganizationSettings(
            isEnabled: true,
            preferredProvider: .ollama,
            ollamaConfiguration: .init(host: "http://localhost:11434", model: "llama3.2")
        )

        let result = await service.organize(text: "raw", settings: settings)
        #expect(result == .organized("organized by ollama"))
        #expect(await recorder.snapshot() == [.ollama])
    }

    @Test func serviceSkipsInvalidPreferredProviderConfiguration() async {
        let recorder = ProviderCallRecorder()
        let service = TextOrganizationService(
            providers: [
                SpyTextOrganizationProvider(kind: .openAICompatible, result: "organized by openai", recorder: recorder)
            ]
        )

        let settings = TextOrganizationSettings(
            isEnabled: true,
            preferredProvider: .openAICompatible,
            openAICompatibleConfiguration: .empty
        )

        let result = await service.organize(text: "raw", settings: settings)
        #expect(result == .skipped("raw"))
        #expect(await recorder.snapshot().isEmpty)
    }
}
