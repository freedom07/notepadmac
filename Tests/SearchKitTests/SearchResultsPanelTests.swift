import XCTest
@testable import SearchKit

@available(macOS 13.0, *)
final class SearchResultsPanelTests: XCTestCase {

    // MARK: - Helpers

    private func makeResult(
        line: Int,
        lineContent: String = "sample line",
        matchedText: String = "sample"
    ) -> SearchResult {
        SearchResult(
            range: NSRange(location: 0, length: matchedText.count),
            lineNumber: line,
            lineContent: lineContent,
            matchedText: matchedText
        )
    }

    private func makeFileSearchResult(
        filename: String,
        matchCount: Int
    ) -> FileSearchResult {
        let matches = (1...matchCount).map { i in
            makeResult(line: i, lineContent: "line \(i) text", matchedText: "text")
        }
        return FileSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            matches: matches
        )
    }

    // MARK: - Initial State

    func testInitialState() {
        let panel = SearchResultsPanel()
        _ = panel.view // trigger loadView

        XCTAssertTrue(panel.resultGroups.isEmpty)
        XCTAssertEqual(panel.totalResultCount, 0)
        XCTAssertEqual(panel.totalFileCount, 0)
    }

    // MARK: - Display Multi-File Results

    func testDisplayMultiFileResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "main.swift", matchCount: 5),
            makeFileSearchResult(filename: "app.swift", matchCount: 3),
        ]

        panel.displayResults(results)

        XCTAssertEqual(panel.resultGroups.count, 2)
        XCTAssertEqual(panel.totalResultCount, 8)
        XCTAssertEqual(panel.totalFileCount, 2)
    }

    func testDisplayMultiFileResultsGroupTitles() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "main.swift", matchCount: 5),
            makeFileSearchResult(filename: "single.swift", matchCount: 1),
        ]

        panel.displayResults(results)

        XCTAssertEqual(panel.resultGroups[0].title, "main.swift (5 hits)")
        XCTAssertEqual(panel.resultGroups[1].title, "single.swift (1 hit)")
    }

    func testDisplayMultiFileResultsPreservesFileURLs() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "test.swift", matchCount: 2),
        ]

        panel.displayResults(results)

        XCTAssertEqual(
            panel.resultGroups[0].fileURL,
            URL(fileURLWithPath: "/tmp/test.swift")
        )
    }

    // MARK: - Display Single-File Results

    func testDisplaySingleFileResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeResult(line: 1, lineContent: "hello world", matchedText: "hello"),
            makeResult(line: 5, lineContent: "hello again", matchedText: "hello"),
        ]

        panel.displayResults(results, title: "Current Document")

        XCTAssertEqual(panel.resultGroups.count, 1)
        XCTAssertEqual(panel.totalResultCount, 2)
        XCTAssertEqual(panel.totalFileCount, 1)
        XCTAssertNil(panel.resultGroups[0].fileURL)
        XCTAssertEqual(panel.resultGroups[0].title, "Current Document (2 hits)")
    }

    func testDisplaySingleResultSingularHit() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeResult(line: 3, lineContent: "only match", matchedText: "only"),
        ]

        panel.displayResults(results, title: "File")

        XCTAssertEqual(panel.resultGroups[0].title, "File (1 hit)")
    }

    // MARK: - Clear Results

    func testClearResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([makeFileSearchResult(filename: "a.swift", matchCount: 3)])
        XCTAssertEqual(panel.totalResultCount, 3)

        panel.clearResults()

        XCTAssertTrue(panel.resultGroups.isEmpty)
        XCTAssertEqual(panel.totalResultCount, 0)
        XCTAssertEqual(panel.totalFileCount, 0)
    }

    // MARK: - Summary Label

    func testSummaryLabelNoResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.updateSummaryLabel()
        XCTAssertEqual(panel.summaryLabel.stringValue, "No results")
    }

    func testSummaryLabelWithResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "a.swift", matchCount: 3),
            makeFileSearchResult(filename: "b.swift", matchCount: 2),
        ]
        panel.displayResults(results)

        XCTAssertEqual(panel.summaryLabel.stringValue, "5 results in 2 files")
    }

    func testSummaryLabelSingularResultSingularFile() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([makeFileSearchResult(filename: "a.swift", matchCount: 1)])

        XCTAssertEqual(panel.summaryLabel.stringValue, "1 result in 1 file")
    }

    // MARK: - Replacing Results

    func testDisplayResultsReplacesExisting() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([makeFileSearchResult(filename: "a.swift", matchCount: 5)])
        XCTAssertEqual(panel.totalResultCount, 5)

        panel.displayResults([makeFileSearchResult(filename: "b.swift", matchCount: 2)])
        XCTAssertEqual(panel.totalResultCount, 2)
        XCTAssertEqual(panel.totalFileCount, 1)
    }

    // MARK: - Empty Results

    func testDisplayEmptyResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([FileSearchResult]())

        XCTAssertTrue(panel.resultGroups.isEmpty)
        XCTAssertEqual(panel.totalResultCount, 0)
    }

    func testDisplayEmptySingleFileResults() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([SearchResult](), title: "Empty")

        XCTAssertEqual(panel.resultGroups.count, 1)
        XCTAssertEqual(panel.totalResultCount, 0)
        XCTAssertEqual(panel.resultGroups[0].title, "Empty (0 hits)")
    }

    // MARK: - Highlight Logic

    func testHighlightedLineContentContainsMatch() {
        let attributed = SearchResultsPanel.highlightedLineContent(
            lineContent: "let x = hello + world",
            matchedText: "hello"
        )

        XCTAssertEqual(attributed.string, "let x = hello + world")

        // Check that the matched range has a yellow background attribute.
        let matchRange = NSRange(location: 8, length: 5) // "hello" starts at index 8
        var effectiveRange = NSRange()
        let bgColor = attributed.attribute(
            .backgroundColor,
            at: matchRange.location,
            effectiveRange: &effectiveRange
        ) as? NSColor

        XCTAssertNotNil(bgColor, "Matched text should have a background color attribute")
    }

    func testHighlightedLineContentNoMatchDoesNotHighlight() {
        let attributed = SearchResultsPanel.highlightedLineContent(
            lineContent: "no match here",
            matchedText: "xyz"
        )

        // Should have no background color attribute.
        var effectiveRange = NSRange()
        let bgColor = attributed.attribute(
            .backgroundColor,
            at: 0,
            effectiveRange: &effectiveRange
        ) as? NSColor

        XCTAssertNil(bgColor, "Non-matching text should not have a background color")
    }

    // MARK: - Outline View Data Source

    func testOutlineViewDataSourceTopLevel() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "a.swift", matchCount: 2),
            makeFileSearchResult(filename: "b.swift", matchCount: 3),
        ]
        panel.displayResults(results)

        let topLevelCount = panel.outlineView(panel.outlineView, numberOfChildrenOfItem: nil)
        XCTAssertEqual(topLevelCount, 2)
    }

    func testOutlineViewDataSourceChildCount() {
        let panel = SearchResultsPanel()
        _ = panel.view

        let results = [
            makeFileSearchResult(filename: "a.swift", matchCount: 4),
        ]
        panel.displayResults(results)

        let groupItem = panel.outlineView(panel.outlineView, child: 0, ofItem: nil)
        let childCount = panel.outlineView(panel.outlineView, numberOfChildrenOfItem: groupItem)
        XCTAssertEqual(childCount, 4)
    }

    func testOutlineViewDataSourceExpandability() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults([makeFileSearchResult(filename: "a.swift", matchCount: 2)])

        let groupItem = panel.outlineView(panel.outlineView, child: 0, ofItem: nil)
        XCTAssertTrue(panel.outlineView(panel.outlineView, isItemExpandable: groupItem))

        let childItem = panel.outlineView(panel.outlineView, child: 0, ofItem: groupItem)
        XCTAssertFalse(panel.outlineView(panel.outlineView, isItemExpandable: childItem))
    }

    // MARK: - Delegate Callback

    func testDelegateCalled() {
        final class MockDelegate: SearchResultsPanelDelegate {
            var selectedResult: SearchResult?
            var selectedFileURL: URL?
            var callCount = 0

            func searchResultsPanel(
                _ panel: SearchResultsPanel,
                didSelectResult result: SearchResult,
                inFile url: URL?
            ) {
                selectedResult = result
                selectedFileURL = url
                callCount += 1
            }
        }

        let panel = SearchResultsPanel()
        _ = panel.view
        let mockDelegate = MockDelegate()
        panel.delegate = mockDelegate

        let fileResult = makeFileSearchResult(filename: "test.swift", matchCount: 1)
        panel.displayResults([fileResult])

        // Verify the delegate is set (actual click testing requires UI interaction).
        XCTAssertNotNil(panel.delegate)
        XCTAssertEqual(mockDelegate.callCount, 0)
    }

    // MARK: - Multiple Display Calls

    func testMultipleDisplayCallsReplaceData() {
        let panel = SearchResultsPanel()
        _ = panel.view

        panel.displayResults(
            [makeResult(line: 1)],
            title: "First"
        )
        XCTAssertEqual(panel.resultGroups[0].title, "First (1 hit)")

        panel.displayResults(
            [makeResult(line: 1), makeResult(line: 2)],
            title: "Second"
        )
        XCTAssertEqual(panel.resultGroups.count, 1)
        XCTAssertEqual(panel.resultGroups[0].title, "Second (2 hits)")
    }
}
