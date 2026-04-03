import CoreGraphics
import Foundation

public enum CGEventTapManagerError: Error {
    case creationFailed
}

public enum CGEventTapInterruptionReason: String, Equatable {
    case timeout
    case userInput
}

public enum CGEventTapDiagnostic: Equatable {
    case started
    case interrupted(CGEventTapInterruptionReason)
    case reenabled(CGEventTapInterruptionReason)
    case stopped
}

public final class CGEventTapManager {
    public typealias Handler = (CGEventType, CGEvent) -> Unmanaged<CGEvent>?

    private let eventMask: CGEventMask
    private let handler: Handler
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public var onDiagnostic: ((CGEventTapDiagnostic) -> Void)?

    public init(eventMask: CGEventMask, handler: @escaping Handler) {
        self.eventMask = eventMask
        self.handler = handler
    }

    deinit {
        stop()
    }

    public func start() throws {
        guard machPort == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<CGEventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                manager.handleInterruption(type: type)
                return Unmanaged.passUnretained(event)
            }
            return manager.handler(type, event)
        }

        guard let machPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw CGEventTapManagerError.creationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: machPort, enable: true)
        self.machPort = machPort
        self.runLoopSource = source
        onDiagnostic?(.started)
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let machPort = machPort {
            CGEvent.tapEnable(tap: machPort, enable: false)
        }
        runLoopSource = nil
        machPort = nil
        onDiagnostic?(.stopped)
    }

    private func handleInterruption(type: CGEventType) {
        guard let reason = interruptionReason(for: type) else { return }
        onDiagnostic?(.interrupted(reason))
        if let port = machPort {
            CGEvent.tapEnable(tap: port, enable: true)
            onDiagnostic?(.reenabled(reason))
        }
    }

    private func interruptionReason(for type: CGEventType) -> CGEventTapInterruptionReason? {
        switch type {
        case .tapDisabledByTimeout:
            .timeout
        case .tapDisabledByUserInput:
            .userInput
        default:
            nil
        }
    }
}
