import Foundation

public enum TestOrganizationOutcome: Equatable, Sendable {
    case organized
    case fallback
}

public struct TestOrganizationPreview: Equatable, Sendable {
    public var rawText: String
    public var organizedText: String
    public var outcome: TestOrganizationOutcome

    public init(rawText: String, organizedText: String, outcome: TestOrganizationOutcome) {
        self.rawText = rawText
        self.organizedText = organizedText
        self.outcome = outcome
    }
}

public enum TestOrganizationWorkbenchError: Error, Equatable, Sendable {
    case missingInput
    case invalidConfiguration([TextOrganizationValidationError])
}

extension TestOrganizationWorkbenchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingInput:
            return "Paste a raw transcript before running Test Organization."
        case .invalidConfiguration(let errors):
            let labels = errors.map(\.debugDescription)
            if labels.count == 1, let first = labels.first {
                return "\(first) is required to test organization."
            }
            return labels.joined(separator: ", ") + " are required to test organization."
        }
    }
}

public final class TestOrganizationWorkbench: @unchecked Sendable {
    public typealias Organizer = @Sendable (_ transcript: String, _ settings: TextOrganizationSettings) async -> TextOrganizationResult

    private let organizer: Organizer

    public init(organizer: @escaping Organizer) {
        self.organizer = organizer
    }

    public convenience init(textOrganizationService: TextOrganizationService = TextOrganizationService()) {
        self.init { transcript, settings in
            await textOrganizationService.organize(text: transcript, settings: settings)
        }
    }

    public func run(rawText: String, settings: TextOrganizationSettings) async throws -> TestOrganizationPreview {
        let normalizedRawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRawText.isEmpty else {
            throw TestOrganizationWorkbenchError.missingInput
        }

        let normalizedSettings = settings.normalized()
        let validationErrors = normalizedSettings.validationErrors()
        guard validationErrors.isEmpty else {
            throw TestOrganizationWorkbenchError.invalidConfiguration(validationErrors)
        }

        switch await organizer(normalizedRawText, normalizedSettings) {
        case .organized(let organizedText):
            return TestOrganizationPreview(
                rawText: normalizedRawText,
                organizedText: normalizeOutput(organizedText, fallback: normalizedRawText),
                outcome: .organized
            )
        case .skipped(let fallbackText):
            return TestOrganizationPreview(
                rawText: normalizedRawText,
                organizedText: normalizeOutput(fallbackText, fallback: normalizedRawText),
                outcome: .fallback
            )
        }
    }

    private func normalizeOutput(_ text: String, fallback: String) -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedText.isEmpty ? fallback : normalizedText
    }
}
