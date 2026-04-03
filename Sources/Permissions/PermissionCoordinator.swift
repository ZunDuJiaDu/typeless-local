import AppKit
import AVFoundation
import ApplicationServices
import Speech

public enum PermissionState: String, Sendable {
    case unknown
    case granted
    case denied
}

public struct PermissionSnapshot: Sendable {
    public var microphone: PermissionState
    public var speech: PermissionState
    public var accessibility: PermissionState
}

@MainActor
public final class PermissionCoordinator {
    public init() {}

    public func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState(),
            speech: speechState(),
            accessibility: AXIsProcessTrusted() ? .granted : .denied
        )
    }

    public func ensureReadyForRecording() async -> PermissionSnapshot {
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
        return snapshot()
    }

    public func promptForAccessibilityIfNeeded() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
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
