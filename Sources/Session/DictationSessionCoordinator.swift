import Foundation

@MainActor
public final class DictationSessionCoordinator {
    public var onStatusChange: ((String) -> Void)?

    public private(set) var state: DictationSessionState = .idle {
        didSet { onStatusChange?(statusText) }
    }

    public var isRecording: Bool { state == .recording }
    public var statusText: String {
        switch state {
        case .idle: return "Ready"
        case .recording: return "Recording"
        case .finalizingASR: return "Finalizing"
        case .refining: return "Organizing"
        case .injecting: return "Injecting"
        case .recovering: return "Recovering"
        case .failed: return "Error"
        }
    }

    private let reducer = DictationSessionReducer()
    private let settingsStore: SettingsStore
    private let permissionCoordinator: PermissionCoordinator
    private let fnKeyMonitor: FnKeyMonitor
    private let audioCaptureEngine: AudioCaptureEngine
    private let speechService: SpeechRecognitionService
    private let overlayController: OverlayPanelController
    private let textInjectionService: TextInjectionService
    private let textOrganizationService: TextOrganizationService

    private struct SessionDiagnostics {
        var id: String
        var startedAt: Date
        var releasedAt: Date?
        var firstPartialAt: Date?
    }

    private var latestTranscript = ""
    private var finalizeTask: Task<Void, Never>?
    private var sessionDiagnostics: SessionDiagnostics?

    public init(
        settingsStore: SettingsStore,
        permissionCoordinator: PermissionCoordinator,
        fnKeyMonitor: FnKeyMonitor,
        audioCaptureEngine: AudioCaptureEngine,
        speechService: SpeechRecognitionService,
        overlayController: OverlayPanelController,
        textInjectionService: TextInjectionService,
        textOrganizationService: TextOrganizationService
    ) {
        self.settingsStore = settingsStore
        self.permissionCoordinator = permissionCoordinator
        self.fnKeyMonitor = fnKeyMonitor
        self.audioCaptureEngine = audioCaptureEngine
        self.speechService = speechService
        self.overlayController = overlayController
        self.textInjectionService = textInjectionService
        self.textOrganizationService = textOrganizationService
        wireCallbacks()
    }

    public func start() throws {
        try fnKeyMonitor.start()
    }

    public func stop() {
        fnKeyMonitor.stop()
        audioCaptureEngine.stop()
        speechService.cancel()
        overlayController.hide()
        finalizeTask?.cancel()
        finalizeTask = nil
        sessionDiagnostics = nil
        state = .idle
    }

    public func handleFnPressed() async {
        guard state == .idle else { return }
        let permissions = await permissionCoordinator.ensureReadyForRecording()
        guard permissions.isReadyForDictation else {
            if permissions.accessibility != .granted {
                permissionCoordinator.promptForAccessibilityIfNeeded()
            }
            AppLogger.permissions.notice("Dictation blocked: \(permissions.summaryText, privacy: .public)")
            overlayController.showTransient(text: permissions.shortPrompt)
            onStatusChange?(permissions.shortPrompt)
            return
        }

        let sessionID = beginSessionDiagnostics()
        latestTranscript = ""
        state = reducer.reduce(state, event: .fnPressed)
        AppLogger.speech.info("Session \(sessionID, privacy: .public) started locale=\(self.settingsStore.selectedLocale.rawValue, privacy: .public)")
        overlayController.show(text: "Listening…")

        do {
            try speechService.start(locale: settingsStore.selectedLocale)
            try audioCaptureEngine.start()
        } catch {
            AppLogger.audio.error("Session \(sessionID, privacy: .public) failed to start recording: \(String(describing: error), privacy: .public)")
            state = reducer.reduce(state, event: .failureOccurred)
            overlayController.showTransient(text: "Recording unavailable")
            resetSessionDiagnostics()
        }
    }

    public func handleFnReleased() async {
        guard state == .recording else { return }
        markSessionReleased()
        if let sessionID = sessionDiagnostics?.id, let heldDuration = elapsedSinceSessionStartMilliseconds() {
            AppLogger.audio.info("Session \(sessionID, privacy: .public) released after \(heldDuration, privacy: .public)ms")
        }
        state = reducer.reduce(state, event: .fnReleased)
        audioCaptureEngine.stop()
        speechService.finish()
        finalizeTask?.cancel()
        finalizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self, self.state == .finalizingASR else { return }
            await self.completeSession(with: self.latestTranscript)
        }
    }

    private func wireCallbacks() {
        fnKeyMonitor.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                switch event {
                case .pressed:
                    await self?.handleFnPressed()
                case .released:
                    await self?.handleFnReleased()
                }
            }
        }

        audioCaptureEngine.onLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                self.overlayController.update(text: self.latestTranscript.isEmpty ? "Listening…" : self.latestTranscript, level: level)
            }
        }

        audioCaptureEngine.onBuffer = { [weak self] buffer in
            self?.speechService.append(buffer: buffer)
        }

        speechService.onPartialResult = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestTranscript = text
                self.logFirstPartialIfNeeded(textCount: text.count)
                if self.state == .recording || self.state == .finalizingASR {
                    self.overlayController.update(text: text, level: self.state == .recording ? 0.2 : 0.12)
                }
            }
        }

        speechService.onFinalResult = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestTranscript = text
                if let sessionID = self.sessionDiagnostics?.id {
                    AppLogger.speech.info("Session \(sessionID, privacy: .public) final transcript length=\(text.count, privacy: .public)")
                }
                await self.completeSession(with: text)
            }
        }

        speechService.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let sessionID = self.sessionDiagnostics?.id ?? "n/a"
                AppLogger.speech.error("Session \(sessionID, privacy: .public) speech error: \(String(describing: error), privacy: .public)")
                if self.state == .finalizingASR, !self.latestTranscript.isEmpty {
                    await self.completeSession(with: self.latestTranscript)
                } else {
                    self.state = self.reducer.reduce(self.state, event: .failureOccurred)
                    self.overlayController.showTransient(text: "Speech unavailable")
                    self.resetSessionDiagnostics()
                }
            }
        }
    }

    private func completeSession(with rawTranscript: String) async {
        finalizeTask?.cancel()
        finalizeTask = nil
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionID = sessionDiagnostics?.id ?? "n/a"
        guard !transcript.isEmpty else {
            AppLogger.speech.notice("Session \(sessionID, privacy: .public) finished without transcript")
            state = .idle
            overlayController.showTransient(text: "No speech detected")
            resetSessionDiagnostics()
            return
        }

        var finalTranscript = transcript
        let organizationSettings = settingsStore.textOrganizationSettings
        if organizationSettings.isEnabled, organizationSettings.validationErrors().isEmpty {
            let organizationStartedAt = Date()
            state = reducer.reduce(state, event: .refinementStarted)
            overlayController.showRefining()
            AppLogger.llm.info(
                "Session \(sessionID, privacy: .public) organization started provider=\(organizationSettings.activeProviderDisplayName, privacy: .public) chars=\(transcript.count, privacy: .public)"
            )
            switch await textOrganizationService.organize(
                text: transcript,
                settings: organizationSettings
            ) {
            case .organized(let organized):
                finalTranscript = organized
                state = reducer.reduce(state, event: .refinementFinished)
                AppLogger.llm.info(
                    "Session \(sessionID, privacy: .public) organization finished in \(self.milliseconds(since: organizationStartedAt), privacy: .public)ms"
                )
            case .skipped(let skipped):
                finalTranscript = skipped
                state = reducer.reduce(state, event: .refinementFailed)
                AppLogger.llm.notice(
                    "Session \(sessionID, privacy: .public) organization fell back after \(self.milliseconds(since: organizationStartedAt), privacy: .public)ms"
                )
            }
        } else {
            state = reducer.reduce(state, event: .finalTranscriptReady)
        }

        do {
            state = .injecting
            if let releaseToInjection = elapsedSinceReleaseMilliseconds() {
                AppLogger.injection.info("Session \(sessionID, privacy: .public) release-to-injection=\(releaseToInjection, privacy: .public)ms")
            }
            AppLogger.injection.info("Session \(sessionID, privacy: .public) injecting chars=\(finalTranscript.count, privacy: .public)")
            try await textInjectionService.inject(text: finalTranscript)
            state = .recovering
            overlayController.hide()
            state = reducer.reduce(state, event: .recoveryFinished)
            AppLogger.injection.info("Session \(sessionID, privacy: .public) injection completed")
            resetSessionDiagnostics()
        } catch {
            AppLogger.injection.error("Session \(sessionID, privacy: .public) injection failed: \(String(describing: error), privacy: .public)")
            state = reducer.reduce(state, event: .failureOccurred)
            overlayController.showTransient(text: "Couldn't paste text")
            state = .idle
            resetSessionDiagnostics()
        }
    }

    private func beginSessionDiagnostics() -> String {
        let diagnostics = SessionDiagnostics(
            id: UUID().uuidString.prefix(8).description,
            startedAt: Date(),
            releasedAt: nil,
            firstPartialAt: nil
        )
        sessionDiagnostics = diagnostics
        return diagnostics.id
    }

    private func markSessionReleased() {
        guard var diagnostics = sessionDiagnostics else { return }
        diagnostics.releasedAt = Date()
        sessionDiagnostics = diagnostics
    }

    private func logFirstPartialIfNeeded(textCount: Int) {
        guard var diagnostics = sessionDiagnostics, diagnostics.firstPartialAt == nil else { return }
        diagnostics.firstPartialAt = Date()
        sessionDiagnostics = diagnostics
        let latency = milliseconds(since: diagnostics.startedAt)
        AppLogger.speech.info("Session \(diagnostics.id, privacy: .public) first partial after \(latency, privacy: .public)ms len=\(textCount, privacy: .public)")
    }

    private func elapsedSinceSessionStartMilliseconds() -> Int? {
        guard let startedAt = sessionDiagnostics?.startedAt else { return nil }
        return milliseconds(since: startedAt)
    }

    private func elapsedSinceReleaseMilliseconds() -> Int? {
        guard let releasedAt = sessionDiagnostics?.releasedAt else { return nil }
        return milliseconds(since: releasedAt)
    }

    private func milliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }

    private func resetSessionDiagnostics() {
        sessionDiagnostics = nil
    }
}
