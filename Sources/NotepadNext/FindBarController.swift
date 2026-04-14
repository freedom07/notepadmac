import AppKit
import SearchKit
import CommonKit

public class FindBarController: NSViewController {
    public let searchField = NSTextField()
    public let replaceField = NSTextField()
    public let resultCountLabel = NSTextField(labelWithString: "0 results")
    public let prevButton = NSButton(title: "Prev", target: nil, action: nil)
    public let nextButton = NSButton(title: "Next", target: nil, action: nil)
    public let replaceButton = NSButton(title: "Replace", target: nil, action: nil)
    public let replaceAllButton = NSButton(title: "All", target: nil, action: nil)
    public let regexToggle = NSButton(checkboxWithTitle: ".*", target: nil, action: nil)
    public let caseToggle = NSButton(checkboxWithTitle: "Aa", target: nil, action: nil)
    public let wordToggle = NSButton(checkboxWithTitle: "W", target: nil, action: nil)

    /// "Find All Open Docs" button — searches all open documents for the current pattern.
    public let findAllOpenDocsButton = NSButton(title: "All Docs", target: nil, action: nil)

    /// Callback invoked when the user clicks "Find All Open Docs".
    /// The closure receives the current search pattern and options.
    public var onFindAllOpenDocuments: ((String, SearchOptions) -> Void)?

    /// "Mark All" button — marks all occurrences of the current search pattern.
    public let markAllButton = NSButton(title: "Mark", target: nil, action: nil)

    /// Style picker for selecting which mark style (1-5) to use.
    public let markStylePicker: NSSegmentedControl = {
        let sc = NSSegmentedControl(labels: ["1", "2", "3", "4", "5"], trackingMode: .selectOne, target: nil, action: nil)
        sc.selectedSegment = 0
        return sc
    }()

    public let searchEngine = SearchEngine()
    public let textMarker = TextMarker()
    public weak var editorTextView: NSTextView?
    public var isReplaceVisible = false
    private var currentResults: [SearchResult] = []
    private var currentIndex = 0

    /// The currently selected mark style derived from the segmented control.
    public var selectedMarkStyle: TextMarker.MarkStyle {
        let raw = markStylePicker.selectedSegment + 1
        return TextMarker.MarkStyle(rawValue: raw) ?? .style1
    }

    public override func loadView() {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 60)); v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        searchField.placeholderString = "Find..."; searchField.frame = NSRect(x: 8, y: 30, width: 250, height: 24)
        searchField.target = self; searchField.action = #selector(searchChanged); v.addSubview(searchField)
        prevButton.frame = NSRect(x: 262, y: 30, width: 50, height: 24); prevButton.target = self; prevButton.action = #selector(findPrevious); v.addSubview(prevButton)
        nextButton.frame = NSRect(x: 316, y: 30, width: 50, height: 24); nextButton.target = self; nextButton.action = #selector(findNext); v.addSubview(nextButton)
        resultCountLabel.frame = NSRect(x: 370, y: 30, width: 80, height: 24); v.addSubview(resultCountLabel)
        regexToggle.frame = NSRect(x: 455, y: 30, width: 40, height: 24); v.addSubview(regexToggle)
        caseToggle.frame = NSRect(x: 500, y: 30, width: 40, height: 24); v.addSubview(caseToggle)
        wordToggle.frame = NSRect(x: 545, y: 30, width: 40, height: 24); v.addSubview(wordToggle)
        findAllOpenDocsButton.frame = NSRect(x: 590, y: 30, width: 70, height: 24); findAllOpenDocsButton.bezelStyle = .accessoryBarAction; findAllOpenDocsButton.target = self; findAllOpenDocsButton.action = #selector(findAllOpenDocsAction); v.addSubview(findAllOpenDocsButton)
        replaceField.placeholderString = "Replace..."; replaceField.frame = NSRect(x: 8, y: 4, width: 250, height: 24); v.addSubview(replaceField)
        replaceButton.frame = NSRect(x: 262, y: 4, width: 70, height: 24); replaceButton.target = self; replaceButton.action = #selector(replaceOne); v.addSubview(replaceButton)
        replaceAllButton.frame = NSRect(x: 336, y: 4, width: 50, height: 24); replaceAllButton.target = self; replaceAllButton.action = #selector(doReplaceAll); v.addSubview(replaceAllButton)
        // Mark All button and style picker on replace row
        markAllButton.frame = NSRect(x: 392, y: 4, width: 50, height: 24); markAllButton.target = self; markAllButton.action = #selector(markAllOccurrences); v.addSubview(markAllButton)
        markStylePicker.frame = NSRect(x: 447, y: 4, width: 140, height: 24); v.addSubview(markStylePicker)
        self.view = v
    }
    public func showFindBar() { view.isHidden = false; searchField.becomeFirstResponder() }
    public func hideFindBar() { view.isHidden = true }
    @objc public func findNext() { guard !currentResults.isEmpty else { return }; currentIndex = (currentIndex + 1) % currentResults.count; select(currentResults[currentIndex]); updateResultCount() }
    @objc public func findPrevious() { guard !currentResults.isEmpty else { return }; currentIndex = (currentIndex - 1 + currentResults.count) % currentResults.count; select(currentResults[currentIndex]); updateResultCount() }
    @objc public func replaceOne() { guard let tv = editorTextView, !currentResults.isEmpty else { return }; tv.insertText(replaceField.stringValue, replacementRange: currentResults[currentIndex].range); searchChanged(nil) }
    @objc public func doReplaceAll() { guard let tv = editorTextView else { return }; let r = searchEngine.replaceAll(in: tv.string, pattern: searchField.stringValue, replacement: replaceField.stringValue, options: opts()); let fullRange = NSRange(location: 0, length: (tv.string as NSString).length)
        tv.textStorage?.replaceCharacters(in: fullRange, with: r.newText); resultCountLabel.stringValue = "Replaced \(r.count)"; currentResults = [] }
    @objc public func markAllOccurrences() {
        guard let tv = editorTextView, let layoutManager = tv.layoutManager else { return }
        let pattern = searchField.stringValue
        guard !pattern.isEmpty else { return }
        let count = textMarker.markAll(
            pattern: pattern,
            in: layoutManager,
            textLength: (tv.string as NSString).length,
            style: selectedMarkStyle,
            options: opts()
        )
        resultCountLabel.stringValue = "Marked \(count)"
    }
    @objc public func findAllOpenDocsAction() {
        let pattern = searchField.stringValue
        guard !pattern.isEmpty else { return }
        onFindAllOpenDocuments?(pattern, opts())
    }
    /// Clears all marks across all styles.
    public func clearAllMarks() {
        guard let tv = editorTextView, let layoutManager = tv.layoutManager else { return }
        textMarker.clearAllMarks(in: layoutManager, textLength: (tv.string as NSString).length)
    }
    @objc private func searchChanged(_ sender: Any?) { guard let tv = editorTextView else { return }; let p = searchField.stringValue; guard !p.isEmpty else { currentResults = []; updateResultCount(); return }; currentResults = searchEngine.find(pattern: p, in: tv.string, options: opts()); currentIndex = 0; updateResultCount(); if let f = currentResults.first { select(f) } }
    public func updateResultCount() { resultCountLabel.stringValue = currentResults.isEmpty ? "0 results" : "\(currentIndex + 1) of \(currentResults.count)" }
    private func select(_ r: SearchResult) { editorTextView?.setSelectedRange(r.range); editorTextView?.scrollRangeToVisible(r.range) }
    private func opts() -> SearchOptions { SearchOptions(caseSensitive: caseToggle.state == .on, wholeWord: wordToggle.state == .on, useRegex: regexToggle.state == .on) }
}
