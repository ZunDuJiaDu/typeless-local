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
            AppLogger.inputTap.error("Failed to start Fn monitor: \(String(describing: error), privacy: .public)")
            environment.statusItemController.updateStatus("Fn monitor unavailable")
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        environment?.sessionCoordinator.stop()
    }
}
