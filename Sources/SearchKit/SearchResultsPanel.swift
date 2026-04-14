// SearchResultsPanel.swift
// SearchKit — NotepadNext
//
// A panel that displays search results in an outline view with
// file-level grouping and per-match detail rows.

import AppKit
import Foundation

// MARK: - SearchResultsPanelDelegate

/// Delegate protocol for handling user interactions in the search results panel.
@available(macOS 13.0, *)
public protocol SearchResultsPanelDelegate: AnyObject {
    /// Called when the user clicks a search result row.
    ///
    /// - Parameters:
    ///   - panel: The panel that sent the event.
    ///   - result: The search result that was selected.
    ///   - url: The file URL containing the result, or `nil` for single-file results.
    func searchResultsPanel(
        _ panel: SearchResultsPanel,
        didSelectResult result: SearchResult,
        inFile url: URL?
    )
}

// MARK: - SearchResultsPanel

/// A view controller that displays search results in a two-level outline view.
///
/// Level 1 (group headers) show file names with match counts.
/// Level 2 (result rows) show line numbers and line content with highlighted matches.
///
/// Usage:
/// ```swift
/// let panel = SearchResultsPanel()
/// panel.delegate = self
/// panel.displayResults(fileSearchResults)
/// ```
@available(macOS 13.0, *)
public final class SearchResultsPanel: NSViewController {

    // MARK: - Data Model

    /// Represents a group of results from a single file.
    public struct ResultGroup {
        /// The file URL, or `nil` for single-file results.
        public let fileURL: URL?
        /// The display title for the group header.
        public let title: String
        /// The individual search results within this group.
        public let results: [SearchResult]
    }

    // MARK: - Properties

    /// The delegate that receives selection events.
    public weak var delegate: SearchResultsPanelDelegate?

    /// The current result groups being displayed.
    public private(set) var resultGroups: [ResultGroup] = []

    /// The total number of individual results across all groups.
    public var totalResultCount: Int {
        resultGroups.reduce(0) { $0 + $1.results.count }
    }

    /// The total number of file groups.
    public var totalFileCount: Int {
        resultGroups.count
    }

    // MARK: - Subviews

    private let scrollView = NSScrollView()
    let outlineView = NSOutlineView()
    let summaryLabel = NSTextField(labelWithString: "")
    let clearButton = NSButton(title: "Clear Results", target: nil, action: nil)
    let collapseAllButton = NSButton(title: "Collapse All", target: nil, action: nil)
    let expandAllButton = NSButton(title: "Expand All", target: nil, action: nil)

    // MARK: - Column Identifiers

    private static let lineNumberColumnID = NSUserInterfaceItemIdentifier("lineNumber")
    private static let contentColumnID = NSUserInterfaceItemIdentifier("content")

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
        updateSummaryLabel()
    }

    // MARK: - Setup

    private func setupToolbar(in container: NSView) {
        let toolbar = NSStackView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

        summaryLabel.font = NSFont.systemFont(ofSize: 11)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        clearButton.bezelStyle = .accessoryBarAction
        clearButton.font = NSFont.systemFont(ofSize: 11)
        clearButton.target = self
        clearButton.action = #selector(clearResultsAction)

        collapseAllButton.bezelStyle = .accessoryBarAction
        collapseAllButton.font = NSFont.systemFont(ofSize: 11)
        collapseAllButton.target = self
        collapseAllButton.action = #selector(collapseAllAction)

        expandAllButton.bezelStyle = .accessoryBarAction
        expandAllButton.font = NSFont.systemFont(ofSize: 11)
        expandAllButton.target = self
        expandAllButton.action = #selector(expandAllAction)

        toolbar.addArrangedSubview(summaryLabel)
        toolbar.addArrangedSubview(collapseAllButton)
        toolbar.addArrangedSubview(expandAllButton)
        toolbar.addArrangedSubview(clearButton)

        container.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: container.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    private func setupOutlineView(in container: NSView) {
        let lineNumberColumn = NSTableColumn(identifier: Self.lineNumberColumnID)
        lineNumberColumn.title = "Line"
        lineNumberColumn.width = 50
        lineNumberColumn.minWidth = 40
        lineNumberColumn.maxWidth = 80

        let contentColumn = NSTableColumn(identifier: Self.contentColumnID)
        contentColumn.title = "Content"
        contentColumn.minWidth = 200

        outlineView.addTableColumn(lineNumberColumn)
        outlineView.addTableColumn(contentColumn)
        outlineView.outlineTableColumn = contentColumn
        outlineView.headerView = nil
        outlineView.rowHeight = 20
        outlineView.indentationPerLevel = 16
        outlineView.selectionHighlightStyle = .regular
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(outlineViewClicked)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.documentView = outlineView

        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    // MARK: - Public API

    /// Displays multi-file search results grouped by file.
    ///
    /// - Parameter results: An array of `FileSearchResult` values, one per file.
    public func displayResults(_ results: [FileSearchResult]) {
        resultGroups = results.map { fileResult in
            let filename = fileResult.fileURL.lastPathComponent
            let count = fileResult.matches.count
            let hitWord = count == 1 ? "hit" : "hits"
            return ResultGroup(
                fileURL: fileResult.fileURL,
                title: "\(filename) (\(count) \(hitWord))",
                results: fileResult.matches
            )
        }
        reloadAndExpand()
    }

    /// Displays multi-document search results grouped by document title.
    ///
    /// Each tuple represents one document: `(title, fileURL, matches)`.
    /// Documents with zero matches should typically be filtered out before calling
    /// this method, but they are silently skipped if present.
    ///
    /// - Parameter groups: An array of `(String, URL?, [SearchResult])` tuples.
    public func displayResultGroups(_ groups: [(String, URL?, [SearchResult])]) {
        resultGroups = groups.compactMap { (title, url, matches) in
            guard !matches.isEmpty else { return nil }
            let count = matches.count
            let hitWord = count == 1 ? "hit" : "hits"
            return ResultGroup(
                fileURL: url,
                title: "\(title) (\(count) \(hitWord))",
                results: matches
            )
        }
        reloadAndExpand()
    }

    /// Displays single-file search results under a custom title.
    ///
    /// - Parameters:
    ///   - results: The search results to display.
    ///   - title: The header title for the result group.
    public func displayResults(_ results: [SearchResult], title: String) {
        let count = results.count
        let hitWord = count == 1 ? "hit" : "hits"
        resultGroups = [
            ResultGroup(
                fileURL: nil,
                title: "\(title) (\(count) \(hitWord))",
                results: results
            )
        ]
        reloadAndExpand()
    }

    /// Removes all displayed results.
    public func clearResults() {
        resultGroups = []
        outlineView.reloadData()
        updateSummaryLabel()
    }

    // MARK: - Actions

    @objc private func clearResultsAction() {
        clearResults()
    }

    @objc private func collapseAllAction() {
        for index in 0..<resultGroups.count {
            let groupWrapper = GroupWrapper(index: index, group: resultGroups[index])
            outlineView.collapseItem(groupWrapper)
        }
    }

    @objc private func expandAllAction() {
        for index in 0..<resultGroups.count {
            let groupWrapper = GroupWrapper(index: index, group: resultGroups[index])
            outlineView.expandItem(groupWrapper)
        }
    }

    @objc private func outlineViewClicked() {
        let row = outlineView.clickedRow
        guard row >= 0 else { return }

        let item = outlineView.item(atRow: row)
        if let resultWrapper = item as? ResultWrapper {
            let group = resultGroups[resultWrapper.groupIndex]
            delegate?.searchResultsPanel(
                self,
                didSelectResult: resultWrapper.result,
                inFile: group.fileURL
            )
        }
    }

    // MARK: - Private Helpers

    private func reloadAndExpand() {
        outlineView.reloadData()
        for index in 0..<resultGroups.count {
            let groupWrapper = GroupWrapper(index: index, group: resultGroups[index])
            outlineView.expandItem(groupWrapper)
        }
        updateSummaryLabel()
    }

    func updateSummaryLabel() {
        let resultCount = totalResultCount
        let fileCount = totalFileCount
        if resultCount == 0 {
            summaryLabel.stringValue = "No results"
        } else {
            let resultWord = resultCount == 1 ? "result" : "results"
            let fileWord = fileCount == 1 ? "file" : "files"
            summaryLabel.stringValue = "\(resultCount) \(resultWord) in \(fileCount) \(fileWord)"
        }
    }

    // MARK: - Attributed String Helpers

    /// Creates an attributed string for a result row with the matched text
    /// highlighted in a yellow background.
    static func highlightedLineContent(
        lineContent: String,
        matchedText: String
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            string: lineContent,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        )

        // Highlight all occurrences of the matched text in the line.
        let nsLine = lineContent as NSString
        var searchStart = 0
        while searchStart < nsLine.length {
            let range = nsLine.range(
                of: matchedText,
                options: [],
                range: NSRange(location: searchStart, length: nsLine.length - searchStart)
            )
            guard range.location != NSNotFound else { break }
            attributed.addAttribute(
                .backgroundColor,
                value: NSColor.yellow.withAlphaComponent(0.4),
                range: range
            )
            searchStart = range.location + range.length
        }

        return attributed
    }
}

// MARK: - Outline View Wrapper Objects

/// Wrapper object for a group header row in the outline view.
/// Uses index-based equality so the outline view can identify items.
@available(macOS 13.0, *)
private final class GroupWrapper: NSObject {
    let index: Int
    let group: SearchResultsPanel.ResultGroup

    init(index: Int, group: SearchResultsPanel.ResultGroup) {
        self.index = index
        self.group = group
    }

    override var hash: Int { index }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? GroupWrapper else { return false }
        return index == other.index
    }
}

/// Wrapper object for a result row in the outline view.
@available(macOS 13.0, *)
private final class ResultWrapper: NSObject {
    let groupIndex: Int
    let resultIndex: Int
    let result: SearchResult

    init(groupIndex: Int, resultIndex: Int, result: SearchResult) {
        self.groupIndex = groupIndex
        self.resultIndex = resultIndex
        self.result = result
    }

    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(groupIndex)
        hasher.combine(resultIndex)
        return hasher.finalize()
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ResultWrapper else { return false }
        return groupIndex == other.groupIndex && resultIndex == other.resultIndex
    }
}

// MARK: - NSOutlineViewDataSource

@available(macOS 13.0, *)
extension SearchResultsPanel: NSOutlineViewDataSource {

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            // Top level: number of file groups.
            return resultGroups.count
        }
        if let groupWrapper = item as? GroupWrapper {
            return groupWrapper.group.results.count
        }
        return 0
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return GroupWrapper(index: index, group: resultGroups[index])
        }
        if let groupWrapper = item as? GroupWrapper {
            return ResultWrapper(
                groupIndex: groupWrapper.index,
                resultIndex: index,
                result: groupWrapper.group.results[index]
            )
        }
        fatalError("Unexpected outline view item type")
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is GroupWrapper
    }
}

// MARK: - NSOutlineViewDelegate

@available(macOS 13.0, *)
extension SearchResultsPanel: NSOutlineViewDelegate {

    public func outlineView(
        _ outlineView: NSOutlineView,
        viewFor tableColumn: NSTableColumn?,
        item: Any
    ) -> NSView? {
        let cellID = NSUserInterfaceItemIdentifier("SearchResultCell")

        if let groupWrapper = item as? GroupWrapper {
            // Group header row — show the title in the content column only.
            guard tableColumn?.identifier == Self.contentColumnID else {
                return nil
            }

            let cell = outlineView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField
                ?? NSTextField(labelWithString: "")
            cell.identifier = cellID
            cell.stringValue = groupWrapper.group.title
            cell.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            cell.textColor = .labelColor
            cell.lineBreakMode = .byTruncatingTail
            return cell
        }

        if let resultWrapper = item as? ResultWrapper {
            let result = resultWrapper.result

            if tableColumn?.identifier == Self.lineNumberColumnID {
                let cell = outlineView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField
                    ?? NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.stringValue = "\(result.lineNumber)"
                cell.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                cell.textColor = .secondaryLabelColor
                cell.alignment = .right
                cell.lineBreakMode = .byClipping
                return cell
            }

            if tableColumn?.identifier == Self.contentColumnID {
                let cell = outlineView.makeView(withIdentifier: cellID, owner: nil) as? NSTextField
                    ?? NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.attributedStringValue = Self.highlightedLineContent(
                    lineContent: result.lineContent,
                    matchedText: result.matchedText
                )
                cell.lineBreakMode = .byTruncatingTail
                return cell
            }
        }

        return nil
    }

    public func outlineView(
        _ outlineView: NSOutlineView,
        isGroupItem item: Any
    ) -> Bool {
        return item is GroupWrapper
    }
}
