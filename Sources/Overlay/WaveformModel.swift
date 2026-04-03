import CoreGraphics
import Foundation

public struct WaveformModel {
    public typealias RandomSource = () -> Double

    public static let weights: [Double] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let randomSource: RandomSource

    public init(randomSource: @escaping RandomSource = { Double.random(in: -1...1) }) {
        self.randomSource = randomSource
    }

    public func barHeights(for normalizedLevel: Double) -> [Double] {
        let level = min(max(normalizedLevel, 0), 1)
        return Self.weights.map { weight in
            let jitter = randomSource() * 0.04
            let base = max(0.08, min(level * weight, 1.0))
            return min(max(base * (1 + jitter), 0.08), 1.04)
        }
    }

    public static func clampedWidth(for text: String) -> CGFloat {
        let estimated = 160 + text.count * 8
        return CGFloat(min(max(estimated, 160), 560))
    }
}
