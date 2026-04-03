import Foundation

public struct EnvelopeSmoother {
    private let attackFactor: Double
    private let releaseFactor: Double
    private var currentValue: Double

    public init(attackFactor: Double, releaseFactor: Double, currentValue: Double = 0) {
        self.attackFactor = attackFactor
        self.releaseFactor = releaseFactor
        self.currentValue = currentValue
    }

    public mutating func process(level: Double) -> Double {
        let clamped = min(max(level, 0), 1)
        let factor = clamped > currentValue ? attackFactor : releaseFactor
        currentValue += (clamped - currentValue) * factor
        return currentValue
    }
}
