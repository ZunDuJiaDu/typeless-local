import AppKit
import Foundation

@MainActor
public final class WaveformView: NSView {
    private var heights = Array(repeating: CGFloat(0.1), count: 5)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(heights: [Double]) {
        self.heights = heights.map { CGFloat($0) }
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)

        let barWidth: CGFloat = 6
        let gap: CGFloat = 3.5
        let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(max(heights.count - 1, 0)) * gap
        let startX = (bounds.width - totalWidth) / 2

        for (index, height) in heights.enumerated() {
            let scaledHeight = max(6, min(bounds.height * height, bounds.height))
            let rect = CGRect(
                x: startX + CGFloat(index) * (barWidth + gap),
                y: (bounds.height - scaledHeight) / 2,
                width: barWidth,
                height: scaledHeight
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2)
            NSColor.white.withAlphaComponent(0.92).setFill()
            path.fill()
        }
    }
}

@MainActor
public final class OverlayContentView: NSVisualEffectView {
    private let waveformView = WaveformView(frame: .zero)
    private let label = NSTextField(labelWithString: "Ready")
    private let waveformModel = WaveformModel()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 28
        layer?.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [waveformView, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56),
            waveformView.widthAnchor.constraint(equalToConstant: 44),
            waveformView.heightAnchor.constraint(equalToConstant: 32),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 464)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func update(text: String, level: Double) {
        label.stringValue = text
        waveformView.update(heights: waveformModel.barHeights(for: level))
    }
}
