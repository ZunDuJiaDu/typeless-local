import Foundation

public enum RecognitionLocale: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case japanese = "ja"
    case korean = "ko"

    public static let `default` = RecognitionLocale.simplifiedChinese

    public static func persisted(_ rawValue: String?) -> RecognitionLocale {
        guard let rawValue, let locale = RecognitionLocale(rawValue: rawValue) else {
            return .default
        }
        return locale
    }

    public var menuTitle: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        }
    }

    public var localeIdentifier: String { rawValue }
}
