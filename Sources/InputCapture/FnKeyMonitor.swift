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
            self.onEvent?(semanticEvent)
        }
        return outcome.shouldSuppress ? nil : Unmanaged.passUnretained(event)
    }

    public init() {}

    public func start() throws {
        try tapManager.start()
    }

    public func stop() {
        tapManager.stop()
    }
}
