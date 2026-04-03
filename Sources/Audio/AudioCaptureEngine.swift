import AVFoundation
import Foundation

public final class AudioCaptureEngine {
    public var onLevel: ((Double) -> Void)?
    public var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    private let engine: AVAudioEngine
    private var isRunning = false

    public init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    public func start() throws {
        guard !isRunning else { return }
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBuffer?(buffer)
            self.onLevel?(Self.normalizedRMS(from: buffer))
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    public func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private static func normalizedRMS(from buffer: AVAudioPCMBuffer) -> Double {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        if let floatData = buffer.floatChannelData {
            let channels = Int(buffer.format.channelCount)
            var sum: Double = 0
            for channel in 0..<channels {
                let samples = UnsafeBufferPointer(start: floatData[channel], count: frameCount)
                for sample in samples {
                    sum += Double(sample * sample)
                }
            }
            let mean = sum / Double(frameCount * max(channels, 1))
            return min(max(sqrt(mean) * 8.0, 0), 1)
        }

        if let int16Data = buffer.int16ChannelData {
            let channels = Int(buffer.format.channelCount)
            var sum: Double = 0
            for channel in 0..<channels {
                let samples = UnsafeBufferPointer(start: int16Data[channel], count: frameCount)
                for sample in samples {
                    let normalized = Double(sample) / Double(Int16.max)
                    sum += normalized * normalized
                }
            }
            let mean = sum / Double(frameCount * max(channels, 1))
            return min(max(sqrt(mean) * 8.0, 0), 1)
        }

        return 0
    }
}
