import AppKit

/// A singleton window showing past transcriptions, newest first. Doubling
/// clicking a row copies its text; a button clears the whole history.
final class HistoryWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = HistoryWindowController()

    private var window: NSWindow?
    private var tableView: NSTableView!
    private var entries: [Entry] = []

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Reloads data, brings the app forward, and shows the window.
    func show() {
        if window == nil { buildWindow() }
        reload()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 380),
                         styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Dictation History"
        w.isReleasedWhenClosed = false
        w.level = .normal
        w.delegate = self
        w.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 380))

        let clearButton = NSButton(title: "Clear History", target: self, action: #selector(clearHistory))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.bezelStyle = .rounded
        contentView.addSubview(clearButton)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.rowSizeStyle = .medium

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 140
        timeColumn.minWidth = 100
        timeColumn.maxWidth = 220
        table.addTableColumn(timeColumn)

        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Text"
        textColumn.width = 440
        table.addTableColumn(textColumn)

        table.target = self
        table.doubleAction = #selector(rowDoubleClicked)

        scrollView.documentView = table
        contentView.addSubview(scrollView)
        tableView = table

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),

            clearButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            clearButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])

        w.contentView = contentView
        window = w
    }

    private func reload() {
        entries = HistoryStore.shared.load().reversed()
        tableView?.reloadData()
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clear()
        reload()
    }

    @objc private func rowDoubleClicked() {
        let row = tableView.clickedRow
        guard row >= 0, row < entries.count else { return }
        let text = entries[row].text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        let preview = String(text.prefix(50))
        Notifier.show(title: "Copied", body: preview)
    }

    func windowWillClose(_ notification: Notification) {}

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < entries.count, let identifier = tableColumn?.identifier else { return nil }
        let entry = entries[row]
        let text = identifier.rawValue == "time"
            ? Self.dateFormatter.string(from: entry.date)
            : entry.text

        let cellIdentifier = NSUserInterfaceItemIdentifier("cell-\(identifier.rawValue)")
        let textField: NSTextField
        if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField {
            textField = existing
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = cellIdentifier
            textField.lineBreakMode = .byTruncatingTail
        }
        textField.stringValue = text
        return textField
    }
}
