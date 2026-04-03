import Cocoa
import os.log

private let logger = Logger(subsystem: "cn.skyrin.yapyap", category: "Overlay")

// MARK: - Overlay State

enum OverlayState {
    case recording
    case processing
}

// MARK: - OverlayWindow

class OverlayWindow {
    private var window: NSWindow?
    private var capsuleView: CapsuleView?
    private var bubbleContainerView: NSView?
    private var bubbleTextField: NSTextField?
    private var containerView: NSView?
    private var currentText: String = ""
    private var state: OverlayState = .recording

    // Layout constants
    private let capsuleHeight: CGFloat = 33
    private let capsuleWidthCompact: CGFloat = 70
    private let bubbleMinHeight: CGFloat = 32
    private let bubbleGap: CGFloat = 6
    private let bubbleMaxWidth: CGFloat = 320
    private let bubblePaddingH: CGFloat = 12
    private let bubblePaddingV: CGFloat = 8
    private let bottomOffset: CGFloat = 120 // above dock

    func show() {
        guard window == nil else { return }
        guard let screen = NSScreen.main else { return }

        state = .recording
        currentText = ""

        // Window sized to hold capsule + bubble
        let winWidth = bubbleMaxWidth + 20
        let winHeight = capsuleHeight + bubbleMinHeight + bubbleGap + 20
        let x = (screen.frame.width - winWidth) / 2
        let y = bottomOffset

        let frame = NSRect(x: x, y: y, width: winWidth, height: winHeight)
        let win = NSWindow(contentRect: frame,
                           styleMask: .borderless,
                           backing: .buffered,
                           defer: false)
        win.level = .floating
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Container uses flipped coords (top-left origin)
        let container = FlippedView(frame: NSRect(x: 0, y: 0, width: winWidth, height: winHeight))
        container.wantsLayer = true
        win.contentView = container
        self.containerView = container

        // Text bubble container (hidden initially, appears when text arrives)
        let bubbleX = (winWidth - bubbleMaxWidth) / 2
        let bubbleContainer = NSView(frame: NSRect(x: bubbleX, y: 0, width: bubbleMaxWidth, height: bubbleMinHeight))
        bubbleContainer.wantsLayer = true
        bubbleContainer.layer?.backgroundColor = NSColor(calibratedRed: 20/255, green: 20/255, blue: 20/255, alpha: 0.88).cgColor
        bubbleContainer.layer?.cornerRadius = 10
        bubbleContainer.layer?.masksToBounds = true
        bubbleContainer.alphaValue = 0
        container.addSubview(bubbleContainer)
        self.bubbleContainerView = bubbleContainer

        // Text field inside bubble with padding
        let textField = NSTextField(frame: NSRect(
            x: bubblePaddingH, y: bubblePaddingV,
            width: bubbleMaxWidth - bubblePaddingH * 2,
            height: bubbleMinHeight - bubblePaddingV * 2
        ))
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.92)
        textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textField.alignment = .right
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 5
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        bubbleContainer.addSubview(textField)
        self.bubbleTextField = textField

        // Capsule view (centered below bubble)
        let capsuleX = (winWidth - capsuleWidthCompact) / 2
        let capsuleY = bubbleMinHeight + bubbleGap
        let capsule = CapsuleView(frame: NSRect(x: capsuleX, y: capsuleY, width: capsuleWidthCompact, height: capsuleHeight))
        container.addSubview(capsule)
        self.capsuleView = capsule

        self.window = win

        // Animate in with spring
        win.alphaValue = 0
        win.orderFrontRegardless()
        capsule.startAnimation()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
            win.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let win = window else { return }
        capsuleView?.stopAnimation()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
            self?.capsuleView = nil
            self?.bubbleContainerView = nil
            self?.bubbleTextField = nil
            self?.containerView = nil
            self?.currentText = ""
        })
    }

    func updateLevel(_ level: Float) {
        capsuleView?.audioLevel = CGFloat(level)
    }

    func updateText(_ text: String) {
        guard !text.isEmpty else { return }
        currentText = text
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let textField = self.bubbleTextField,
                  let bubbleContainer = self.bubbleContainerView,
                  let parentView = self.containerView,
                  let capsule = self.capsuleView,
                  let win = self.window else { return }

            textField.stringValue = text

            // Calculate required text height for multi-line
            let maxTextWidth = self.bubbleMaxWidth - self.bubblePaddingH * 2
            let textHeight = textField.cell?.cellSize(forBounds: NSRect(
                x: 0, y: 0, width: maxTextWidth, height: .greatestFiniteMagnitude
            )).height ?? 16
            let bubbleHeight = max(self.bubbleMinHeight, textHeight + self.bubblePaddingV * 2)

            // Resize text field
            textField.frame = NSRect(
                x: self.bubblePaddingH, y: self.bubblePaddingV,
                width: maxTextWidth,
                height: bubbleHeight - self.bubblePaddingV * 2
            )

            // Resize bubble container
            let bubbleX = (parentView.bounds.width - self.bubbleMaxWidth) / 2
            bubbleContainer.frame = NSRect(x: bubbleX, y: 0, width: self.bubbleMaxWidth, height: bubbleHeight)

            // Reposition capsule below bubble
            let capsuleX = (parentView.bounds.width - self.capsuleWidthCompact) / 2
            capsule.frame = NSRect(x: capsuleX, y: bubbleHeight + self.bubbleGap, width: self.capsuleWidthCompact, height: self.capsuleHeight)

            // Resize window (grow upward, keep bottom edge fixed)
            let totalHeight = bubbleHeight + self.bubbleGap + self.capsuleHeight + 20
            var winFrame = win.frame
            winFrame.size.height = totalHeight
            winFrame.origin.y = self.bottomOffset
            win.setFrame(winFrame, display: true)

            // Show bubble if hidden
            if bubbleContainer.alphaValue < 1 {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.25
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    bubbleContainer.animator().alphaValue = 1
                }
            }
        }
    }

    func showProcessing() {
        state = .processing
        capsuleView?.showProcessing()
        // Fade out the text bubble during processing
        DispatchQueue.main.async { [weak self] in
            guard let container = self?.bubbleContainerView else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                container.animator().alphaValue = 0
            }
        }
    }
}

// MARK: - FlippedView (top-left origin for easier layout)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - CapsuleView

private class CapsuleView: NSView {
    // Bar configuration
    private let barCount = 7
    private let barWidth: CGFloat = 3.0
    private let barGap: CGFloat = 2
    private let barRadius: CGFloat = 1.5
    private let barMinHeight: CGFloat = 3
    private let barMaxHeight: CGFloat = 22
    private let barEnvelope: [CGFloat] = [0.5, 0.7, 0.85, 1.0, 0.75, 0.65, 0.4]

    // Colors
    private let capsuleBg = NSColor(calibratedRed: 20/255, green: 20/255, blue: 20/255, alpha: 0.92)
    private let barColorBase = NSColor(calibratedRed: 180/255, green: 180/255, blue: 180/255, alpha: 1.0)

    // State
    var audioLevel: CGFloat = 0
    private var smoothedLevel: CGFloat = 0
    private var timer: Timer?
    private var startTime: CFTimeInterval = 0
    private var isProcessing = false

    // Thinking dots
    private let dotCount = 6
    private let dotDurations: [Double] = [1.3, 1.7, 1.1, 1.5, 1.9, 1.25]
    private let dotDelays: [Double] = [0, 0.4, 0.15, 0.65, 0.3, 0.8]

    func startAnimation() {
        startTime = CACurrentMediaTime()
        isProcessing = false
        smoothedLevel = 0
        // 60fps timer
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    func showProcessing() {
        isProcessing = true
        startTime = CACurrentMediaTime()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw capsule background
        let capsulePath = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        capsuleBg.setFill()
        capsulePath.fill()

        // Subtle border
        NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
        capsulePath.lineWidth = 0.5
        capsulePath.stroke()

        let now = CACurrentMediaTime()
        let elapsed = now - startTime

        if isProcessing {
            drawThinkingDots(ctx: ctx, elapsed: elapsed)
        } else {
            drawWaveformBars(ctx: ctx, elapsed: elapsed)
        }
    }

    // MARK: - Waveform bars (purely RMS-driven)

    private func drawWaveformBars(ctx: CGContext, elapsed: Double) {
        // Asymmetric smoothing: fast attack 40%, slow release 15%
        let dt: CGFloat = 1.0 / 60.0
        let rate: CGFloat = audioLevel > smoothedLevel ? 0.4 : 0.15
        let alpha = 1.0 - pow(1.0 - rate, dt * 60)
        smoothedLevel += (audioLevel - smoothedLevel) * alpha

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        for i in 0..<barCount {
            // ±4% random jitter per bar for organic feel
            let jitter: CGFloat = 1.0 + CGFloat.random(in: -0.04...0.04)
            let barH = barMinHeight + smoothedLevel * barEnvelope[i] * (barMaxHeight - barMinHeight) * jitter

            let x = startX + CGFloat(i) * (barWidth + barGap)
            let y = centerY - barH / 2

            let barAlpha = 0.5 + smoothedLevel * 0.45
            let color = barColorBase.withAlphaComponent(barAlpha)

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 3 + smoothedLevel * 8,
                          color: NSColor(calibratedWhite: 0.7, alpha: 0.15 + smoothedLevel * 0.4).cgColor)
            color.setFill()
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barH)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: barRadius, yRadius: barRadius)
            barPath.fill()
            ctx.restoreGState()
        }
    }

    // MARK: - Thinking dots (from handless algorithm)

    private func drawThinkingDots(ctx: CGContext, elapsed: Double) {
        let dotSize: CGFloat = 2.5
        let dotGap: CGFloat = 4
        let totalWidth = CGFloat(dotCount) * dotSize + CGFloat(dotCount - 1) * dotGap
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        let accentColor = NSColor(calibratedRed: 180/255, green: 180/255, blue: 180/255, alpha: 1.0)

        for i in 0..<dotCount {
            let duration = dotDurations[i]
            let delay = dotDelays[i]
            let t = max(0, elapsed - delay)
            let phase = t.truncatingRemainder(dividingBy: duration) / duration

            let opacity = fidgetOpacity(phase: phase)
            let (dx, dy) = fidgetOffset(phase: phase)

            let x = startX + CGFloat(i) * (dotSize + dotGap) + CGFloat(dx)
            let y = centerY - dotSize / 2 + CGFloat(dy)

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 3,
                          color: accentColor.withAlphaComponent(CGFloat(opacity) * 0.6).cgColor)
            accentColor.withAlphaComponent(CGFloat(opacity)).setFill()
            let dotRect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            dotPath.fill()
            ctx.restoreGState()
        }
    }

    private func fidgetOpacity(phase: Double) -> Double {
        let p = phase
        if p < 0.12 { return 0.4 + (1.0 - 0.4) * (p / 0.12) }
        if p < 0.24 { return 1.0 - (1.0 - 0.35) * ((p - 0.12) / 0.12) }
        if p < 0.38 { return 0.35 + (0.95 - 0.35) * ((p - 0.24) / 0.14) }
        if p < 0.50 { return 0.95 - (0.95 - 0.3) * ((p - 0.38) / 0.12) }
        if p < 0.62 { return 0.3 + (1.0 - 0.3) * ((p - 0.50) / 0.12) }
        if p < 0.74 { return 1.0 - (1.0 - 0.4) * ((p - 0.62) / 0.12) }
        if p < 0.88 { return 0.4 + (0.9 - 0.4) * ((p - 0.74) / 0.14) }
        return 0.9 - (0.9 - 0.4) * ((p - 0.88) / 0.12)
    }

    private func fidgetOffset(phase: Double) -> (Double, Double) {
        let p = phase
        if p < 0.12 { return (0.8 * (p / 0.12), -2.0 * (p / 0.12) + 2.5) }
        if p < 0.24 { return (0.8 - 1.1 * ((p - 0.12) / 0.12), 2.0 * ((p - 0.12) / 0.12) - 2.0) }
        if p < 0.50 { return (-0.3, 2.5 * sin(Double.pi * (p - 0.24) / 0.26)) }
        if p < 0.62 { return (0.5, -2.5 * ((p - 0.50) / 0.12)) }
        return (0.2 * sin(Double.pi * 2 * p), 1.0 * sin(Double.pi * 3 * p))
    }
}
