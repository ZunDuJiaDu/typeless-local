import AppKit
import Foundation

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let environment = AppEnvironment()
        self.environment = environment
        do {
            try environment.sessionCoordinator.start()
        } catch {
            let permissions = environment.permissionCoordinator.snapshot()
            AppLogger.inputTap.error(
                "Failed to start Fn monitor: \(String(describing: error), privacy: .public) | mic=\(permissions.microphone.rawValue, privacy: .public) speech=\(permissions.speech.rawValue, privacy: .public) ax=\(permissions.accessibility.rawValue, privacy: .public)"
            )
            let fallbackStatus = permissions.accessibility == .granted
                ? "Fn monitor unavailable"
                : "Enable Accessibility for Fn"
            environment.statusItemController.updateStatus(fallbackStatus)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        environment?.sessionCoordinator.stop()
    }
}
