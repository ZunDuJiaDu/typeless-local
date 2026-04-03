import AVFoundation
import Foundation
import Speech

public final class SpeechRecognitionService {
    public var onPartialResult: ((String) -> Void)?
    public var onFinalResult: ((String) -> Void)?
    public var onError: ((Error) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    public init() {}

    public func start(locale: RecognitionLocale) throws {
        cancel()
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale.localeIdentifier))
        recognizer?.defaultTaskHint = .dictation
        guard let recognizer else {
            throw NSError(domain: "Typeless.Speech", code: 1)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        self.recognizer = recognizer
        self.request = request
        self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    self?.onFinalResult?(text)
                    self?.cancel()
                } else {
                    self?.onPartialResult?(text)
                }
            }
            if let error {
                self?.onError?(error)
            }
        }
    }

    public func append(buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    public func finish() {
        request?.endAudio()
    }

    public func cancel() {
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
    }
}
