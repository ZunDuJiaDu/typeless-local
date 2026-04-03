import Foundation

public enum MainWindowPage: String, CaseIterable, Equatable, Sendable {
    case welcome
    case general
    case speechRecognition
    case ollamaOrganization
    case testOrganization
    case injectionAndPaste
    case advanced
    case about

    public var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .general: return "General"
        case .speechRecognition: return "Speech Recognition"
        case .ollamaOrganization: return "Ollama Organization"
        case .testOrganization: return "Test Organization"
        case .injectionAndPaste: return "Injection & Paste"
        case .advanced: return "Advanced"
        case .about: return "About"
        }
    }

    public var systemImageName: String {
        switch self {
        case .welcome: return "sparkles"
        case .general: return "slider.horizontal.3"
        case .speechRecognition: return "waveform.badge.mic"
        case .ollamaOrganization: return "brain"
        case .testOrganization: return "text.alignleft"
        case .injectionAndPaste: return "arrow.right.doc.on.clipboard"
        case .advanced: return "gearshape.2"
        case .about: return "info.circle"
        }
    }
}

public struct MainWindowNavigationModel: Equatable, Sendable {
    public let pages: [MainWindowPage]

    public init(pages: [MainWindowPage] = MainWindowPage.allCases) {
        self.pages = pages
    }

    public func initialPage(hasCompletedWelcome: Bool) -> MainWindowPage {
        hasCompletedWelcome ? .general : .welcome
    }
}
