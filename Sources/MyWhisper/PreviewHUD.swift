import AppKit

/// A small floating HUD that shows the live partial transcript while
/// recording. Borderless, click-through, and stays above normal windows.
final class PreviewHUD {
    static let shared = PreviewHUD()

    private static let maxWidth: CGFloat = 480
    private static let bottomMargin: CGFloat = 120
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 12

    private var panel: NSPanel?
    private var label: NSTextField?

    private init() {}

    /// Updates the HUD text and shows it. Empty text keeps the HUD hidden.
    func update(text: String) {
        guard !text.isEmpty else {
            hide()
            return
        }
        if panel == nil { buildPanel() }
        guard let panel, let label else { return }
        label.stringValue = text
        layout(panel: panel, label: label)
        panel.orderFrontRegardless()
    }

    /// Hides the HUD.
    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel() {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.maxWidth, height: 60),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .transient]
        p.isReleasedWhenClosed = false

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.state = .active
        effectView.blendingMode = .behindWindow
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 10
        effectView.layer?.masksToBounds = true

        let textField = NSTextField(wrappingLabelWithString: "")
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.textColor = NSColor.white.withAlphaComponent(0.92)
        textField.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        textField.alignment = .center
        textField.maximumNumberOfLines = 3
        textField.lineBreakMode = .byTruncatingHead

        effectView.addSubview(textField)
        p.contentView = effectView

        panel = p
        label = textField
    }

    private func layout(panel: NSPanel, label: NSTextField) {
        let width = Self.maxWidth
        let textWidth = width - Self.horizontalPadding * 2
        label.preferredMaxLayoutWidth = textWidth
        let fittingSize = label.sizeThatFits(NSSize(width: textWidth, height: .greatestFiniteMagnitude))
        let height = min(fittingSize.height, (label.font?.pointSize ?? 15) * 1.3 * 3) + Self.verticalPadding * 2

        label.frame = NSRect(x: Self.horizontalPadding, y: Self.verticalPadding,
                             width: textWidth, height: fittingSize.height)
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
