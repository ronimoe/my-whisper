import AppKit

/// A singleton window showing the transcript of a file transcribed via
/// "Transcribe Audio File…". Shows the source filename, a scrollable
/// read-only transcript, a char/word count, and a Copy button.
final class TranscriptWindowController: NSObject, NSWindowDelegate {
    static let shared = TranscriptWindowController()

    private var window: NSWindow?
    private var filenameLabel: NSTextField!
    private var textView: NSTextView!
    private var countLabel: NSTextField!

    /// Reloads state, brings the app forward, and shows the window.
    func show() {
        if window == nil { buildWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
                         styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "File Transcript"
        w.isReleasedWhenClosed = false
        w.level = .normal
        w.delegate = self
        w.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 360))

        let filenameLabel = NSTextField(labelWithString: "")
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        filenameLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        filenameLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(filenameLabel)
        self.filenameLabel = filenameLabel

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        self.textView = textView

        let countLabel = NSTextField(labelWithString: "")
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.textColor = .secondaryLabelColor
        countLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        contentView.addSubview(countLabel)
        self.countLabel = countLabel

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyTranscript))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.bezelStyle = .rounded
        contentView.addSubview(copyButton)

        NSLayoutConstraint.activate([
            filenameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            filenameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            filenameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: countLabel.topAnchor, constant: -8),

            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            countLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),

            copyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: countLabel.centerYAnchor),
        ])

        w.contentView = contentView
        window = w
    }

    /// Shows the window in a "working" state while the file decodes/transcribes.
    func setBusy(filename: String) {
        show()
        filenameLabel.stringValue = filename
        textView.string = "Transcribing \(filename)…"
        countLabel.stringValue = ""
    }

    /// Replaces the transcript with the final text and updates the char/word count.
    func setTranscript(_ text: String, for filename: String) {
        filenameLabel.stringValue = filename
        textView.string = text
        let wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        countLabel.stringValue = "\(text.count) characters · \(wordCount) words"
    }

    /// Replaces the transcript area with an error message.
    func setError(_ message: String) {
        textView.string = "Error: \(message)"
        countLabel.stringValue = ""
    }

    @objc private func copyTranscript() {
        let text = textView.string
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func windowWillClose(_ notification: Notification) {}
}
