import Foundation

public struct InputSourceDescriptor: Equatable, Sendable {
    public var identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

public struct PasteboardItemSnapshot: Equatable, Sendable {
    public var valuesByType: [String: Data]

    public init(valuesByType: [String: Data]) {
        self.valuesByType = valuesByType
    }
}

public struct PasteboardSnapshot: Equatable, Sendable {
    public var items: [PasteboardItemSnapshot]

    public init(items: [PasteboardItemSnapshot]) {
        self.items = items
    }
}

@MainActor
public protocol PasteboardSnapshotting {
    func capture() async throws -> PasteboardSnapshot
    func set(string: String) async throws
    func restore(snapshot: PasteboardSnapshot) async throws
}

@MainActor
public protocol InputSourceManaging {
    func currentInputSource() async throws -> InputSourceDescriptor
    func selectASCIISourceIfNeeded(from source: InputSourceDescriptor) async throws -> Bool
    func restoreInputSource(_ source: InputSourceDescriptor) async throws
}

@MainActor
public protocol KeyboardPastePerforming {
    func performPaste() async throws
}

@MainActor
public final class TextInjectionService {
    private let pasteboardService: PasteboardSnapshotting
    private let inputSourceService: InputSourceManaging
    private let keyboardPastePerformer: KeyboardPastePerforming
    private let switchSettleDelayNanoseconds: UInt64

    public init(
        pasteboardService: PasteboardSnapshotting,
        inputSourceService: InputSourceManaging,
        keyboardPastePerformer: KeyboardPastePerforming,
        switchSettleDelayNanoseconds: UInt64 = 150_000_000
    ) {
        self.pasteboardService = pasteboardService
        self.inputSourceService = inputSourceService
        self.keyboardPastePerformer = keyboardPastePerformer
        self.switchSettleDelayNanoseconds = switchSettleDelayNanoseconds
    }

    public func inject(text: String) async throws {
        let snapshot = try await pasteboardService.capture()
        let currentSource = try await inputSourceService.currentInputSource()
        let switched = try await inputSourceService.selectASCIISourceIfNeeded(from: currentSource)

        var primaryError: Error?
        if switched {
            try? await Task.sleep(nanoseconds: switchSettleDelayNanoseconds)
        }

        do {
            try await pasteboardService.set(string: text)
            try await keyboardPastePerformer.performPaste()
        } catch {
            primaryError = error
        }

        var cleanupError: Error?
        if switched {
            do {
                try await inputSourceService.restoreInputSource(currentSource)
            } catch {
                cleanupError = cleanupError ?? error
            }
        }

        do {
            try await pasteboardService.restore(snapshot: snapshot)
        } catch {
            cleanupError = cleanupError ?? error
        }

        if let primaryError {
            throw primaryError
        }
        if let cleanupError {
            throw cleanupError
        }
    }
}
