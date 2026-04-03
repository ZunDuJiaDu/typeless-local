import AppKit
import Foundation

@MainActor
public final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let settingsStore: SettingsStore
    private let permissionCoordinator: PermissionCoordinator
    private let settingsWindowController: SettingsWindowController
    private let sessionCoordinator: DictationSessionCoordinator

    private var statusMessage = "Ready"

    public init(
        settingsStore: SettingsStore,
        permissionCoordinator: PermissionCoordinator,
        settingsWindowController: SettingsWindowController,
        sessionCoordinator: DictationSessionCoordinator
    ) {
        self.settingsStore = settingsStore
        self.permissionCoordinator = permissionCoordinator
        self.settingsWindowController = settingsWindowController
        self.sessionCoordinator = sessionCoordinator
        super.init()
        configureButton()
        rebuildMenu()
    }

    public func updateStatus(_ text: String) {
        statusMessage = text
        rebuildMenu()
    }

    private func configureButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "WuZi")
            button.imagePosition = .imageOnly
            button.toolTip = "WuZi"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let status = NSMenuItem(title: "Status: \(statusMessage)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let languageMenuItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for locale in RecognitionLocale.allCases {
            let item = NSMenuItem(title: locale.menuTitle, action: #selector(selectLocale(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = locale.rawValue
            item.state = settingsStore.selectedLocale == locale ? .on : .off
            languageMenu.addItem(item)
        }
        menu.setSubmenu(languageMenu, for: languageMenuItem)
        menu.addItem(languageMenuItem)

        let llmMenuItem = NSMenuItem(title: "Text Organization", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()
        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleLLM(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = settingsStore.isLLMRefinementEnabled ? .on : .off
        llmMenu.addItem(toggle)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)
        menu.setSubmenu(llmMenu, for: llmMenuItem)
        menu.addItem(llmMenuItem)

        let permissionMenuItem = NSMenuItem(title: permissionSummary(), action: #selector(promptPermissions), keyEquivalent: "")
        permissionMenuItem.target = self
        menu.addItem(permissionMenuItem)

        let startStopTitle = sessionCoordinator.isRecording ? "Stop Recording" : "Start Recording"
        let startStop = NSMenuItem(title: startStopTitle, action: #selector(toggleRecording), keyEquivalent: "")
        startStop.target = self
        menu.addItem(startStop)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit WuZi", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func permissionSummary() -> String {
        let snapshot = permissionCoordinator.snapshot()
        return "Permissions: Mic \(snapshot.microphone.rawValue), Speech \(snapshot.speech.rawValue), AX \(snapshot.accessibility.rawValue)"
    }

    @objc private func selectLocale(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let locale = RecognitionLocale(rawValue: raw)
        else { return }
        settingsStore.selectedLocale = locale
        rebuildMenu()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        settingsStore.isLLMRefinementEnabled.toggle()
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func promptPermissions() {
        permissionCoordinator.promptForAccessibilityIfNeeded()
        Task {
            _ = await permissionCoordinator.ensureReadyForRecording()
            self.rebuildMenu()
        }
    }

    @objc private func toggleRecording() {
        if sessionCoordinator.isRecording {
            Task { await sessionCoordinator.handleFnReleased() }
        } else {
            Task { await sessionCoordinator.handleFnPressed() }
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
