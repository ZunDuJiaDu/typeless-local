import AppKit
import Foundation

@MainActor
public final class OverlayPanelController {
    private let panel: NSPanel
    private let contentView = OverlayContentView(frame: .zero)

    public init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = contentView
        panel.alphaValue = 0
    }

    public func show(text: String) {
        contentView.update(text: text, level: 0.08)
        resize(for: text, animated: false)
        positionPanel()
        applyScale(0.92)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            panel.animator().alphaValue = 1
        }
        animateScale(to: 1.0, duration: 0.35)
    }

    public func update(text: String, level: Double) {
        contentView.update(text: text, level: level)
        resize(for: text, animated: true)
    }

    public func showRefining() {
        update(text: "Refining…", level: 0.12)
    }

    public func hide() {
        animateScale(to: 0.96, duration: 0.22)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: {
            self.panel.orderOut(nil)
            self.applyScale(1.0)
        })
    }

    private func resize(for text: String, animated: Bool) {
        let width = WaveformModel.clampedWidth(for: text)
        var frame = panel.frame
        frame.size = CGSize(width: width, height: 56)
        frame.origin = origin(for: frame.size)
        if animated, panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                self.panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func positionPanel() {
        panel.setFrame(NSRect(origin: origin(for: panel.frame.size), size: panel.frame.size), display: true)
    }

    private func origin(for size: CGSize) -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? .zero
        return CGPoint(x: screen.midX - size.width / 2, y: screen.minY + 56)
    }

    private func applyScale(_ scale: CGFloat) {
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
    }

    private func animateScale(to scale: CGFloat, duration: TimeInterval) {
        panel.contentView?.wantsLayer = true
        guard let layer = panel.contentView?.layer else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = layer.value(forKeyPath: "transform.scale") ?? 1.0
        animation.toValue = scale
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(animation, forKey: "scale")
        layer.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
    }
}
