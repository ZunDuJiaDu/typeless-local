import AppKit
import Foundation

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let permissionCoordinator: PermissionCoordinator
    private let textOrganizationService: TextOrganizationService
    private let navigationModel = MainWindowNavigationModel()
    private let workbench: TestOrganizationWorkbench

    private let localePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let enableCheckbox = NSButton(checkboxWithTitle: "Enable text organization", target: nil, action: nil)
    private let providerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let ollamaHostField = NSTextField(string: "")
    private let ollamaModelField = NSTextField(string: "")
    private let strengthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let preserveToneCheckbox = NSButton(checkboxWithTitle: "Preserve original tone", target: nil, action: nil)
    private let preserveStructureCheckbox = NSButton(checkboxWithTitle: "Preserve structural intent", target: nil, action: nil)
    private let openAIBaseURLField = NSTextField(string: "")
    private let openAIAPIKeyField = NSSecureTextField(string: "")
    private let openAIModelField = NSTextField(string: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let permissionSummaryLabel = NSTextField(wrappingLabelWithString: "")
    private let permissionDetailsLabel = NSTextField(wrappingLabelWithString: "")
    private let microphoneStateLabel = NSTextField(labelWithString: "")
    private let speechStateLabel = NSTextField(labelWithString: "")
    private let accessibilityStateLabel = NSTextField(labelWithString: "")
    private let rawTextView = NSTextView(frame: .zero)
    private let organizedTextView = NSTextView(frame: .zero)
    private lazy var rawScrollView = makeScrollView(for: rawTextView)
    private lazy var organizedScrollView = makeScrollView(for: organizedTextView)
    private let testStatusLabel = NSTextField(labelWithString: "Paste a raw transcript, then run Test Organization.")
    private let contentContainer = NSView(frame: .zero)

    private var sidebarButtons: [MainWindowPage: NSButton] = [:]
    private var selectedPage: MainWindowPage

    private var appDisplayName: String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty { return displayName }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty { return bundleName }
        return "WuZi"
    }

    private static func resolveAppDisplayName() -> String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !displayName.isEmpty { return displayName }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, !bundleName.isEmpty { return bundleName }
        return "WuZi"
    }

    public init(
        settingsStore: SettingsStore,
        permissionCoordinator: PermissionCoordinator,
        textOrganizationService: TextOrganizationService
    ) {
        self.settingsStore = settingsStore
        self.permissionCoordinator = permissionCoordinator
        self.textOrganizationService = textOrganizationService
        self.workbench = TestOrganizationWorkbench(textOrganizationService: textOrganizationService)
        self.selectedPage = MainWindowNavigationModel().initialPage(hasCompletedWelcome: settingsStore.hasCompletedWelcome)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Self.resolveAppDisplayName()
        window.minSize = NSSize(width: 860, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        configureUI()
        loadFromSettings()
        display(page: selectedPage)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func showMainWindow(selecting page: MainWindowPage? = nil) {
        if let page { display(page: page) } else { display(page: selectedPage) }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }
        configureControls()

        let splitView = NSSplitView(frame: .zero)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarView = makeSidebarView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(sidebarView)
        splitView.addArrangedSubview(contentContainer)
        sidebarView.widthAnchor.constraint(equalToConstant: 240).isActive = true

        contentView.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: contentView.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func configureControls() {
        if localePopup.numberOfItems == 0 {
            RecognitionLocale.allCases.forEach {
                localePopup.addItem(withTitle: $0.menuTitle)
                localePopup.lastItem?.representedObject = $0.rawValue
            }
        }
        if providerPopup.numberOfItems == 0 {
            TextOrganizationProviderKind.allCases.forEach {
                providerPopup.addItem(withTitle: $0.displayName)
                providerPopup.lastItem?.representedObject = $0.rawValue
            }
        }
        if strengthPopup.numberOfItems == 0 {
            OrganizationStrength.allCases.forEach {
                strengthPopup.addItem(withTitle: $0.displayName)
                strengthPopup.lastItem?.representedObject = $0.rawValue
            }
        }
        localePopup.target = self
        localePopup.action = #selector(localeChanged)
        enableCheckbox.target = self
        enableCheckbox.action = #selector(handleFormToggles)
        providerPopup.target = self
        providerPopup.action = #selector(handleFormToggles)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0
        permissionSummaryLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        permissionDetailsLabel.textColor = .secondaryLabelColor
        permissionDetailsLabel.maximumNumberOfLines = 0
        permissionDetailsLabel.lineBreakMode = .byWordWrapping
        rawTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        organizedTextView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        organizedTextView.isEditable = false
        testStatusLabel.textColor = .secondaryLabelColor
        testStatusLabel.lineBreakMode = .byWordWrapping
        testStatusLabel.maximumNumberOfLines = 0
    }

    private func makeSidebarView() -> NSView {
        let sidebarView = NSView(frame: .zero)
        sidebarView.translatesAutoresizingMaskIntoConstraints = false
        sidebarView.wantsLayer = true
        sidebarView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: appDisplayName)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let subtitleLabel = NSTextField(wrappingLabelWithString: "Settings, onboarding, and testing live here while the menu bar stays optimized for quick capture.")
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        navigationModel.pages.forEach { page in
            let button = NSButton(title: page.title, target: self, action: #selector(selectPageFromSidebar(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(page.rawValue)
            button.setButtonType(.toggle)
            button.isBordered = false
            button.image = NSImage(systemSymbolName: page.systemImageName, accessibilityDescription: page.title)
            button.imagePosition = .imageLeading
            button.contentTintColor = .labelColor
            button.font = .systemFont(ofSize: 13, weight: .regular)
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 200).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            stack.addArrangedSubview(button)
            sidebarButtons[page] = button
        }

        sidebarView.addSubview(titleLabel)
        sidebarView.addSubview(subtitleLabel)
        sidebarView.addSubview(stack)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: sidebarView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: sidebarView.trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: sidebarView.topAnchor, constant: 20),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            stack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20)
        ])
        return sidebarView
    }

    private func loadFromSettings() {
        let settings = settingsStore.settings
        if let idx = RecognitionLocale.allCases.firstIndex(of: settings.selectedLocale) { localePopup.selectItem(at: idx) }
        let organizationSettings = settings.textOrganizationSettings.normalized()
        enableCheckbox.state = organizationSettings.isEnabled ? .on : .off
        if let idx = TextOrganizationProviderKind.allCases.firstIndex(of: organizationSettings.preferredProvider) { providerPopup.selectItem(at: idx) }
        if let idx = OrganizationStrength.allCases.firstIndex(of: organizationSettings.options.strength) { strengthPopup.selectItem(at: idx) }
        ollamaHostField.stringValue = organizationSettings.ollamaConfiguration.host
        ollamaModelField.stringValue = organizationSettings.ollamaConfiguration.model
        preserveToneCheckbox.state = organizationSettings.options.preserveTone ? .on : .off
        preserveStructureCheckbox.state = organizationSettings.options.preserveStructureIntent ? .on : .off
        openAIBaseURLField.stringValue = organizationSettings.openAICompatibleConfiguration.baseURL
        openAIAPIKeyField.stringValue = organizationSettings.openAICompatibleConfiguration.apiKey
        openAIModelField.stringValue = organizationSettings.openAICompatibleConfiguration.model
        refreshPermissionStatus()
        refreshSidebarSelection()
        syncOrganizationFormState()
    }

    private func display(page: MainWindowPage) {
        selectedPage = page
        if page != .welcome && !settingsStore.hasCompletedWelcome {
            settingsStore.hasCompletedWelcome = true
        }
        refreshPermissionStatus()
        refreshSidebarSelection()
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let pageView = makePageView(for: page)
        pageView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(pageView)
        NSLayoutConstraint.activate([
            pageView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            pageView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            pageView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }

    private func makePageView(for page: MainWindowPage) -> NSView {
        switch page {
        case .welcome: return makeWelcomePage()
        case .general: return makeGeneralPage()
        case .speechRecognition: return makeSpeechRecognitionPage()
        case .ollamaOrganization: return makeOrganizationPage()
        case .testOrganization: return makeTestOrganizationPage()
        case .injectionAndPaste: return makeInjectionPage()
        case .advanced: return makeAdvancedPage()
        case .about: return makeAboutPage()
        }
    }

    private func makeWelcomePage() -> NSView {
        makePageLayout(
            title: "Welcome",
            summary: "WuZi keeps dictation in the menu bar and exposes settings, onboarding, and testing here.",
            bodyViews: [
                makeWrappingLabel("Start by reviewing permissions, choosing your dictation language, and configuring text organization before replacing your current workflow."),
                makeWrappingLabel("• Use Speech Recognition to confirm microphone / speech / accessibility.\n• Use Ollama Organization to choose your preferred provider and model.\n• Use Test Organization to compare raw transcript vs organized output before enabling it in live dictation."),
                NSButton(title: "Continue to General", target: self, action: #selector(completeWelcome))
            ]
        )
    }

    private func makeGeneralPage() -> NSView {
        let label = NSTextField(labelWithString: "Language")
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        let grid = NSGridView(views: [[label, localePopup]])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        return makePageLayout(
            title: "General",
            summary: "Set the defaults you expect every time you trigger dictation from the menu bar.",
            bodyViews: [
                makeWrappingLabel("Choose the locale Apple Speech uses for live dictation. Changes save immediately."),
                grid,
                makeWrappingLabel("The Welcome page stays pinned in the sidebar so first-run help and troubleshooting are always one click away.")
            ]
        )
    }

    private func makeSpeechRecognitionPage() -> NSView {
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Microphone"), microphoneStateLabel],
            [NSTextField(labelWithString: "Speech Recognition"), speechStateLabel],
            [NSTextField(labelWithString: "Accessibility"), accessibilityStateLabel]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 18
        let button = NSButton(title: "Check Permissions", target: self, action: #selector(checkPermissions))
        return makePageLayout(
            title: "Speech Recognition",
            summary: "Review the live capture requirements before holding Fn to talk.",
            bodyViews: [permissionSummaryLabel, grid, permissionDetailsLabel, button]
        )
    }

    private func makeOrganizationPage() -> NSView {
        let labels = [
            "Primary Provider",
            "Ollama Host",
            "Ollama Model",
            "Organization Strength",
            "OpenAI-Compatible Base URL",
            "OpenAI-Compatible API Key",
            "OpenAI-Compatible Model"
        ].map {
            let label = NSTextField(labelWithString: $0)
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            return label
        }
        let testButton = NSButton(title: "Test Active Provider", target: self, action: #selector(testTextOrganization))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        let buttonRow = NSStackView(views: [testButton, saveButton])
        buttonRow.spacing = 12
        let grid = NSGridView(views: [
            [NSTextField(labelWithString: ""), enableCheckbox],
            [labels[0], providerPopup],
            [labels[1], ollamaHostField],
            [labels[2], ollamaModelField],
            [labels[3], strengthPopup],
            [NSTextField(labelWithString: ""), preserveToneCheckbox],
            [NSTextField(labelWithString: ""), preserveStructureCheckbox],
            [labels[4], openAIBaseURLField],
            [labels[5], openAIAPIKeyField],
            [labels[6], openAIModelField],
            [statusLabel, buttonRow]
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        return makePageLayout(
            title: "Ollama Organization",
            summary: "Apple Speech still performs STT. This section configures how WuZi organizes the transcript while preserving meaning and tone.",
            bodyViews: [
                makeWrappingLabel("Ollama is the primary path. OpenAI-compatible remains available as a secondary provider for parity and migration."),
                grid
            ]
        )
    }

    private func makeTestOrganizationPage() -> NSView {
        let rawLabel = NSTextField(labelWithString: "Raw Transcript")
        rawLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let organizedLabel = NSTextField(labelWithString: "Organized Output")
        organizedLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let comparisonGrid = NSGridView(views: [
            [rawLabel, organizedLabel],
            [rawScrollView, organizedScrollView]
        ])
        comparisonGrid.rowSpacing = 12
        comparisonGrid.columnSpacing = 16
        let runButton = NSButton(title: "Run Test Organization", target: self, action: #selector(runTestOrganization))
        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearTestOrganization))
        let buttons = NSStackView(views: [runButton, clearButton])
        buttons.spacing = 12
        return makePageLayout(
            title: "Test Organization",
            summary: "Compare a raw transcript against organized output using the currently selected provider and options.",
            bodyViews: [comparisonGrid, buttons, testStatusLabel]
        )
    }

    private func makeInjectionPage() -> NSView {
        makePageLayout(
            title: "Injection & Paste",
            summary: "Understand where paste injection works well and where it remains best effort.",
            bodyViews: [
                makeWrappingLabel("WuZi pastes the final transcript with the clipboard, may switch temporarily to ASCII, and tries to restore the original input source afterward."),
                makeWrappingLabel("• Standard text views are the best validation target.\n• Secure fields, terminals, and some sandboxed apps may reject synthetic paste events.\n• A failed target app should not poison the next recording attempt.")
            ]
        )
    }

    private func makeAdvancedPage() -> NSView {
        makePageLayout(
            title: "Advanced",
            summary: "Secondary-provider and diagnostics context live here while the main pages stay focused.",
            bodyViews: [
                makeWrappingLabel("Current provider: \(currentTextOrganizationSettings.activeProviderDisplayName). OpenAI-compatible remains supported for fallback and migration, but Ollama is the default-first path."),
                makeWrappingLabel("Use the menu bar plus Test Organization page for end-to-end checks before enabling text organization during live dictation.")
            ]
        )
    }

    private func makeAboutPage() -> NSView {
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "local"
        return makePageLayout(
            title: "About",
            summary: "Quick reference information about the current build and runtime expectations.",
            bodyViews: [
                makeWrappingLabel("WuZi is a macOS menu-bar dictation app with Apple Speech for STT and local/text-provider organization on top."),
                makeWrappingLabel("Version: \(version) (\(build))\nPlatform: macOS 14+")
            ]
        )
    }

    private func makePageLayout(title: String, summary: String, bodyViews: [NSView]) -> NSView {
        let pageView = NSView(frame: .zero)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        let summaryLabel = makeWrappingLabel(summary)
        let stack = NSStackView(views: [titleLabel, summaryLabel] + bodyViews)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        pageView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: pageView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: pageView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: pageView.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: pageView.bottomAnchor, constant: -28)
        ])
        return pageView
    }

    private func makeWrappingLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    private func makeScrollView(for textView: NSTextView) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.widthAnchor.constraint(equalToConstant: 360).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 300).isActive = true
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true
        return scrollView
    }

    private func refreshPermissionStatus() {
        let snapshot = permissionCoordinator.snapshot()
        permissionSummaryLabel.stringValue = snapshot.summaryText
        permissionSummaryLabel.textColor = snapshot.isReadyForDictation ? .systemGreen : .labelColor
        permissionDetailsLabel.stringValue = snapshot.troubleshootingText
        microphoneStateLabel.stringValue = snapshot.microphone.statusLabel
        speechStateLabel.stringValue = snapshot.speech.statusLabel
        accessibilityStateLabel.stringValue = snapshot.accessibility.statusLabel
    }

    private func refreshSidebarSelection() {
        for (page, button) in sidebarButtons {
            let selected = page == selectedPage
            button.state = selected ? .on : .off
            button.contentTintColor = selected ? .controlAccentColor : .labelColor
            button.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .regular)
            button.layer?.backgroundColor = selected ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor : NSColor.clear.cgColor
        }
    }

    private func syncOrganizationFormState() {
        let isEnabled = enableCheckbox.state == .on
        [providerPopup, ollamaHostField, ollamaModelField, strengthPopup, openAIBaseURLField, openAIAPIKeyField, openAIModelField].forEach { $0.isEnabled = isEnabled }
        preserveToneCheckbox.isEnabled = isEnabled
        preserveStructureCheckbox.isEnabled = isEnabled
    }

    private var currentTextOrganizationSettings: TextOrganizationSettings {
        TextOrganizationSettings(
            isEnabled: enableCheckbox.state == .on,
            preferredProvider: selectedProvider,
            ollamaConfiguration: OllamaConfiguration(host: ollamaHostField.stringValue, model: ollamaModelField.stringValue),
            openAICompatibleConfiguration: LLMConfiguration(baseURL: openAIBaseURLField.stringValue, apiKey: openAIAPIKeyField.stringValue, model: openAIModelField.stringValue),
            options: TextOrganizationOptions(
                strength: selectedStrength,
                preserveTone: preserveToneCheckbox.state == .on,
                preserveStructureIntent: preserveStructureCheckbox.state == .on
            )
        ).normalized()
    }

    private var selectedProvider: TextOrganizationProviderKind {
        guard let raw = providerPopup.selectedItem?.representedObject as? String,
              let provider = TextOrganizationProviderKind(rawValue: raw) else { return .ollama }
        return provider
    }

    private var selectedStrength: OrganizationStrength {
        guard let raw = strengthPopup.selectedItem?.representedObject as? String,
              let value = OrganizationStrength(rawValue: raw) else { return .balanced }
        return value
    }

    @objc private func selectPageFromSidebar(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let page = MainWindowPage(rawValue: raw) else { return }
        display(page: page)
    }

    @objc private func completeWelcome() {
        settingsStore.hasCompletedWelcome = true
        display(page: .general)
    }

    @objc private func localeChanged() {
        let locale = RecognitionLocale.allCases[max(localePopup.indexOfSelectedItem, 0)]
        settingsStore.selectedLocale = locale
    }

    @objc private func handleFormToggles() {
        syncOrganizationFormState()
    }

    @objc private func checkPermissions() {
        if permissionCoordinator.snapshot().accessibility != .granted {
            permissionCoordinator.promptForAccessibilityIfNeeded()
        }
        Task {
            _ = await permissionCoordinator.ensureReadyForRecording()
            await MainActor.run { self.refreshPermissionStatus() }
        }
    }

    @objc private func testTextOrganization() {
        let settings = currentTextOrganizationSettings
        let errors = settings.validationErrors()
        guard errors.isEmpty else {
            AppLogger.llm.notice("Skipped text organization test because the configuration is incomplete")
            setStatus(validationMessage(for: errors), isError: true)
            return
        }
        setStatus("Testing \(settings.activeProviderDisplayName)…", isError: false)
        Task {
            do {
                try await textOrganizationService.testConnection(settings: settings)
                await MainActor.run { self.setStatus("\(settings.activeProviderDisplayName) connection OK. Save to persist these values.", isError: false) }
            } catch {
                await MainActor.run { self.setStatus("Test failed: \(error.localizedDescription)", isError: true) }
            }
        }
    }

    @objc private func saveSettings() {
        let locale = RecognitionLocale.allCases[max(localePopup.indexOfSelectedItem, 0)]
        let settings = currentTextOrganizationSettings
        let errors = settings.validationErrors()
        guard errors.isEmpty else {
            setStatus(validationMessage(for: errors), isError: true)
            return
        }
        settingsStore.settings = AppSettings(
            selectedLocale: locale,
            textOrganizationSettings: settings,
            hasCompletedWelcome: settingsStore.hasCompletedWelcome
        )
        loadFromSettings()
        setStatus("Saved", isError: false)
    }

    @objc private func runTestOrganization() {
        let settings = currentTextOrganizationSettings
        let rawText = rawTextView.string
        setTestStatus("Running organization test…", isError: false)
        Task {
            do {
                let preview = try await workbench.run(rawText: rawText, settings: settings)
                await MainActor.run {
                    self.organizedTextView.string = preview.organizedText
                    self.setTestStatus(preview.outcome == .organized ? "Organization complete." : "Provider unavailable; showing fallback output.", isError: false)
                }
            } catch {
                await MainActor.run {
                    self.organizedTextView.string = ""
                    self.setTestStatus(error.localizedDescription, isError: true)
                }
            }
        }
    }

    @objc private func clearTestOrganization() {
        rawTextView.string = ""
        organizedTextView.string = ""
        setTestStatus("Paste a raw transcript, then run Test Organization.", isError: false)
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func setTestStatus(_ message: String, isError: Bool) {
        testStatusLabel.stringValue = message
        testStatusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func validationMessage(for errors: [TextOrganizationValidationError]) -> String {
        let labels = errors.map(\.debugDescription)
        if labels.count == 1, let first = labels.first { return "\(first) is required when text organization is enabled." }
        return labels.joined(separator: ", ") + " are required when text organization is enabled."
    }
}
