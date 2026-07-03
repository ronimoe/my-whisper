import AppKit

/// A floating pill shown for the entire duration of a recording: a live mic
/// level meter, an elapsed-time label, a caption (language/mode), an optional
/// partial-transcript line, and a cancel button. Borderless, non-activating,
/// and stays above normal windows without stealing focus.
final class RecordingPill {
    static let shared = RecordingPill()

    private static let width: CGFloat = 480
    private static let bottomMargin: CGFloat = 120
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 12
    private static let meterHeight: CGFloat = 18
    private static let rowSpacing: CGFloat = 6

    /// Supplies the live mic level (0…1) for the bar meter. Set by AppDelegate.
    var levelProvider: (() -> Float)?
    /// Invoked when the user clicks the ✕ button.
    var onCancel: (() -> Void)?

    private var panel: NSPanel?
    private var meterView: LevelMeterView?
    private var elapsedLabel: NSTextField?
    private var captionLabel: NSTextField?
    private var textLabel: NSTextField?
    private var cancelButton: NSButton?

    private var meterTimer: Timer?
    private var elapsedTimer: Timer?
    private var startDate: Date?

    private init() {}

    /// Builds (if needed) and shows the pill, starting the meter and elapsed
    /// timers. Safe to call repeatedly.
    func show() {
        if panel == nil { buildPanel() }
        guard let panel, let elapsedLabel, let captionLabel, let textLabel else { return }

        startDate = Date()
        elapsedLabel.stringValue = Self.formatElapsed(0)
        captionLabel.stringValue = captionText()
        textLabel.stringValue = ""

        layout(panel: panel, textLabel: textLabel)
        panel.orderFrontRegardless()

        meterTimer?.invalidate()
        let meter = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.meterView?.level = self.levelProvider?() ?? 0
        }
        RunLoop.main.add(meter, forMode: .common)
        meterTimer = meter

        elapsedTimer?.invalidate()
        let elapsed = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickElapsed()
        }
        RunLoop.main.add(elapsed, forMode: .common)
        elapsedTimer = elapsed
    }

    /// Updates the partial-transcript line. Does not affect visibility.
    func update(text: String) {
        guard let panel, let textLabel else { return }
        textLabel.stringValue = text
        layout(panel: panel, textLabel: textLabel)
    }

    /// Hides the pill and invalidates its timers.
    func hide() {
        meterTimer?.invalidate()
        meterTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        startDate = nil
        panel?.orderOut(nil)
    }

    /// Pure formatter for the elapsed-time label: "0:07", "1:23", "12:05".
    static func formatElapsed(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func tickElapsed() {
        guard let elapsedLabel, let startDate else { return }
        let seconds = Int(Date().timeIntervalSince(startDate))
        elapsedLabel.stringValue = Self.formatElapsed(seconds)
    }

    private func captionText() -> String {
        let current = Settings.shared.language
        let name = Settings.languages.first(where: { $0.code == current })?.name ?? current
        let mode = Settings.shared.currentModeName
        if mode != "Raw" {
            return "\(name) · \(mode)"
        }
        return name
    }

    private func buildPanel() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 80),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = false
        p.becomesKeyOnlyIfNeeded = true
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true

        let meter = LevelMeterView(frame: .zero)

        let elapsed = NSTextField(labelWithString: Self.formatElapsed(0))
        elapsed.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        elapsed.textColor = NSColor.white.withAlphaComponent(0.92)
        elapsed.alignment = .left
        elapsed.isBordered = false
        elapsed.drawsBackground = false

        let caption = NSTextField(labelWithString: "")
        caption.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        caption.textColor = NSColor.white.withAlphaComponent(0.6)
        caption.alignment = .left
        caption.isBordered = false
        caption.drawsBackground = false

        let text = NSTextField(wrappingLabelWithString: "")
        text.isEditable = false
        text.isSelectable = false
        text.isBordered = false
        text.drawsBackground = false
        text.textColor = NSColor.white.withAlphaComponent(0.92)
        text.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        text.alignment = .center
        text.maximumNumberOfLines = 3
        text.lineBreakMode = .byTruncatingHead

        let cancel = NSButton(image: cancelImage() ?? NSImage(), target: self, action: #selector(cancelTapped))
        cancel.isBordered = false
        cancel.bezelStyle = NSButton.BezelStyle.regularSquare
        cancel.imagePosition = .imageOnly
        cancel.wantsLayer = true

        effectView.addSubview(meter)
        effectView.addSubview(elapsed)
        effectView.addSubview(caption)
        effectView.addSubview(text)
        effectView.addSubview(cancel)
        p.contentView = effectView

        panel = p
        meterView = meter
        elapsedLabel = elapsed
        captionLabel = caption
        textLabel = text
        cancelButton = cancel
    }

    private func cancelImage() -> NSImage? {
        let image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Cancel dictation")
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let configured = image?.withSymbolConfiguration(config)
        configured?.isTemplate = false
        return configured
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    private func layout(panel: NSPanel, textLabel: NSTextField) {
        let width = Self.width
        let textWidth = width - Self.horizontalPadding * 2
        textLabel.preferredMaxLayoutWidth = textWidth
        let fittingSize = textLabel.sizeThatFits(NSSize(width: textWidth, height: .greatestFiniteMagnitude))
        let textHeight = textLabel.stringValue.isEmpty
            ? 0
            : min(fittingSize.height, (textLabel.font?.pointSize ?? 15) * 1.3 * 3)

        let topRowHeight = Self.meterHeight
        let hasText = textHeight > 0
        let contentHeight = topRowHeight + (hasText ? Self.rowSpacing + textHeight : 0)
        let height = contentHeight + Self.verticalPadding * 2

        // Top row: meter (left), elapsed + caption (middle-left), cancel (right).
        let cancelSize: CGFloat = 20
        let meterWidth: CGFloat = 40
        var x = Self.horizontalPadding
        let topRowY = height - Self.verticalPadding - topRowHeight

        meterView?.frame = NSRect(x: x, y: topRowY, width: meterWidth, height: topRowHeight)
        x += meterWidth + 10

        let labelsWidth = width - x - cancelSize - Self.horizontalPadding - 10
        elapsedLabel?.frame = NSRect(x: x, y: topRowY + topRowHeight / 2 - 1,
                                     width: labelsWidth, height: 14)
        captionLabel?.frame = NSRect(x: x, y: topRowY - 1, width: labelsWidth, height: 12)

        cancelButton?.frame = NSRect(x: width - Self.horizontalPadding - cancelSize,
                                     y: topRowY + (topRowHeight - cancelSize) / 2,
                                     width: cancelSize, height: cancelSize)

        if hasText {
            textLabel.frame = NSRect(x: Self.horizontalPadding,
                                     y: Self.verticalPadding,
                                     width: textWidth, height: textHeight)
        } else {
            textLabel.frame = NSRect(x: Self.horizontalPadding, y: Self.verticalPadding,
                                     width: textWidth, height: 0)
        }

        panel.contentView?.frame = NSRect(x: 0, y: 0, width: width, height: height)

        guard let screen = NSScreen.main else {
            panel.setFrame(NSRect(x: 0, y: 0, width: width, height: height), display: true)
            return
        }
        let screenFrame = screen.frame
        let originX = screenFrame.midX - width / 2
        let originY = screenFrame.minY + Self.bottomMargin
        panel.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
    }
}

/// Small custom view drawing 5 vertical rounded bars, matching the visual
/// language of MenuBarIcon's waveform (white bars, same proportions).
private final class LevelMeterView: NSView {
    var level: Float = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let heights: [CGFloat] = [0.45, 0.75, 1.0, 0.65, 0.5]
        let energy = 0.25 + CGFloat(min(1.0, max(0, level))) * 0.75
        let barWidth: CGFloat = 3
        let gap: CGFloat = 2.5
        let count = CGFloat(heights.count)
        let totalWidth = count * barWidth + (count - 1) * gap
        var x = (bounds.width - totalWidth) / 2
        let maxHeight = bounds.height
        NSColor.white.withAlphaComponent(0.9).setFill()
        for h in heights {
            let barHeight = max(2, maxHeight * min(1.0, h * energy))
            let y = (bounds.height - barHeight) / 2
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: barHeight),
                        xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            x += barWidth + gap
        }
    }
}
