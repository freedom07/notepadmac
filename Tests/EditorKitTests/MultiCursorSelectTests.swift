import XCTest
import AppKit
@testable import EditorKit

// MARK: - MultiCursorSelectTests

/// Tests for the occurrence-selection methods on ``MultiCursorController``:
/// `selectAllOccurrences`, `selectNextOccurrence`, `skipAndSelectNext`,
/// and `undoLastSelection`.
@available(macOS 13.0, *)
final class MultiCursorSelectTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a minimal NSTextView pre-populated with the given text and
    /// an optional initial selection range.
    private func makeTextView(
        _ text: String,
        selectedRange: NSRange? = nil
    ) -> NSTextView {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 1000, height: 1000))
        layoutManager.addTextContainer(textContainer)
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 1000, height: 500), textContainer: textContainer)
        if let range = selectedRange {
            tv.setSelectedRange(range)
        }
        return tv
    }

    // MARK: - selectAllOccurrences

    func testSelectAllOccurrences_withSelection() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv)

        XCTAssertEqual(controller.cursors.count, 3, "Should find 3 occurrences of 'foo'")

        let selections = controller.cursors.compactMap { $0.selection }
        XCTAssertEqual(selections.count, 3, "All cursors should have selections")

        let locations = selections.map { $0.location }.sorted()
        XCTAssertEqual(locations, [0, 8, 16], "Occurrences should be at offsets 0, 8, 16")

        for sel in selections {
            XCTAssertEqual(sel.length, 3, "Each occurrence of 'foo' has length 3")
        }
    }

    func testSelectAllOccurrences_caseInsensitive() {
        let text = "Hello hello HELLO"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 5))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, caseSensitive: false, wholeWord: true)

        XCTAssertEqual(controller.cursors.count, 3, "Case-insensitive should match all three")
    }

    func testSelectAllOccurrences_caseSensitive() {
        let text = "Hello hello HELLO"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 5))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, caseSensitive: true, wholeWord: true)

        XCTAssertEqual(controller.cursors.count, 1, "Case-sensitive should match only 'Hello'")
    }

    func testSelectAllOccurrences_singleOccurrence() {
        let tv = makeTextView("abc def ghi", selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, wholeWord: true)

        XCTAssertEqual(controller.cursors.count, 1, "Only one occurrence of 'abc'")
    }

    func testSelectAllOccurrences_wholeWordFalse() {
        let text = "testing test tested"
        let tv = makeTextView(text, selectedRange: NSRange(location: 8, length: 4))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, wholeWord: false)

        XCTAssertEqual(controller.cursors.count, 3, "Without wholeWord, 'test' matches inside other words")
    }

    func testSelectAllOccurrences_wholeWordTrue() {
        let text = "testing test tested"
        let tv = makeTextView(text, selectedRange: NSRange(location: 8, length: 4))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, wholeWord: true)

        XCTAssertEqual(controller.cursors.count, 1, "With wholeWord, only standalone 'test' matches")
    }

    func testSelectAllOccurrences_emptyText() {
        let tv = makeTextView("")
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv)

        XCTAssertTrue(controller.cursors.isEmpty || controller.cursors.count <= 1)
    }

    func testSelectAllOccurrences_specialRegexChars() {
        let text = "a+b a+b c+d"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv, wholeWord: false)

        XCTAssertEqual(controller.cursors.count, 2, "Should handle regex special chars by escaping them")
    }

    // MARK: - selectNextOccurrence

    func testSelectNextOccurrence_firstCall() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])

        controller.selectNextOccurrence(in: tv)

        XCTAssertEqual(controller.cursors.count, 2, "Should add a second cursor at next 'foo'")
        XCTAssertEqual(controller.cursors[1].selection?.location, 8, "Second occurrence at offset 8")
    }

    func testSelectNextOccurrence_multipleCalls() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])

        controller.selectNextOccurrence(in: tv)
        controller.selectNextOccurrence(in: tv)

        XCTAssertEqual(controller.cursors.count, 3, "Should have 3 cursors after two calls")
        XCTAssertEqual(controller.cursors[2].selection?.location, 16, "Third occurrence at offset 16")
    }

    func testSelectNextOccurrence_wrapsAround() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 16, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 19, selection: NSRange(location: 16, length: 3))])

        controller.selectNextOccurrence(in: tv)

        XCTAssertEqual(controller.cursors.count, 2, "Should wrap around and find occurrence at start")
        XCTAssertEqual(controller.cursors[0].selection?.location, 0, "Wrapped occurrence at offset 0")
    }

    func testSelectNextOccurrence_noMoreOccurrences() {
        let text = "foo bar baz"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])

        controller.selectNextOccurrence(in: tv)

        XCTAssertEqual(controller.cursors.count, 1, "Should stay at 1 cursor when no more occurrences")
    }

    func testSelectNextOccurrence_withWordUnderCursor() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 1, length: 0))
        let controller = MultiCursorController(textView: tv)

        controller.selectNextOccurrence(in: tv)

        XCTAssertEqual(controller.cursors.count, 1, "First call selects word under cursor")
        XCTAssertNotNil(controller.cursors.first?.selection, "Cursor should have a selection")
        XCTAssertEqual(controller.cursors.first?.selection?.location, 0, "Word 'foo' starts at 0")
        XCTAssertEqual(controller.cursors.first?.selection?.length, 3, "Word 'foo' has length 3")
    }

    // MARK: - skipAndSelectNext

    func testSkipAndSelectNext() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        // Build up cursors via selectNextOccurrence so currentSearchTerm is set.
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])
        controller.selectNextOccurrence(in: tv)

        // Now we have cursors at offsets 0 and 8. Skip 8 and go to 16.
        XCTAssertEqual(controller.cursors.count, 2)

        controller.skipAndSelectNext(in: tv)

        // After skip: removed cursor at 8, added next occurrence.
        // The remaining cursors should be at 0 and 16.
        XCTAssertGreaterThanOrEqual(controller.cursors.count, 2,
            "Should have at least 2 cursors. Got: \(controller.cursors.map { ($0.selection?.location ?? -1, $0.position) })")
        if controller.cursors.count >= 2 {
            let locations = controller.cursors.compactMap { $0.selection?.location }.sorted()
            XCTAssertTrue(locations.contains(0), "First cursor should remain")
            XCTAssertTrue(locations.contains(16), "Should have added cursor at third occurrence. Got locations: \(locations)")
        }
    }

    func testSkipAndSelectNext_singleCursor() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])

        controller.skipAndSelectNext(in: tv)

        XCTAssertGreaterThanOrEqual(controller.cursors.count, 1)
    }

    // MARK: - undoLastSelection

    func testUndoLastSelection_removesLast() {
        let controller = MultiCursorController()
        controller.setCursors([
            MultiCursor(position: 3, selection: NSRange(location: 0, length: 3)),
            MultiCursor(position: 11, selection: NSRange(location: 8, length: 3)),
            MultiCursor(position: 19, selection: NSRange(location: 16, length: 3)),
        ])

        controller.undoLastSelection()

        XCTAssertEqual(controller.cursors.count, 2, "Should remove last cursor")
        XCTAssertEqual(controller.cursors.last?.selection?.location, 8, "Last cursor now at offset 8")
    }

    func testUndoLastSelection_keepsMinimumOne() {
        let controller = MultiCursorController()
        controller.setCursors([MultiCursor(position: 0)])

        controller.undoLastSelection()

        XCTAssertEqual(controller.cursors.count, 1, "Should keep at least one cursor")
    }

    func testUndoLastSelection_multipleCalls() {
        let controller = MultiCursorController()
        controller.setCursors([
            MultiCursor(position: 3, selection: NSRange(location: 0, length: 3)),
            MultiCursor(position: 11, selection: NSRange(location: 8, length: 3)),
            MultiCursor(position: 19, selection: NSRange(location: 16, length: 3)),
        ])

        controller.undoLastSelection()
        controller.undoLastSelection()

        XCTAssertEqual(controller.cursors.count, 1, "Two undos should leave one cursor")
        XCTAssertEqual(controller.cursors[0].selection?.location, 0, "Remaining cursor at offset 0")
    }

    func testUndoLastSelection_emptyDoesNothing() {
        let controller = MultiCursorController()

        controller.undoLastSelection()

        XCTAssertTrue(controller.cursors.isEmpty, "Should remain empty without crash")
    }

    // MARK: - Integration

    func testSelectNextThenUndo() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)
        controller.setCursors([MultiCursor(position: 3, selection: NSRange(location: 0, length: 3))])

        controller.selectNextOccurrence(in: tv)
        XCTAssertEqual(controller.cursors.count, 2)

        controller.undoLastSelection()
        XCTAssertEqual(controller.cursors.count, 1)
        XCTAssertEqual(controller.cursors[0].selection?.location, 0)
    }

    func testSelectAllThenUndoAll() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv)
        XCTAssertEqual(controller.cursors.count, 3)

        controller.undoLastSelection()
        controller.undoLastSelection()
        XCTAssertEqual(controller.cursors.count, 1)
    }

    func testCursorsAreSortedByPosition() {
        let text = "foo bar foo baz foo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv)

        let positions = controller.cursors.map { $0.position }
        XCTAssertEqual(positions, positions.sorted(), "Cursors should be sorted by position")
    }

    func testMultilineText() {
        let text = "foo\nbar\nfoo\nbaz\nfoo"
        let tv = makeTextView(text, selectedRange: NSRange(location: 0, length: 3))
        let controller = MultiCursorController(textView: tv)

        controller.selectAllOccurrences(in: tv)

        XCTAssertEqual(controller.cursors.count, 3, "Should find occurrences across multiple lines")
    }
}
