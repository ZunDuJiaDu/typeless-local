import Foundation

public enum InputSourceClassification: Equatable {
    case cjk
    case asciiCapable
    case unknown
}

public enum InputSourceClassifier {
    public static func classify(identifier: String) -> InputSourceClassification {
        let lowered = identifier.lowercased()
        if lowered.contains("pinyin") || lowered.contains("scim") || lowered.contains("kotoeri") || lowered.contains("japanese") || lowered.contains("korean") || lowered.contains("tcim") {
            return .cjk
        }
        if lowered.contains("abc") || lowered.contains("us") || lowered.contains("keylayout") {
            return .asciiCapable
        }
        return .unknown
    }
}
