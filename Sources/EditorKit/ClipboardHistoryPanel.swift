// ClipboardHistoryPanel.swift
// EditorKit — NotepadNext
//
// A side panel that monitors NSPasteboard.general and shows the history
// of clipboard entries. Supports double-click to paste at cursor, clear
// history, and a maximum of 50 entries.

import AppKit

// MARK: - ClipboardHistoryPanelDelegate

/// Delegate protocol for handling clipboard entry selection.
@available(macOS 13.0, *)
public protocol ClipboardHistoryPanelDelegate: AnyObject {
    /// Called when the user double-clicks a clipboard entry.
    func clipboardHistory(_ panel: ClipboardHistoryPanel, didSelectEntry text: String)
}

// MARK: - ClipboardEntry

/// A single entry in the clipboard history.
public struct ClipboardEntry: Equatable {
    /// The full text content of the clipboard entry.
    public let text: String
    /// A truncated preview (first 100 characters).
    public var preview: String {
        if text.count <= 100 {
            return text.replacingOccurrences(of: "\n", with: " ")
        }
        let truncated = String(text.prefix(100))
        return truncated.replacingOccurrences(of: "\n", with: " ") + "\u{2026}"
    }
    /// The timestamp when this entry was captured.
    public let timestamp: Date

    public init(text: String, timestamp: Date = Date()) {
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - ClipboardHistoryStorage

/// In-memory storage for clipboard history entries with a configurable maximum.
public final class ClipboardHistoryStorage {
    /// Maximum number of entries to store.
    public let maxEntries: Int

    /// The current entries, newest first.
    public private(set) var entries: [ClipboardEntry] = []

    public init(maxEntries: Int = 50) {
        self.maxEntries = maxEntries
    }

    /// Adds an entry to the front of the list if it differs from the most recent.
    /// Trims the list to `maxEntries` if needed.
    /// Returns `true` if the entry was actually added.
    @discardableResult
    public func addEntry(_ text: String) -> Bool {
        // Don't add empty strings or duplicates of the most recent
        guard !text.isEmpty else { return false }
        if let latest = entries.first, latest.text == text {
            return false
        }
        let entry = ClipboardEntry(text: text, timestamp: Date())
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        return true
    }

    /// Removes all entries.
    public func clear() {
        entries.removeAll()
    }
}

// MARK: - ClipboardHistoryPanel

/// A view controller that displays clipboard history in an NSTableView.
///
/// Polls `NSPasteboard.general` every 1 second for changes using a Timer.
/// Stores the last 50 entries in memory. Double-click an entry to paste
/// at the cursor via the delegate. A "Clear History" button clears all entries.
@available(macOS 13.0, *)
public class ClipboardHistoryPanel: NSViewController {

    // MARK: - Public Properties

    /// Delegate for handling clipboard entry selection.
    public weak var delegate: ClipboardHistoryPanelDelegate?

    /// The storage backing the clipboard history.
    public let storage: ClipboardHistoryStorage

    // MARK: - Private Properties

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let clearButton = NSButton()
    private var pollTimer: Timer?
    private var lastChangeCount: Int = 0

    // MARK: - Column Identifiers

    private static let previewColumnID = NSUserInterfaceItemIdentifier("PreviewColumn")

    // MARK: - Initialization

    public init(storage: ClipboardHistoryStorage = ClipboardHistoryStorage()) {
        self.storage = storage
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Lifecycle

    public override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        setupClearButton(in: container)
        setupTableView(in: container)

        self.view = container
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Clipboard"
        lastChangeCount = NSPasteboard.general.changeCount
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        startPolling()
    }

    public override func viewDidDisappear() {
        super.viewDidDisappear()
        stopPolling()
    }

    // MARK: - Setup

    private func setupClearButton(in container: NSView) {
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.title = "Clear History"
        clearButton.bezelStyle = .accessoryBarAction
        clearButton.controlSize = .small
        clearButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        clearButton.target = self
        clearButton.action = #selector(clearHistoryClicked(_:))
        container.addSubview(clearButton)

        NSLayoutConstraint.activate([
            clearButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            clearButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            clearButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    private func setupTableView(in container: NSView) {
        // Preview column
        let column = NSTableColumn(identifier: ClipboardHistoryPanel.previewColumnID)
        column.title = "Clipboard Entry"
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        // Configure table view
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.selectionHighlightStyle = .regular

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: clearButton.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func clearHistoryClicked(_ sender: NSButton) {
        storage.clear()
        tableView.reloadData()
    }

    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < storage.entries.count else { return }
        let entry = storage.entries[row]
        delegate?.clipboardHistory(self, didSelectEntry: entry.text)
    }

    // MARK: - Clipboard Polling

    /// Starts the 1-second poll timer for clipboard changes.
    public func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    /// Stops the poll timer.
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// Checks the general pasteboard for new content.
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if let text = pasteboard.string(forType: .string) {
            if storage.addEntry(text) {
                tableView.reloadData()
            }
        }
    }
}

// MARK: - NSTableViewDataSource

@available(macOS 13.0, *)
extension ClipboardHistoryPanel: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return storage.entries.count
    }
}

// MARK: - NSTableViewDelegate

@available(macOS 13.0, *)
extension ClipboardHistoryPanel: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < storage.entries.count else { return nil }
        let entry = storage.entries[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipboardHistoryCell")
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = entry.preview
        cell.toolTip = entry.text

        return cell
    }
}
