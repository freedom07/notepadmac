// DocumentListPanel.swift
// EditorKit — NotepadNext
//
// A side panel that displays all open tabs in an NSTableView with columns
// for filename, path, modified status, and language. Supports click-to-activate,
// sortable column headers, and auto-refresh.

import AppKit

// MARK: - DocumentListPanelDelegate

/// Delegate protocol for handling tab selection in the document list.
@available(macOS 13.0, *)
public protocol DocumentListPanelDelegate: AnyObject {
    /// Called when the user clicks a document in the list.
    func documentList(_ panel: DocumentListPanel, didSelectTabAt index: Int)
}

// MARK: - DocumentEntry

/// A lightweight data model representing a single document entry in the list.
public struct DocumentEntry: Equatable {
    /// Display filename for the document.
    public let filename: String
    /// Full file path, or "Untitled" for unsaved documents.
    public let path: String
    /// Whether the document has unsaved modifications.
    public let isModified: Bool
    /// The detected language name (e.g. "Swift", "Python", "Plain Text").
    public let language: String

    public init(filename: String, path: String, isModified: Bool, language: String) {
        self.filename = filename
        self.path = path
        self.isModified = isModified
        self.language = language
    }
}

// MARK: - DocumentListPanel

/// A view controller that displays all open tabs in a multi-column table view.
///
/// Columns: Filename, Path, Modified (indicator), Language.
/// Click a row to activate the corresponding tab via the delegate.
/// Click column headers to sort by that column.
@available(macOS 13.0, *)
public class DocumentListPanel: NSViewController {

    // MARK: - Public Properties

    /// Delegate for handling document selection.
    public weak var delegate: DocumentListPanelDelegate?

    /// The current list of document entries. Setting this refreshes the table.
    public var entries: [DocumentEntry] = [] {
        didSet {
            applySort()
        }
    }

    // MARK: - Private Properties

    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    /// Currently displayed entries (after sorting).
    internal var displayedEntries: [DocumentEntry] = []

    /// Maps displayed index back to original entries index.
    private var sortedIndices: [Int] = []

    /// Current sort column identifier and ascending flag.
    internal var sortColumn: String?
    internal var sortAscending: Bool = true

    // MARK: - Column Identifiers

    private static let filenameColumnID = NSUserInterfaceItemIdentifier("FilenameColumn")
    private static let pathColumnID = NSUserInterfaceItemIdentifier("PathColumn")
    private static let modifiedColumnID = NSUserInterfaceItemIdentifier("ModifiedColumn")
    private static let languageColumnID = NSUserInterfaceItemIdentifier("LanguageColumn")

    // MARK: - Lifecycle

    public override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        setupTableView(in: container)

        self.view = container
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Documents"
    }

    // MARK: - Setup

    private func setupTableView(in container: NSView) {
        // Filename column
        let filenameColumn = NSTableColumn(identifier: DocumentListPanel.filenameColumnID)
        filenameColumn.title = "Filename"
        filenameColumn.minWidth = 80
        filenameColumn.resizingMask = .autoresizingMask
        filenameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "filename", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        tableView.addTableColumn(filenameColumn)

        // Path column
        let pathColumn = NSTableColumn(identifier: DocumentListPanel.pathColumnID)
        pathColumn.title = "Path"
        pathColumn.minWidth = 100
        pathColumn.resizingMask = .autoresizingMask
        pathColumn.sortDescriptorPrototype = NSSortDescriptor(key: "path", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        tableView.addTableColumn(pathColumn)

        // Modified column
        let modifiedColumn = NSTableColumn(identifier: DocumentListPanel.modifiedColumnID)
        modifiedColumn.title = "Modified"
        modifiedColumn.minWidth = 50
        modifiedColumn.maxWidth = 70
        modifiedColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(modifiedColumn)

        // Language column
        let languageColumn = NSTableColumn(identifier: DocumentListPanel.languageColumnID)
        languageColumn.title = "Language"
        languageColumn.minWidth = 60
        languageColumn.resizingMask = .autoresizingMask
        languageColumn.sortDescriptorPrototype = NSSortDescriptor(key: "language", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        tableView.addTableColumn(languageColumn)

        // Configure table view
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 20
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.action = #selector(tableViewClicked(_:))
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
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func tableViewClicked(_ sender: NSTableView) {
        let row = sender.clickedRow
        guard row >= 0, row < displayedEntries.count else { return }
        let originalIndex = sortedIndices[row]
        delegate?.documentList(self, didSelectTabAt: originalIndex)
    }

    // MARK: - Refresh

    /// Forces a reload of the table view with the current entries.
    public func refresh() {
        applySort()
    }

    // MARK: - Sorting

    /// Applies the current sort and reloads the table.
    internal func applySort() {
        var indexed = entries.enumerated().map { ($0.offset, $0.element) }

        if let col = sortColumn {
            indexed.sort { lhs, rhs in
                let result: ComparisonResult
                switch col {
                case "FilenameColumn":
                    result = lhs.1.filename.localizedCaseInsensitiveCompare(rhs.1.filename)
                case "PathColumn":
                    result = lhs.1.path.localizedCaseInsensitiveCompare(rhs.1.path)
                case "LanguageColumn":
                    result = lhs.1.language.localizedCaseInsensitiveCompare(rhs.1.language)
                default:
                    result = .orderedSame
                }
                return sortAscending ? result == .orderedAscending : result == .orderedDescending
            }
        }

        sortedIndices = indexed.map { $0.0 }
        displayedEntries = indexed.map { $0.1 }
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

@available(macOS 13.0, *)
extension DocumentListPanel: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedEntries.count
    }

    public func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else {
            sortColumn = nil
            applySort()
            return
        }

        // Map sort key to column ID
        switch descriptor.key {
        case "filename":
            sortColumn = "FilenameColumn"
        case "path":
            sortColumn = "PathColumn"
        case "language":
            sortColumn = "LanguageColumn"
        default:
            sortColumn = nil
        }
        sortAscending = descriptor.ascending
        applySort()
    }
}

// MARK: - NSTableViewDelegate

@available(macOS 13.0, *)
extension DocumentListPanel: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayedEntries.count, let columnID = tableColumn?.identifier else { return nil }
        let entry = displayedEntries[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("DocumentListCell_\(columnID.rawValue)")
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

        switch columnID {
        case DocumentListPanel.filenameColumnID:
            cell.textField?.stringValue = entry.filename
        case DocumentListPanel.pathColumnID:
            cell.textField?.stringValue = entry.path
        case DocumentListPanel.modifiedColumnID:
            // Use a filled circle indicator for modified documents
            cell.textField?.stringValue = entry.isModified ? "\u{25CF}" : ""
            cell.textField?.alignment = .center
        case DocumentListPanel.languageColumnID:
            cell.textField?.stringValue = entry.language
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }
}
