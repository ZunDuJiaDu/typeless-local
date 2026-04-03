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

    private var appDisplayName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return "WuZi"
    }

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
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: appDisplayName)
            button.imagePosition = .imageOnly
            button.toolTip = appDisplayName
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: "Status: \(statusMessage)", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let openMainWindow = NSMenuItem(title: "Open \(appDisplayName)…", action: #selector(openSettings), keyEquivalent: ",")
        openMainWindow.target = self
        menu.addItem(openMainWindow)

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

        let organizationMenuItem = NSMenuItem(title: "Text Organization", action: nil, keyEquivalent: "")
        let organizationMenu = NSMenu()
        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleOrganization(_:)), keyEquivalent: "")
        toggle.target = self
        toggle.state = settingsStore.textOrganizationSettings.isEnabled ? .on : .off
        organizationMenu.addItem(toggle)
        let openWorkbench = NSMenuItem(title: "Open Test Organization", action: #selector(openTestOrganization), keyEquivalent: "")
        openWorkbench.target = self
        organizationMenu.addItem(openWorkbench)
        menu.setSubmenu(organizationMenu, for: organizationMenuItem)
        menu.addItem(organizationMenuItem)

        let permissionMenuItem = NSMenuItem(title: permissionSummary(), action: #selector(promptPermissions), keyEquivalent: "")
        permissionMenuItem.target = self
        menu.addItem(permissionMenuItem)

        let startStopTitle = sessionCoordinator.isRecording ? "Stop Recording" : "Start Recording"
        let startStop = NSMenuItem(title: startStopTitle, action: #selector(toggleRecording), keyEquivalent: "")
        startStop.target = self
        menu.addItem(startStop)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(appDisplayName)", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func permissionSummary() -> String {
        let snapshot = permissionCoordinator.snapshot()
        return "Permissions: Mic \(snapshot.microphone.rawValue), Speech \(snapshot.speech.rawValue), AX \(snapshot.accessibility.rawValue)"
    }

    @objc private func selectLocale(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let locale = RecognitionLocale(rawValue: raw) else { return }
        settingsStore.selectedLocale = locale
        rebuildMenu()
    }

    @objc private func toggleOrganization(_ sender: NSMenuItem) {
        var settings = settingsStore.textOrganizationSettings
        settings.isEnabled.toggle()
        settingsStore.textOrganizationSettings = settings
        rebuildMenu()
    }

    @objc private func openSettings() {
        settingsWindowController.showMainWindow()
    }

    @objc private func openTestOrganization() {
        settingsWindowController.showMainWindow(selecting: .testOrganization)
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
