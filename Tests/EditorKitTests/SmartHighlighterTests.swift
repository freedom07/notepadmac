import XCTest
@testable import EditorKit
import CommonKit

@available(macOS 13.0, *)
final class SmartHighlighterTests: XCTestCase {

    // MARK: - wordRange tests

    func testWordRangeAtStartOfWord() {
        let highlighter = SmartHighlighter()
        let text = "hello world"
        let range = highlighter.wordRange(at: 0, in: text)
        XCTAssertEqual(range, NSRange(location: 0, length: 5), "Should find 'hello' at position 0")
    }

    func testWordRangeAtMiddleOfWord() {
        let highlighter = SmartHighlighter()
        let text = "hello world"
        let range = highlighter.wordRange(at: 2, in: text)
        XCTAssertEqual(range, NSRange(location: 0, length: 5), "Position 2 is inside 'hello'")
    }

    func testWordRangeAtEndOfWord() {
        let highlighter = SmartHighlighter()
        let text = "hello world"
        // Position 5 is the space, but the boundary check allows word-end matching
        let range = highlighter.wordRange(at: 5, in: text)
        XCTAssertEqual(range, NSRange(location: 0, length: 5), "Position 5 is at end of 'hello'")
    }

    func testWordRangeSecondWord() {
        let highlighter = SmartHighlighter()
        let text = "hello world"
        let range = highlighter.wordRange(at: 7, in: text)
        XCTAssertEqual(range, NSRange(location: 6, length: 5), "Position 7 is inside 'world'")
    }

    func testWordRangeEmptyString() {
        let highlighter = SmartHighlighter()
        let range = highlighter.wordRange(at: 0, in: "")
        XCTAssertNil(range, "Empty string has no words")
    }

    func testWordRangeOutOfBounds() {
        let highlighter = SmartHighlighter()
        let range = highlighter.wordRange(at: -1, in: "hello")
        XCTAssertNil(range, "Negative position should return nil")
    }

    func testWordRangeOnlySpaces() {
        let highlighter = SmartHighlighter()
        let range = highlighter.wordRange(at: 1, in: "   ")
        XCTAssertNil(range, "No word at position in whitespace-only string")
    }

    func testWordRangeWithUnderscores() {
        let highlighter = SmartHighlighter()
        let text = "foo_bar baz"
        let range = highlighter.wordRange(at: 2, in: text)
        // \\w+ matches underscores, so 'foo_bar' is one word
        XCTAssertEqual(range, NSRange(location: 0, length: 7), "\\w+ includes underscores")
    }

    // MARK: - Helpers

    /// Returns `true` if any character in `range` has a temporary `.backgroundColor`
    /// attribute set on the given layout manager.
    private func hasTemporaryBackgroundColor(in layoutManager: NSLayoutManager, range: NSRange) -> Bool {
        var index = range.location
        while index < NSMaxRange(range) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let value = layoutManager.temporaryAttribute(
                .backgroundColor,
                atCharacterIndex: index,
                effectiveRange: &effectiveRange
            )
            if value != nil { return true }
            // Advance past the effective range to avoid re-checking the same span.
            index = NSMaxRange(effectiveRange)
            if effectiveRange.length == 0 { index += 1 }
        }
        return false
    }

    private func makeTextView(with text: String) -> NSTextView {
        let textStorage = NSTextStorage(string: text)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = false
        textContainer.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.addTextContainer(textContainer)
        return NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 500), textContainer: textContainer)
    }

    func testHighlightAppliesBackgroundColor() {
        let highlighter = SmartHighlighter()
        let text = "hello world hello again hello"
        let tv = makeTextView(with: text)

        // Place cursor inside the first "hello" (position 2)
        tv.setSelectedRange(NSRange(location: 2, length: 0))
        highlighter.cursorDidMove(in: tv)

        // The debouncer delays execution; trigger synchronously for testing
        // by calling internal method via the public clear+re-trigger pattern.
        // Instead, we wait briefly for the debounce to fire.
        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // After debounce, check that the second "hello" (at 12) has the highlight.
        // Highlights are now temporary attributes on the layout manager, not on text storage.
        guard let layoutManager = tv.layoutManager else {
            XCTFail("layoutManager should not be nil")
            return
        }

        let found = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 12, length: 5))
        XCTAssertTrue(found, "Second occurrence of 'hello' should be highlighted via temporary attribute")
    }

    func testHighlightSkipsCursorWord() {
        let highlighter = SmartHighlighter()
        let text = "foo bar foo baz foo"
        let tv = makeTextView(with: text)

        tv.setSelectedRange(NSRange(location: 1, length: 0)) // inside first "foo"
        highlighter.cursorDidMove(in: tv)

        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        guard let layoutManager = tv.layoutManager else {
            XCTFail("layoutManager should not be nil")
            return
        }

        // The word at cursor (location 0, length 3) should NOT have highlight
        let found = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 0, length: 3))
        XCTAssertFalse(found, "Word at cursor should not be highlighted")
    }

    func testClearHighlightsRemovesAll() {
        let highlighter = SmartHighlighter()
        let text = "abc def abc ghi abc"
        let tv = makeTextView(with: text)

        tv.setSelectedRange(NSRange(location: 1, length: 0))
        highlighter.cursorDidMove(in: tv)

        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        highlighter.clearHighlights(in: tv)

        guard let layoutManager = tv.layoutManager,
              let textStorage = tv.textStorage else {
            XCTFail("layoutManager/textStorage should not be nil")
            return
        }

        let anyHighlight = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 0, length: textStorage.length))
        XCTAssertFalse(anyHighlight, "After clear, no background highlights should remain")
    }

    func testMinWordLengthFilter() {
        let highlighter = SmartHighlighter()
        highlighter.minWordLength = 3
        let text = "a b a c a"
        let tv = makeTextView(with: text)

        tv.setSelectedRange(NSRange(location: 0, length: 0))
        highlighter.cursorDidMove(in: tv)

        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        guard let layoutManager = tv.layoutManager,
              let textStorage = tv.textStorage else {
            XCTFail("layoutManager/textStorage should not be nil")
            return
        }

        let anyHighlight = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 0, length: textStorage.length))
        XCTAssertFalse(anyHighlight, "Single-char word 'a' is below minWordLength=3, no highlights")
    }

    func testDisabledStateNoHighlights() {
        let highlighter = SmartHighlighter()
        highlighter.isEnabled = false
        let text = "hello world hello"
        let tv = makeTextView(with: text)

        tv.setSelectedRange(NSRange(location: 2, length: 0))
        highlighter.cursorDidMove(in: tv)

        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        guard let layoutManager = tv.layoutManager,
              let textStorage = tv.textStorage else {
            XCTFail("layoutManager/textStorage should not be nil")
            return
        }

        let anyHighlight = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 0, length: textStorage.length))
        XCTAssertFalse(anyHighlight, "When disabled, no highlights should be applied")
    }

    func testSelectionRangePreventHighlights() {
        let highlighter = SmartHighlighter()
        let text = "hello world hello"
        let tv = makeTextView(with: text)

        // Select text (non-zero selection length)
        tv.setSelectedRange(NSRange(location: 0, length: 5))
        highlighter.cursorDidMove(in: tv)

        let expectation = XCTestExpectation(description: "Debounce fires")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        guard let layoutManager = tv.layoutManager,
              let textStorage = tv.textStorage else {
            XCTFail("layoutManager/textStorage should not be nil")
            return
        }

        let anyHighlight = hasTemporaryBackgroundColor(in: layoutManager, range: NSRange(location: 0, length: textStorage.length))
        XCTAssertFalse(anyHighlight, "Highlights should not appear when text is selected")
    }

    func testDefaultProperties() {
        let highlighter = SmartHighlighter()
        XCTAssertTrue(highlighter.isEnabled, "Should be enabled by default")
        XCTAssertEqual(highlighter.minWordLength, 2, "Default min word length should be 2")
    }
}
