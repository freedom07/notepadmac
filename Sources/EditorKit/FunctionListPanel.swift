// FunctionListPanel.swift
// EditorKit — NotepadNext
//
// A side panel that displays an outline of functions, classes, and other symbols
// parsed from the current document. Supports search/filter, click-to-navigate,
// sort toggle, and auto-refresh with debouncing.

import AppKit
import SyntaxKit
import CommonKit

// MARK: - FunctionListPanelDelegate

/// Delegate protocol for handling symbol selection in the function list.
@available(macOS 13.0, *)
public protocol FunctionListPanelDelegate: AnyObject {
    /// Called when the user clicks a symbol in the function list.
    func functionList(_ panel: FunctionListPanel, didSelectSymbol symbol: SymbolInfo)
}

// MARK: - FunctionListPanel

/// A view controller that displays an NSOutlineView of parsed code symbols
/// (functions, classes, structs, etc.) with search filtering and sort toggle.
@available(macOS 13.0, *)
public class FunctionListPanel: NSViewController {

    // MARK: - Public Properties

    /// Delegate for handling symbol selection.
    public weak var delegate: FunctionListPanelDelegate?

    /// The language identifier used for parsing (e.g., "swift", "python").
    public var languageId: String = "" {
        didSet {
            if languageId != oldValue {
                refreshSymbols()
            }
        }
    }

    /// The current source text to parse symbols from.
    public var sourceText: String = "" {
        didSet {
            parseDebouncer.debounce { [weak self] in
                self?.refreshSymbols()
            }
        }
    }

    /// Whether symbols are sorted alphabetically. When false, symbols are
    /// displayed in their order of appearance.
    public var isSortedAlphabetically: Bool = false {
        didSet {
            applyFilter()
        }
    }

    // MARK: - Private Properties

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let searchField = NSSearchField()
    private let sortButton = NSButton()
    private let parseDebouncer = Debouncer(delay: 0.5)

    /// All parsed symbols (unfiltered).
    private var allSymbols: [SymbolInfo] = []

    /// Currently displayed symbols (after filtering and sorting).
    private var displayedSymbols: [SymbolInfo] = []

    // MARK: - Lifecycle

    public override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        setupToolbar(in: container)
        setupOutlineView(in: container)

        self.view = container
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Functions"
    }

    // MARK: - Setup

    private func setupToolbar(in container: NSView) {
        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter symbols..."
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.controlSize = .small
        searchField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        container.addSubview(searchField)

        // Sort button
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        sortButton.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Sort")
        sortButton.bezelStyle = .accessoryBarAction
        sortButton.setButtonType(.toggle)
        sortButton.target = self
        sortButton.action = #selector(sortButtonClicked(_:))
        sortButton.toolTip = "Toggle alphabetical sorting"
        sortButton.controlSize = .small
        container.addSubview(sortButton)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            searchField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            searchField.trailingAnchor.constraint(equalTo: sortButton.leadingAnchor, constant: -4),
            searchField.heightAnchor.constraint(equalToConstant: 22),

            sortButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            sortButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            sortButton.widthAnchor.constraint(equalToConstant: 28),
            sortButton.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    private func setupOutlineView(in container: NSView) {
        // Configure outline view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SymbolColumn"))
        column.title = "Symbol"
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowHeight = 20
        outlineView.indentationPerLevel = 16
        outlineView.autoresizesOutlineColumn = true
        outlineView.target = self
        outlineView.action = #selector(outlineViewClicked(_:))
        outlineView.selectionHighlightStyle = .regular

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        applyFilter()
    }

    @objc private func sortButtonClicked(_ sender: NSButton) {
        isSortedAlphabetically = sender.state == .on
    }

    @objc private func outlineViewClicked(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0, let item = sender.item(atRow: row) as? SymbolInfo else { return }
        delegate?.functionList(self, didSelectSymbol: item)
    }

    // MARK: - Parsing & Display

    /// Re-parses the source text and updates the display.
    public func refreshSymbols() {
        guard !languageId.isEmpty else {
            allSymbols = []
            displayedSymbols = []
            outlineView.reloadData()
            return
        }

        allSymbols = FunctionListParser.parse(text: sourceText, languageId: languageId)
        applyFilter()
    }

    /// Applies the current search filter and sort order, then reloads the outline view.
    private func applyFilter() {
        let query = searchField.stringValue.lowercased()
        var symbols = allSymbols

        if !query.isEmpty {
            symbols = filterSymbols(symbols, query: query)
        }

        if isSortedAlphabetically {
            symbols = sortSymbols(symbols)
        }

        displayedSymbols = symbols
        outlineView.reloadData()
        outlineView.expandItem(nil, expandChildren: true)
    }

    /// Recursively filters symbols whose name contains the query.
    private func filterSymbols(_ symbols: [SymbolInfo], query: String) -> [SymbolInfo] {
        var result: [SymbolInfo] = []

        for symbol in symbols {
            let filteredChildren = filterSymbols(symbol.children, query: query)
            let nameMatches = symbol.name.lowercased().contains(query)

            if nameMatches || !filteredChildren.isEmpty {
                let filtered = SymbolInfo(
                    name: symbol.name,
                    kind: symbol.kind,
                    lineNumber: symbol.lineNumber,
                    children: nameMatches ? symbol.children : filteredChildren
                )
                result.append(filtered)
            }
        }

        return result
    }

    /// Recursively sorts symbols alphabetically by name.
    private func sortSymbols(_ symbols: [SymbolInfo]) -> [SymbolInfo] {
        symbols.map { symbol in
            SymbolInfo(
                name: symbol.name,
                kind: symbol.kind,
                lineNumber: symbol.lineNumber,
                children: sortSymbols(symbol.children)
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Symbol Icon

    /// Returns an SF Symbol name appropriate for the given symbol kind.
    private func iconName(for kind: SymbolKind) -> String {
        switch kind {
        case .function: return "function"
        case .method:   return "m.square"
        case .class_:   return "c.square"
        case .struct_:  return "s.square"
        case .enum_:    return "e.square"
        case .property: return "p.square"
        case .protocol_: return "p.circle"
        }
    }

    /// Returns a tint color for the given symbol kind.
    private func iconColor(for kind: SymbolKind) -> NSColor {
        switch kind {
        case .function, .method: return .systemBlue
        case .class_:            return .systemPurple
        case .struct_:           return .systemGreen
        case .enum_:             return .systemOrange
        case .property:          return .systemTeal
        case .protocol_:         return .systemPink
        }
    }
}

// MARK: - NSOutlineViewDataSource

@available(macOS 13.0, *)
extension FunctionListPanel: NSOutlineViewDataSource {

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return displayedSymbols.count
        }
        if let symbol = item as? SymbolInfo {
            return symbol.children.count
        }
        return 0
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return displayedSymbols[index]
        }
        if let symbol = item as? SymbolInfo {
            return symbol.children[index]
        }
        return SymbolInfo(name: "", kind: .function, lineNumber: 0)
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let symbol = item as? SymbolInfo {
            return !symbol.children.isEmpty
        }
        return false
    }
}

// MARK: - NSOutlineViewDelegate

@available(macOS 13.0, *)
extension FunctionListPanel: NSOutlineViewDelegate {

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let symbol = item as? SymbolInfo else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("SymbolCell")
        let cellView: NSTableCellView

        if let existing = outlineView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            cellView = existing
        } else {
            cellView = NSTableCellView()
            cellView.identifier = identifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(imageView)
            cellView.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 14),
                imageView.heightAnchor.constraint(equalToConstant: 14),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }

        cellView.textField?.stringValue = symbol.name

        let symbolName = iconName(for: symbol.kind)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbol.kind.rawValue) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            cellView.imageView?.image = image.withSymbolConfiguration(config)
            cellView.imageView?.contentTintColor = iconColor(for: symbol.kind)
        }

        return cellView
    }
}
