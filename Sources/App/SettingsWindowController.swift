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

        let labels = ["Language", "API Base URL", "API Key", "Model"].map { title -> NSTextField in
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            return label
        }

        let testButton = NSButton(title: "Test", target: self, action: #selector(testLLM))
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        statusLabel.textColor = .secondaryLabelColor

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
        baseURLField.stringValue = settings.llmConfiguration.baseURL
        apiKeyField.stringValue = settings.llmConfiguration.apiKey
        modelField.stringValue = settings.llmConfiguration.model
    }

    @objc private func testLLM() {
        let config = currentConfiguration
        statusLabel.stringValue = "Testing…"
        Task {
            do {
                try await llmRefinementService.testConnection(configuration: config)
                await MainActor.run {
                    self.statusLabel.stringValue = "Connection OK"
                }
            } catch {
                await MainActor.run {
                    self.statusLabel.stringValue = "Test failed: \(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func saveSettings() {
        let locale = RecognitionLocale.allCases[max(localePopup.indexOfSelectedItem, 0)]
        settingsStore.settings = AppSettings(
            selectedLocale: locale,
            isLLMRefinementEnabled: enableCheckbox.state == .on,
            llmConfiguration: currentConfiguration
        )
        statusLabel.stringValue = "Saved"
    }

    private var currentConfiguration: LLMConfiguration {
        LLMConfiguration(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        )
    }
}
