import AppKit
import Foundation

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let textOrganizationService: TextOrganizationService
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

    public init(settingsStore: SettingsStore, textOrganizationService: TextOrganizationService) {
        self.settingsStore = settingsStore
        self.textOrganizationService = textOrganizationService

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typeless Settings"
        super.init(window: window)
        configureUI()
        loadFromSettings()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureUI() {
        guard let contentView = window?.contentView else { return }

        RecognitionLocale.allCases.forEach { locale in
            localePopup.addItem(withTitle: locale.menuTitle)
            localePopup.lastItem?.representedObject = locale.rawValue
        }

        TextOrganizationProviderKind.allCases.forEach { provider in
            providerPopup.addItem(withTitle: provider.displayName)
            providerPopup.lastItem?.representedObject = provider.rawValue
        }

        OrganizationStrength.allCases.forEach { strength in
            strengthPopup.addItem(withTitle: strength.displayName)
            strengthPopup.lastItem?.representedObject = strength.rawValue
        }

        enableCheckbox.target = self
        enableCheckbox.action = #selector(handleFormToggles)
        providerPopup.target = self
        providerPopup.action = #selector(handleFormToggles)

        let labels = [
            "Language",
            "Primary Provider",
            "Ollama Host",
            "Ollama Model",
            "Organization Strength",
            "OpenAI-Compatible Base URL",
            "OpenAI-Compatible API Key",
            "OpenAI-Compatible Model"
        ].map { title -> NSTextField in
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            return label
        }

        let advancedLabel = NSTextField(labelWithString: "Advanced Secondary Path")
        advancedLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let advancedDescription = NSTextField(labelWithString: "Keep an OpenAI-compatible endpoint configured as the secondary provider.")
        advancedDescription.textColor = .secondaryLabelColor
        advancedDescription.lineBreakMode = .byWordWrapping
        advancedDescription.maximumNumberOfLines = 0

        let testButton = NSButton(title: "Test Active Provider", target: self, action: #selector(testTextOrganization))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0

        let grid = NSGridView(views: [
            [labels[0], localePopup],
            [NSTextField(labelWithString: ""), enableCheckbox],
            [labels[1], providerPopup],
            [labels[2], ollamaHostField],
            [labels[3], ollamaModelField],
            [labels[4], strengthPopup],
            [NSTextField(labelWithString: ""), preserveToneCheckbox],
            [NSTextField(labelWithString: ""), preserveStructureCheckbox],
            [advancedLabel, advancedDescription],
            [labels[5], openAIBaseURLField],
            [labels[6], openAIAPIKeyField],
            [labels[7], openAIModelField],
            [statusLabel, NSStackView(views: [testButton, saveButton])]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 16
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24)
        ])
    }

    private func loadFromSettings() {
        let settings = settingsStore.settings
        if let index = RecognitionLocale.allCases.firstIndex(of: settings.selectedLocale) {
            localePopup.selectItem(at: index)
        }

        let organizationSettings = settings.textOrganizationSettings.normalized()
        enableCheckbox.state = organizationSettings.isEnabled ? .on : .off

        if let providerIndex = TextOrganizationProviderKind.allCases.firstIndex(of: organizationSettings.preferredProvider) {
            providerPopup.selectItem(at: providerIndex)
        }
        if let strengthIndex = OrganizationStrength.allCases.firstIndex(of: organizationSettings.options.strength) {
            strengthPopup.selectItem(at: strengthIndex)
        }

        ollamaHostField.stringValue = organizationSettings.ollamaConfiguration.host
        ollamaModelField.stringValue = organizationSettings.ollamaConfiguration.model
        preserveToneCheckbox.state = organizationSettings.options.preserveTone ? .on : .off
        preserveStructureCheckbox.state = organizationSettings.options.preserveStructureIntent ? .on : .off
        openAIBaseURLField.stringValue = organizationSettings.openAICompatibleConfiguration.baseURL
        openAIAPIKeyField.stringValue = organizationSettings.openAICompatibleConfiguration.apiKey
        openAIModelField.stringValue = organizationSettings.openAICompatibleConfiguration.model
        syncFormState()
    }

    @objc private func handleFormToggles() {
        syncFormState()
    }

    @objc private func testTextOrganization() {
        let settings = currentTextOrganizationSettings
        let validationErrors = settings.validationErrors()
        guard validationErrors.isEmpty else {
            AppLogger.llm.notice("Skipped text organization test because the configuration is incomplete")
            setStatus(validationMessage(for: validationErrors), isError: true)
            return
        }

        setStatus("Testing \(settings.activeProviderDisplayName)…", isError: false)
        Task {
            do {
                try await textOrganizationService.testConnection(settings: settings)
                await MainActor.run {
                    AppLogger.llm.info(
                        "Text organization connectivity test passed provider=\(settings.activeProviderDisplayName, privacy: .public)"
                    )
                    self.setStatus("\(settings.activeProviderDisplayName) connection OK. Save to persist these values.", isError: false)
                }
            } catch {
                await MainActor.run {
                    AppLogger.llm.error("Text organization connectivity test failed: \(String(describing: error), privacy: .public)")
                    self.setStatus("Test failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    @objc private func saveSettings() {
        let locale = RecognitionLocale.allCases[max(localePopup.indexOfSelectedItem, 0)]
        let organizationSettings = currentTextOrganizationSettings
        let validationErrors = organizationSettings.validationErrors()
        guard validationErrors.isEmpty else {
            AppLogger.llm.error(
                "Rejected invalid text organization settings save enabled=\(organizationSettings.isEnabled, privacy: .public) provider=\(organizationSettings.activeProviderDisplayName, privacy: .public) errors=\(validationErrors.map(\.debugDescription).joined(separator: ", "), privacy: .public)"
            )
            setStatus(validationMessage(for: validationErrors), isError: true)
            return
        }

        settingsStore.settings = AppSettings(
            selectedLocale: locale,
            textOrganizationSettings: organizationSettings
        )
        loadFromSettings()
        AppLogger.llm.info(
            "Saved settings locale=\(locale.rawValue, privacy: .public) provider=\(organizationSettings.activeProviderDisplayName, privacy: .public) enabled=\(organizationSettings.isEnabled, privacy: .public)"
        )
        setStatus("Saved", isError: false)
    }

    private var currentTextOrganizationSettings: TextOrganizationSettings {
        TextOrganizationSettings(
            isEnabled: enableCheckbox.state == .on,
            preferredProvider: selectedProvider,
            ollamaConfiguration: OllamaConfiguration(
                host: ollamaHostField.stringValue,
                model: ollamaModelField.stringValue
            ),
            openAICompatibleConfiguration: LLMConfiguration(
                baseURL: openAIBaseURLField.stringValue,
                apiKey: openAIAPIKeyField.stringValue,
                model: openAIModelField.stringValue
            ),
            options: TextOrganizationOptions(
                strength: selectedStrength,
                preserveTone: preserveToneCheckbox.state == .on,
                preserveStructureIntent: preserveStructureCheckbox.state == .on
            )
        ).normalized()
    }

    private var selectedProvider: TextOrganizationProviderKind {
        guard
            let rawValue = providerPopup.selectedItem?.representedObject as? String,
            let provider = TextOrganizationProviderKind(rawValue: rawValue)
        else {
            return .ollama
        }
        return provider
    }

    private var selectedStrength: OrganizationStrength {
        guard
            let rawValue = strengthPopup.selectedItem?.representedObject as? String,
            let strength = OrganizationStrength(rawValue: rawValue)
        else {
            return .balanced
        }
        return strength
    }

    private func syncFormState() {
        let isEnabled = enableCheckbox.state == .on
        [
            providerPopup,
            ollamaHostField,
            ollamaModelField,
            strengthPopup,
            openAIBaseURLField,
            openAIAPIKeyField,
            openAIModelField
        ].forEach { $0.isEnabled = isEnabled }
        preserveToneCheckbox.isEnabled = isEnabled
        preserveStructureCheckbox.isEnabled = isEnabled
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func validationMessage(for errors: [TextOrganizationValidationError]) -> String {
        let labels = errors.map(\.debugDescription)
        if labels.count == 1, let label = labels.first {
            return "\(label) is required when text organization is enabled."
        }
        return labels.joined(separator: ", ") + " are required when text organization is enabled."
    }
}
