import Foundation

@MainActor
public final class AppEnvironment {
    public let settingsStore: SettingsStore
    public let permissionCoordinator: PermissionCoordinator
    public let settingsWindowController: SettingsWindowController
    public let statusItemController: StatusItemController
    public let sessionCoordinator: DictationSessionCoordinator

    public init() {
        let settingsStore = SettingsStore()
        let permissionCoordinator = PermissionCoordinator()
        let overlayController = OverlayPanelController()
        let textInjectionService = TextInjectionService(
            pasteboardService: SystemPasteboardService(),
            inputSourceService: SystemInputSourceService(),
            keyboardPastePerformer: SystemKeyboardPastePerformer()
        )
        let textOrganizationService = TextOrganizationService()
        let sessionCoordinator = DictationSessionCoordinator(
            settingsStore: settingsStore,
            permissionCoordinator: permissionCoordinator,
            fnKeyMonitor: FnKeyMonitor(),
            audioCaptureEngine: AudioCaptureEngine(),
            speechService: SpeechRecognitionService(),
            overlayController: overlayController,
            textInjectionService: textInjectionService,
            textOrganizationService: textOrganizationService
        )
        let settingsWindowController = SettingsWindowController(
            settingsStore: settingsStore,
            textOrganizationService: textOrganizationService
        )
        let statusItemController = StatusItemController(
            settingsStore: settingsStore,
            permissionCoordinator: permissionCoordinator,
            settingsWindowController: settingsWindowController,
            sessionCoordinator: sessionCoordinator
        )

        self.settingsStore = settingsStore
        self.permissionCoordinator = permissionCoordinator
        self.settingsWindowController = settingsWindowController
        self.statusItemController = statusItemController
        self.sessionCoordinator = sessionCoordinator

        self.sessionCoordinator.onStatusChange = { [weak statusItemController] text in
            statusItemController?.updateStatus(text)
        }
    }
}
