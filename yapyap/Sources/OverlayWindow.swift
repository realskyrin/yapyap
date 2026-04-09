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
    private var cancelButton: OverlayActionButton?
    private var confirmButton: OverlayActionButton?
    private var currentText: String = ""
    private var state: OverlayState = .recording
    private var isClickMode = false

    // Callbacks for click-mode buttons
    var onCancel: (() -> Void)?
    var onConfirm: (() -> Void)?

    // Layout constants
    private let capsuleHeight: CGFloat = 33
    private let capsuleWidthCompact: CGFloat = 70
    private let bubbleMinHeight: CGFloat = 32
    private let bubbleGap: CGFloat = 6
    private let bubbleMaxWidth: CGFloat = 320
    private let bubblePaddingH: CGFloat = 12
    private let bubblePaddingV: CGFloat = 8
    private let bottomOffset: CGFloat = 120 // above dock
    private let actionButtonSize: CGFloat = 33
    private let actionButtonGap: CGFloat = 4

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
        let win = NSPanel(contentRect: frame,
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered,
                          defer: false)
        win.level = .floating
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false
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
        textField.alphaValue = 0  // fade in with container
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
            win.ignoresMouseEvents = true
            self?.window = nil
            self?.capsuleView = nil
            self?.bubbleContainerView = nil
            self?.bubbleTextField = nil
            self?.containerView = nil
            self?.cancelButton = nil
            self?.confirmButton = nil
            self?.currentText = ""
            self?.isClickMode = false
        })
    }

    func enterClickMode() {
        guard let parentView = containerView,
              let capsule = capsuleView,
              let win = window else {
            logger.warning("enterClickMode: window not ready yet")
            return
        }
        logger.info("enterClickMode: showing action buttons")
        isClickMode = true

        if cancelButton == nil {
            let cancel = OverlayActionButton(kind: .cancel,
                frame: NSRect(x: 0, y: 0, width: actionButtonSize, height: actionButtonSize))
            cancel.alphaValue = 0
            cancel.onClick = { [weak self] in self?.onCancel?() }
            parentView.addSubview(cancel)
            self.cancelButton = cancel

            let confirm = OverlayActionButton(kind: .confirm,
                frame: NSRect(x: 0, y: 0, width: actionButtonSize, height: actionButtonSize))
            confirm.alphaValue = 0
            confirm.onClick = { [weak self] in self?.onConfirm?() }
            parentView.addSubview(confirm)
            self.confirmButton = confirm
        }

        layoutActionButtons()
        win.ignoresMouseEvents = false

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.cancelButton?.animator().alphaValue = 1
            self.confirmButton?.animator().alphaValue = 1
        }
    }

    private func layoutActionButtons() {
        guard let capsule = capsuleView,
              let cancel = cancelButton,
              let confirm = confirmButton else { return }

        let cancelX = capsule.frame.origin.x - actionButtonGap - actionButtonSize
        let confirmX = capsule.frame.maxX + actionButtonGap
        let btnY = capsule.frame.origin.y + (capsule.frame.height - actionButtonSize) / 2

        cancel.frame = NSRect(x: cancelX, y: btnY, width: actionButtonSize, height: actionButtonSize)
        confirm.frame = NSRect(x: confirmX, y: btnY, width: actionButtonSize, height: actionButtonSize)
    }

    func updateLevel(_ level: Float) {
        capsuleView?.audioLevel = CGFloat(level)
    }

    func updateText(_ text: String) {
        guard !text.isEmpty else { return }
        currentText = text

        // NOTE: This method must run synchronously on the main thread.
        // All callers already dispatch to main. An extra DispatchQueue.main.async
        // here would cause the final inference text update to race with hide(),
        // resulting in the last character never appearing in the bubble.

        guard let textField = self.bubbleTextField,
              let bubbleContainer = self.bubbleContainerView,
              let parentView = self.containerView,
              let capsule = self.capsuleView,
              let win = self.window else { return }

        let maxTextWidth = self.bubbleMaxWidth - self.bubblePaddingH * 2
        let font = textField.font ?? NSFont.systemFont(ofSize: 13, weight: .medium)

        // Measure text size using the text field's cell for accurate width
        // (NSString.size(withAttributes:) underestimates by ignoring cell margins)
        textField.stringValue = text
        let cellSize = textField.cell?.cellSize ?? .zero
        let singleLineWidth = ceil(cellSize.width)

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let needsWrap = singleLineWidth > maxTextWidth
        let contentWidth: CGFloat
        let textHeight: CGFloat

        if needsWrap {
            contentWidth = maxTextWidth
            let boundingRect = (text as NSString).boundingRect(
                with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            textHeight = ceil(boundingRect.height)
        } else {
            contentWidth = singleLineWidth
            textHeight = ceil(cellSize.height)
        }

        let bubbleWidth = min(contentWidth + self.bubblePaddingH * 2, self.bubbleMaxWidth)
        let bubbleHeight = max(self.bubbleMinHeight, textHeight + self.bubblePaddingV * 2)
        let bubbleX = (parentView.bounds.width - bubbleWidth) / 2
        let targetBubbleFrame = NSRect(x: bubbleX, y: 0, width: bubbleWidth, height: bubbleHeight)
        let capsuleX = (parentView.bounds.width - self.capsuleWidthCompact) / 2
        let targetCapsuleFrame = NSRect(x: capsuleX, y: bubbleHeight + self.bubbleGap,
                                        width: self.capsuleWidthCompact, height: self.capsuleHeight)
        let totalHeight = bubbleHeight + self.bubbleGap + self.capsuleHeight + 20
        var winFrame = win.frame
        winFrame.size.height = totalHeight
        winFrame.origin.y = self.bottomOffset

        // First appearance: set frames instantly, then fade in container + text together
        let isFirstAppearance = bubbleContainer.alphaValue < 1

        if isFirstAppearance {
            // Set layout immediately (no animation) so text is never clipped
            bubbleContainer.frame = targetBubbleFrame
            textField.frame = NSRect(
                x: self.bubblePaddingH, y: self.bubblePaddingV,
                width: bubbleWidth - self.bubblePaddingH * 2,
                height: bubbleHeight - self.bubblePaddingV * 2
            )
            capsule.frame = targetCapsuleFrame
            win.setFrame(winFrame, display: true)
            textField.stringValue = text

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                bubbleContainer.animator().alphaValue = 1
                textField.animator().alphaValue = 1
            }
        } else {
            // Subsequent updates: resize layout instantly, then set text
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            bubbleContainer.frame = targetBubbleFrame
            textField.frame = NSRect(
                x: self.bubblePaddingH, y: self.bubblePaddingV,
                width: bubbleWidth - self.bubblePaddingH * 2,
                height: bubbleHeight - self.bubblePaddingV * 2
            )
            capsule.frame = targetCapsuleFrame
            CATransaction.commit()

            textField.stringValue = text

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 1.0, 0.5, 1.0)
                win.animator().setFrame(winFrame, display: true)
            }
        }

        // Keep action buttons aligned with capsule
        if self.isClickMode {
            self.layoutActionButtons()
        }
    }

    func showProcessing() {
        state = .processing
        capsuleView?.showProcessing()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.bubbleContainerView?.animator().alphaValue = 0
                // Hide action buttons when entering processing
                self.cancelButton?.animator().alphaValue = 0
                self.confirmButton?.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.cancelButton?.removeFromSuperview()
                self?.cancelButton = nil
                self?.confirmButton?.removeFromSuperview()
                self?.confirmButton = nil
                self?.isClickMode = false
                self?.window?.ignoresMouseEvents = true
            }
        }
    }
}

// MARK: - FlippedView (top-left origin for easier layout)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only allow clicks on OverlayActionButton; everything else passes through
        let result = super.hitTest(point)
        if result is OverlayActionButton { return result }
        return nil
    }
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

// MARK: - OverlayActionButton (cancel / confirm circles for click mode)

private class OverlayActionButton: NSView {
    enum Kind { case cancel, confirm }
    let kind: Kind
    var onClick: (() -> Void)?
    private var isPressed = false

    private let bgColor = NSColor(calibratedRed: 20/255, green: 20/255, blue: 20/255, alpha: 0.92)
    private let pressedBgColor = NSColor(calibratedWhite: 0.28, alpha: 0.92)
    private let symbolColor = NSColor(calibratedWhite: 1.0, alpha: 0.85)

    init(kind: Kind, frame: NSRect) {
        self.kind = kind
        super.init(frame: frame)
        wantsLayer = true
        focusRingType = .none
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { false }
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Circle background — lighter when pressed
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        (isPressed ? pressedBgColor : bgColor).setFill()
        circle.fill()

        // Subtle border
        NSColor(calibratedWhite: 1.0, alpha: 0.06).setStroke()
        circle.lineWidth = 0.5
        circle.stroke()

        // Draw symbol
        let cx = bounds.midX
        let cy = bounds.midY
        let s: CGFloat = 5.0

        let path = NSBezierPath()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        symbolColor.setStroke()

        switch kind {
        case .cancel:
            path.move(to: CGPoint(x: cx - s, y: cy - s))
            path.line(to: CGPoint(x: cx + s, y: cy + s))
            path.move(to: CGPoint(x: cx + s, y: cy - s))
            path.line(to: CGPoint(x: cx - s, y: cy + s))
        case .confirm:
            // Checkmark: left → bottom → top-right (flipped coords, y down)
            path.move(to: CGPoint(x: cx - s * 0.9, y: cy - s * 0.1))
            path.line(to: CGPoint(x: cx - s * 0.15, y: cy + s * 0.7))
            path.line(to: CGPoint(x: cx + s, y: cy - s * 0.7))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        needsDisplay = true
        let localPoint = convert(event.locationInWindow, from: nil)
        if bounds.contains(localPoint) {
            onClick?()
        }
    }
}
