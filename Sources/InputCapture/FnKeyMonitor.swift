import CoreGraphics
import Foundation

public final class FnKeyMonitor {
    public var onEvent: ((FnSemanticEvent) -> Void)?

    private let interpreter = FnEventInterpreter()
    private lazy var tapManager = CGEventTapManager(
        eventMask: CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    ) { [weak self] type, event in
        guard let self else { return Unmanaged.passUnretained(event) }
        let outcome = self.interpreter.interpret(event: event, type: type)
        if let semanticEvent = outcome.event {
            switch semanticEvent {
            case .pressed:
                AppLogger.inputTap.debug("Suppressed Fn press event and started recording path")
            case .released:
                AppLogger.inputTap.debug("Suppressed Fn release event and started finalization path")
            }
            self.onEvent?(semanticEvent)
        } else if outcome.shouldSuppress {
            AppLogger.inputTap.debug("Suppressed duplicate Fn-only flagsChanged event to avoid emoji picker handoff")
        }
        return outcome.shouldSuppress ? nil : Unmanaged.passUnretained(event)
    }

    public init() {}

    public func start() throws {
        interpreter.reset()
        tapManager.onDiagnostic = { [weak self] diagnostic in
            guard let self else { return }
            switch diagnostic {
            case .started:
                AppLogger.inputTap.info("Fn event tap started")
            case .interrupted(let reason):
                self.interpreter.markStateUnknown()
                AppLogger.inputTap.error("Fn event tap interrupted: \(reason.rawValue, privacy: .public)")
            case .reenabled(let reason):
                AppLogger.inputTap.info("Fn event tap re-enabled after \(reason.rawValue, privacy: .public) interruption")
            case .stopped:
                self.interpreter.reset()
                AppLogger.inputTap.info("Fn event tap stopped")
            }
        }
        try tapManager.start()
    }

    public func stop() {
        interpreter.reset()
        tapManager.stop()
    }
}
