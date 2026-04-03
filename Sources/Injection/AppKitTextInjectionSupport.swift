import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

public enum SystemInputSourceError: Error {
    case missingCurrentSource
    case missingASCIISource
    case selectionFailed(OSStatus)
}

public final class SystemPasteboardService: PasteboardSnapshotting, @unchecked Sendable {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public func capture() async throws -> PasteboardSnapshot {
        await MainActor.run {
            let items = pasteboard.pasteboardItems?.map { item in
                PasteboardItemSnapshot(
                    valuesByType: Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                        guard let data = item.data(forType: type) else { return nil }
                        return (type.rawValue, data)
                    })
                )
            } ?? []
            return PasteboardSnapshot(items: items)
        }
    }

    public func set(string: String) async throws {
        await MainActor.run {
            pasteboard.clearContents()
            pasteboard.setString(string, forType: .string)
        }
    }

    public func restore(snapshot: PasteboardSnapshot) async throws {
        await MainActor.run {
            pasteboard.clearContents()
            guard !snapshot.items.isEmpty else { return }
            let restoredItems = snapshot.items.map { snapshot -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (rawType, data) in snapshot.valuesByType {
                    item.setData(data, forType: NSPasteboard.PasteboardType(rawType))
                }
                return item
            }
            pasteboard.writeObjects(restoredItems)
        }
    }
}

public final class SystemInputSourceService: InputSourceManaging, @unchecked Sendable {
    public init() {}

    public func currentInputSource() async throws -> InputSourceDescriptor {
        await MainActor.run {
            let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            return InputSourceDescriptor(identifier: Self.identifier(for: source))
        }
    }

    public func selectASCIISourceIfNeeded(from source: InputSourceDescriptor) async throws -> Bool {
        guard InputSourceClassifier.classify(identifier: source.identifier) == .cjk else { return false }
        return try await MainActor.run {
            let list = TISCreateASCIICapableInputSourceList().takeRetainedValue() as NSArray
            guard let ascii = list.firstObject else {
                throw SystemInputSourceError.missingASCIISource
            }
            let status = TISSelectInputSource(unsafeBitCast(ascii, to: TISInputSource.self))
            guard status == noErr else {
                throw SystemInputSourceError.selectionFailed(status)
            }
            return true
        }
    }

    public func restoreInputSource(_ source: InputSourceDescriptor) async throws {
        try await MainActor.run {
            let properties = [kTISPropertyInputSourceID as String: source.identifier] as CFDictionary
            let rawList = TISCreateInputSourceList(properties, false).takeRetainedValue() as NSArray
            guard let match = rawList.firstObject else { return }
            let status = TISSelectInputSource(unsafeBitCast(match, to: TISInputSource.self))
            guard status == noErr else {
                throw SystemInputSourceError.selectionFailed(status)
            }
        }
    }

    private static func identifier(for source: TISInputSource) -> String {
        guard let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return ""
        }
        return Unmanaged<CFString>.fromOpaque(property).takeUnretainedValue() as String
    }
}

public final class SystemKeyboardPastePerformer: KeyboardPastePerforming, @unchecked Sendable {
    public init() {}

    public func performPaste() async throws {
        await MainActor.run {
            let source = CGEventSource(stateID: .hidSystemState)
            let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
            commandDown?.flags = .maskCommand
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            vDown?.flags = .maskCommand
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            vUp?.flags = .maskCommand
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

            commandDown?.post(tap: .cgSessionEventTap)
            vDown?.post(tap: .cgSessionEventTap)
            vUp?.post(tap: .cgSessionEventTap)
            commandUp?.post(tap: .cgSessionEventTap)
        }
    }
}
