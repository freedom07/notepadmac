import XCTest
@testable import SearchKit
import AppKit
import CommonKit

@available(macOS 13.0, *)
final class TextMarkerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a layout manager with a text storage containing the given text.
    private func makeLayoutManager(with text: String) -> (NSLayoutManager, NSTextStorage) {
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
        return (layoutManager, textStorage)
    }

    /// Checks if a temporary background color is set at the given range.
    private func hasTemporaryBackgroundColor(
        in layoutManager: NSLayoutManager,
        range: NSRange
    ) -> Bool {
        var index = range.location
        while index < NSMaxRange(range) {
            var effectiveRange = NSRange(location: 0, length: 0)
            let value = layoutManager.temporaryAttribute(
                .backgroundColor,
                atCharacterIndex: index,
                effectiveRange: &effectiveRange
            )
            if value != nil { return true }
            index = NSMaxRange(effectiveRange)
            if effectiveRange.length == 0 { index += 1 }
        }
        return false
    }

    // MARK: - Mark All

    func testMarkAllFindsOccurrences() {
        let marker = TextMarker()
        let text = "hello world hello again hello"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "hello",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions()
        )

        XCTAssertEqual(count, 3, "Should find 3 occurrences of 'hello'")
        XCTAssertEqual(marker.markCount(for: .style1), 3)
    }

    func testMarkAllAppliesTemporaryAttributes() {
        let marker = TextMarker()
        let text = "foo bar foo baz foo"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions()
        )

        // First "foo" at 0
        XCTAssertTrue(hasTemporaryBackgroundColor(in: lm, range: NSRange(location: 0, length: 3)),
                       "First 'foo' should have background color")
        // Second "foo" at 8
        XCTAssertTrue(hasTemporaryBackgroundColor(in: lm, range: NSRange(location: 8, length: 3)),
                       "Second 'foo' should have background color")
        // Third "foo" at 16
        XCTAssertTrue(hasTemporaryBackgroundColor(in: lm, range: NSRange(location: 16, length: 3)),
                       "Third 'foo' should have background color")
    }

    func testMarkAllCaseInsensitive() {
        let marker = TextMarker()
        let text = "Hello hello HELLO"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "hello",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions(caseSensitive: false)
        )

        XCTAssertEqual(count, 3, "Case-insensitive should match all 3 variants")
    }

    func testMarkAllCaseSensitive() {
        let marker = TextMarker()
        let text = "Hello hello HELLO"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "hello",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions(caseSensitive: true)
        )

        XCTAssertEqual(count, 1, "Case-sensitive should match only lowercase 'hello'")
    }

    func testMarkAllWholeWord() {
        let marker = TextMarker()
        let text = "the cat sat on the mat there"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "the",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions(wholeWord: true)
        )

        XCTAssertEqual(count, 2, "Whole-word should not match 'there'")
    }

    func testMarkAllRegex() {
        let marker = TextMarker()
        let text = "abc 123 def 456 ghi"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "\\d+",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions(useRegex: true)
        )

        XCTAssertEqual(count, 2, "Regex should find 2 number sequences")
    }

    func testMarkAllEmptyPattern() {
        let marker = TextMarker()
        let text = "hello world"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions()
        )

        XCTAssertEqual(count, 0, "Empty pattern should mark nothing")
    }

    func testMarkAllNoMatch() {
        let marker = TextMarker()
        let text = "hello world"
        let (lm, ts) = makeLayoutManager(with: text)

        let count = marker.markAll(
            pattern: "xyz",
            in: lm,
            textLength: ts.length,
            style: .style1,
            options: SearchOptions()
        )

        XCTAssertEqual(count, 0, "Non-matching pattern should mark nothing")
    }

    // MARK: - Multiple Styles

    func testMarkAllMultipleStyles() {
        let marker = TextMarker()
        let text = "foo bar baz foo bar baz"
        let (lm, ts) = makeLayoutManager(with: text)

        let fooCount = marker.markAll(
            pattern: "foo",
            in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )
        let barCount = marker.markAll(
            pattern: "bar",
            in: lm, textLength: ts.length,
            style: .style2, options: SearchOptions()
        )

        XCTAssertEqual(fooCount, 2, "Should find 2 'foo'")
        XCTAssertEqual(barCount, 2, "Should find 2 'bar'")
        XCTAssertEqual(marker.markCount(for: .style1), 2)
        XCTAssertEqual(marker.markCount(for: .style2), 2)
    }

    // MARK: - Clear Marks

    func testClearMarksSingleStyle() {
        let marker = TextMarker()
        let text = "foo bar foo bar"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )
        marker.markAll(
            pattern: "bar", in: lm, textLength: ts.length,
            style: .style2, options: SearchOptions()
        )

        marker.clearMarks(style: .style1, in: lm, textLength: ts.length)

        XCTAssertEqual(marker.markCount(for: .style1), 0, "Style 1 marks should be cleared")
        XCTAssertEqual(marker.markCount(for: .style2), 2, "Style 2 marks should remain")

        // Verify temporary attributes were removed for style1
        XCTAssertFalse(hasTemporaryBackgroundColor(in: lm, range: NSRange(location: 0, length: 3)),
                        "First 'foo' highlight should be removed")
    }

    func testClearAllMarks() {
        let marker = TextMarker()
        let text = "foo bar baz"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )
        marker.markAll(
            pattern: "bar", in: lm, textLength: ts.length,
            style: .style2, options: SearchOptions()
        )
        marker.markAll(
            pattern: "baz", in: lm, textLength: ts.length,
            style: .style3, options: SearchOptions()
        )

        marker.clearAllMarks(in: lm, textLength: ts.length)

        XCTAssertFalse(marker.hasMarks, "All marks should be cleared")
        for style in TextMarker.MarkStyle.allCases {
            XCTAssertEqual(marker.markCount(for: style), 0)
        }
    }

    func testClearMarksOnEmptyStyle() {
        let marker = TextMarker()
        let text = "hello"
        let (lm, ts) = makeLayoutManager(with: text)

        // Should not crash
        marker.clearMarks(style: .style5, in: lm, textLength: ts.length)
        XCTAssertEqual(marker.markCount(for: .style5), 0)
    }

    // MARK: - Navigation

    func testNextMarkAfterOffset() {
        let marker = TextMarker()
        let text = "foo bar foo baz foo"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )

        // Starting after position 1, next should be at 8
        let next = marker.nextMark(after: 1, style: .style1)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.location, 8, "Next mark after offset 1 should be at 8")
    }

    func testNextMarkWrapsAround() {
        let marker = TextMarker()
        let text = "foo bar foo"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )

        // After the last mark, should wrap to first
        let next = marker.nextMark(after: 100, style: .style1)
        XCTAssertNotNil(next)
        XCTAssertEqual(next?.location, 0, "Should wrap around to the first mark")
    }

    func testNextMarkReturnsNilForNoMarks() {
        let marker = TextMarker()
        let next = marker.nextMark(after: 0, style: .style1)
        XCTAssertNil(next, "Should return nil when no marks exist")
    }

    func testPreviousMarkBeforeOffset() {
        let marker = TextMarker()
        let text = "foo bar foo baz foo"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )

        // Before position 12, previous should be at 8
        let prev = marker.previousMark(before: 12, style: .style1)
        XCTAssertNotNil(prev)
        XCTAssertEqual(prev?.location, 8, "Previous mark before offset 12 should be at 8")
    }

    func testPreviousMarkWrapsAround() {
        let marker = TextMarker()
        let text = "foo bar foo"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )

        // Before the first mark, should wrap to last
        let prev = marker.previousMark(before: 0, style: .style1)
        XCTAssertNotNil(prev)
        XCTAssertEqual(prev?.location, 8, "Should wrap around to the last mark")
    }

    func testPreviousMarkReturnsNilForNoMarks() {
        let marker = TextMarker()
        let prev = marker.previousMark(before: 10, style: .style1)
        XCTAssertNil(prev, "Should return nil when no marks exist")
    }

    // MARK: - Has Marks

    func testHasMarksInitiallyFalse() {
        let marker = TextMarker()
        XCTAssertFalse(marker.hasMarks, "Should have no marks initially")
    }

    func testHasMarksAfterMarking() {
        let marker = TextMarker()
        let text = "hello world"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "hello", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )

        XCTAssertTrue(marker.hasMarks, "Should have marks after markAll")
    }

    // MARK: - Style Colors

    func testStyleColorsExistForAllStyles() {
        for style in TextMarker.MarkStyle.allCases {
            XCTAssertNotNil(TextMarker.styleColors[style], "Color should exist for style \(style.rawValue)")
        }
    }

    func testAllStylesEnumerated() {
        XCTAssertEqual(TextMarker.MarkStyle.allCases.count, 5, "Should have exactly 5 styles")
        XCTAssertEqual(TextMarker.MarkStyle.style1.rawValue, 1)
        XCTAssertEqual(TextMarker.MarkStyle.style2.rawValue, 2)
        XCTAssertEqual(TextMarker.MarkStyle.style3.rawValue, 3)
        XCTAssertEqual(TextMarker.MarkStyle.style4.rawValue, 4)
        XCTAssertEqual(TextMarker.MarkStyle.style5.rawValue, 5)
    }

    // MARK: - Re-marking Clears Previous

    func testRemarkClearsPreviousMarks() {
        let marker = TextMarker()
        let text = "foo bar foo baz"
        let (lm, ts) = makeLayoutManager(with: text)

        marker.markAll(
            pattern: "foo", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )
        XCTAssertEqual(marker.markCount(for: .style1), 2)

        // Re-mark with a different pattern using the same style
        marker.markAll(
            pattern: "bar", in: lm, textLength: ts.length,
            style: .style1, options: SearchOptions()
        )
        XCTAssertEqual(marker.markCount(for: .style1), 1, "Old marks should be replaced")
    }
}
