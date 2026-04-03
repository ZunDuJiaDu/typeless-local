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
        case .refining: return "Refining"
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
    private let llmRefinementService: LLMRefinementService

    private var latestTranscript = ""
    private var finalizeTask: Task<Void, Never>?

    public init(
        settingsStore: SettingsStore,
        permissionCoordinator: PermissionCoordinator,
        fnKeyMonitor: FnKeyMonitor,
        audioCaptureEngine: AudioCaptureEngine,
        speechService: SpeechRecognitionService,
        overlayController: OverlayPanelController,
        textInjectionService: TextInjectionService,
        llmRefinementService: LLMRefinementService
    ) {
        self.settingsStore = settingsStore
        self.permissionCoordinator = permissionCoordinator
        self.fnKeyMonitor = fnKeyMonitor
        self.audioCaptureEngine = audioCaptureEngine
        self.speechService = speechService
        self.overlayController = overlayController
        self.textInjectionService = textInjectionService
        self.llmRefinementService = llmRefinementService
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
        state = .idle
    }

    public func handleFnPressed() async {
        guard state == .idle else { return }
        let permissions = await permissionCoordinator.ensureReadyForRecording()
        guard permissions.microphone == .granted, permissions.speech == .granted else {
            permissionCoordinator.promptForAccessibilityIfNeeded()
            onStatusChange?("Permissions needed")
            return
        }

        latestTranscript = ""
        state = reducer.reduce(state, event: .fnPressed)
        overlayController.show(text: "Listening…")

        do {
            try speechService.start(locale: settingsStore.selectedLocale)
            try audioCaptureEngine.start()
        } catch {
            AppLogger.audio.error("Failed to start recording: \(String(describing: error), privacy: .public)")
            state = reducer.reduce(state, event: .failureOccurred)
            overlayController.hide()
        }
    }

    public func handleFnReleased() async {
        guard state == .recording else { return }
        state = reducer.reduce(state, event: .fnReleased)
        audioCaptureEngine.stop()
        speechService.finish()
        finalizeTask?.cancel()
        let fallbackTranscript = latestTranscript
        finalizeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, self.state == .finalizingASR else { return }
            await self.completeSession(with: fallbackTranscript)
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
                if self.state == .recording {
                    self.overlayController.update(text: text, level: 0.2)
                }
            }
        }

        speechService.onFinalResult = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.latestTranscript = text
                await self.completeSession(with: text)
            }
        }

        speechService.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppLogger.speech.error("Speech error: \(String(describing: error), privacy: .public)")
                if self.state == .finalizingASR, !self.latestTranscript.isEmpty {
                    await self.completeSession(with: self.latestTranscript)
                } else {
                    self.state = self.reducer.reduce(self.state, event: .failureOccurred)
                    self.overlayController.hide()
                }
            }
        }
    }

    private func completeSession(with rawTranscript: String) async {
        finalizeTask?.cancel()
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            state = .idle
            overlayController.hide()
            return
        }

        var finalTranscript = transcript
        if settingsStore.isLLMRefinementEnabled, settingsStore.llmConfiguration.isConfigured {
            state = reducer.reduce(state, event: .refinementStarted)
            overlayController.showRefining()
            switch await llmRefinementService.refine(
                transcript: transcript,
                configuration: settingsStore.llmConfiguration,
                isEnabled: settingsStore.isLLMRefinementEnabled
            ) {
            case .refined(let refined):
                finalTranscript = refined
                state = reducer.reduce(state, event: .refinementFinished)
            case .skipped(let skipped):
                finalTranscript = skipped
                state = reducer.reduce(state, event: .refinementFailed)
            }
        } else {
            state = reducer.reduce(state, event: .finalTranscriptReady)
        }

        do {
            state = .injecting
            try await textInjectionService.inject(text: finalTranscript)
            state = .recovering
            overlayController.hide()
            state = reducer.reduce(state, event: .recoveryFinished)
        } catch {
            AppLogger.injection.error("Injection failed: \(String(describing: error), privacy: .public)")
            state = reducer.reduce(state, event: .failureOccurred)
            overlayController.hide()
            state = .idle
        }
    }
}
