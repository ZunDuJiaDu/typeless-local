import AppKit
import Foundation

@MainActor
public final class SettingsWindowController: NSWindowController {
    private let settingsStore: SettingsStore
    private let llmRefinementService: LLMRefinementService
    private let localePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let enableCheckbox = NSButton(checkboxWithTitle: "Enable LLM refinement", target: nil, action: nil)
    private let baseURLField = NSTextField(string: "")
    private let apiKeyField = NSSecureTextField(string: "")
    private let modelField = NSTextField(string: "")
    private let statusLabel = NSTextField(labelWithString: "")

    public init(settingsStore: SettingsStore, llmRefinementService: LLMRefinementService) {
        self.settingsStore = settingsStore
        self.llmRefinementService = llmRefinementService

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "WuZi Settings"
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

        let labels = ["Language", "API Base URL", "API Key", "Model"].map { title -> NSTextField in
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            return label
        }

        let testButton = NSButton(title: "Test", target: self, action: #selector(testLLM))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 0

        let grid = NSGridView(views: [
            [labels[0], localePopup],
            [NSTextField(labelWithString: ""), enableCheckbox],
            [labels[1], baseURLField],
            [labels[2], apiKeyField],
            [labels[3], modelField],
            [statusLabel, NSStackView(views: [testButton, saveButton])]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 16
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
        enableCheckbox.state = settings.isLLMRefinementEnabled ? .on : .off
        let configuration = settings.llmConfiguration.normalized()
        baseURLField.stringValue = configuration.baseURL
        apiKeyField.stringValue = configuration.apiKey
        modelField.stringValue = configuration.model
    }

    @objc private func testLLM() {
        let config = currentConfiguration
        let validationErrors = config.validationErrors(isEnabled: true)
        guard validationErrors.isEmpty else {
            AppLogger.llm.notice("Skipped LLM test because the configuration is incomplete")
            setStatus(validationMessage(for: validationErrors), isError: true)
            return
        }

        setStatus("Testing…", isError: false)
        Task {
            do {
                try await llmRefinementService.testConnection(configuration: config)
                await MainActor.run {
                    AppLogger.llm.info("LLM connectivity test passed for baseURL=\(config.baseURL, privacy: .public) model=\(config.model, privacy: .public)")
                    self.setStatus("Connection OK. Save to persist these values.", isError: false)
                }
            } catch {
                await MainActor.run {
                    AppLogger.llm.error("LLM connectivity test failed: \(String(describing: error), privacy: .public)")
                    self.setStatus("Test failed: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    @objc private func saveSettings() {
        let locale = RecognitionLocale.allCases[max(localePopup.indexOfSelectedItem, 0)]
        let llmEnabled = enableCheckbox.state == .on
        let configuration = currentConfiguration
        let validationErrors = configuration.validationErrors(isEnabled: llmEnabled)
        guard validationErrors.isEmpty else {
            AppLogger.llm.error("Rejected invalid LLM settings save enabled=\(llmEnabled, privacy: .public) errors=\(validationErrors.map(\.debugDescription).joined(separator: ", "), privacy: .public)")
            setStatus(validationMessage(for: validationErrors), isError: true)
            return
        }

        settingsStore.settings = AppSettings(
            selectedLocale: locale,
            isLLMRefinementEnabled: llmEnabled,
            llmConfiguration: configuration
        )
        baseURLField.stringValue = configuration.baseURL
        apiKeyField.stringValue = configuration.apiKey
        modelField.stringValue = configuration.model
        AppLogger.llm.info("Saved settings locale=\(locale.rawValue, privacy: .public) enabled=\(llmEnabled, privacy: .public) configured=\(configuration.isConfigured, privacy: .public)")
        setStatus("Saved", isError: false)
    }

    private var currentConfiguration: LLMConfiguration {
        LLMConfiguration(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        ).normalized()
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? .systemRed : .secondaryLabelColor
    }

    private func validationMessage(for errors: [LLMConfigurationValidationError]) -> String {
        let labels = Set(errors.map(\.debugDescription))
        if labels.count == 1, let label = labels.first {
            return "\(label) is required when refinement is enabled."
        }
        return "Base URL and Model are required when refinement is enabled."
    }
}
