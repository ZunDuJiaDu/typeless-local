import AppKit
import AVFoundation
import ApplicationServices
import Speech

struct AccessibilityPromptGate {
    private var hasPromptedWithoutGrant = false

    mutating func shouldPrompt(accessibilityGranted: Bool) -> Bool {
        guard !accessibilityGranted else {
            hasPromptedWithoutGrant = false
            return false
        }
        guard !hasPromptedWithoutGrant else { return false }
        hasPromptedWithoutGrant = true
        return true
    }
}

public enum PermissionState: String, Sendable {
    case unknown
    case granted
    case denied

    public var statusLabel: String {
        switch self {
        case .unknown:
            return "Needs approval"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }
}

public enum PermissionRequirement: String, CaseIterable, Sendable {
    case microphone
    case speech
    case accessibility

    public var title: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .speech:
            return "Speech Recognition"
        case .accessibility:
            return "Accessibility"
        }
    }
}

public struct PermissionSnapshot: Sendable {
    public var microphone: PermissionState
    public var speech: PermissionState
    public var accessibility: PermissionState

    public var missingRequirements: [PermissionRequirement] {
        var missing: [PermissionRequirement] = []
        if microphone != .granted { missing.append(.microphone) }
        if speech != .granted { missing.append(.speech) }
        if accessibility != .granted { missing.append(.accessibility) }
        return missing
    }

    public var isReadyForDictation: Bool {
        missingRequirements.isEmpty
    }

    public var summaryText: String {
        guard !missingRequirements.isEmpty else { return "Ready" }
        return "Needs \(missingRequirements.map(\.title).joined(separator: " + "))"
    }

    public var shortPrompt: String {
        guard !missingRequirements.isEmpty else { return "Ready" }
        return "Grant \(missingRequirements.map(\.title).joined(separator: " + "))"
    }

    public var troubleshootingText: String {
        if isReadyForDictation {
            return "All required permissions are granted. WuZi should be ready to listen and paste."
        }

        let steps = missingRequirements.map { requirement -> String in
            switch requirement {
            case .microphone:
                return "• System Settings → Privacy & Security → Microphone → enable WuZi"
            case .speech:
                return "• System Settings → Privacy & Security → Speech Recognition → enable WuZi"
            case .accessibility:
                return "• System Settings → Privacy & Security → Accessibility → enable WuZi"
            }
        }

        return """
        WuZi needs the following before it can start and paste safely:
        \(steps.joined(separator: "\n"))
        """
    }
}

@MainActor
public final class PermissionCoordinator {
    private var accessibilityPromptGate = AccessibilityPromptGate()

    public init() {}

    public func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState(),
            speech: speechState(),
            accessibility: AXIsProcessTrusted() ? .granted : .denied
        )
    }

    public func ensureReadyForRecording() async -> PermissionSnapshot {
        let initialSnapshot = snapshot()
        AppLogger.permissions.info(
            "Permission snapshot before request: mic=\(initialSnapshot.microphone.rawValue, privacy: .public) speech=\(initialSnapshot.speech.rawValue, privacy: .public) ax=\(initialSnapshot.accessibility.rawValue, privacy: .public)"
        )
        if microphoneState() == .unknown {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        if speechState() == .unknown {
            _ = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume(returning: ())
                }
            }
        }
        let updatedSnapshot = snapshot()
        AppLogger.permissions.info(
            "Permission snapshot after request: mic=\(updatedSnapshot.microphone.rawValue, privacy: .public) speech=\(updatedSnapshot.speech.rawValue, privacy: .public) ax=\(updatedSnapshot.accessibility.rawValue, privacy: .public)"
        )
        return updatedSnapshot
    }

    public func promptForAccessibilityIfNeeded() {
        let accessibilityGranted = AXIsProcessTrusted()
        guard accessibilityPromptGate.shouldPrompt(accessibilityGranted: accessibilityGranted) else {
            if accessibilityGranted {
                AppLogger.permissions.debug("Skipping accessibility prompt because trust is already granted")
            } else {
                AppLogger.permissions.debug("Suppressing duplicate accessibility prompt for current launch")
            }
            return
        }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AppLogger.permissions.notice("Prompting for accessibility trust")
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }

    private func speechState() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unknown
        }
    }
}
