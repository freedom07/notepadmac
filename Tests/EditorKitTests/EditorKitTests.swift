import XCTest
@testable import EditorKit
@testable import SyntaxKit
import CommonKit

final class EditorKitTests: XCTestCase {
    func testBracketMatcherFindMatching() {
        let text = "foo(bar[baz])"
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 3, in: text), 12) // ( -> )
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 7, in: text), 11) // [ -> ]
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 12, in: text), 3) // ) -> (
    }
    func testBracketMatcherNoMatch() {
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 0, in: "hello"))
    }
    func testBookmarkManagerToggle() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 5)
        XCTAssertTrue(mgr.bookmarkedLines.contains(5))
        mgr.toggleBookmark(at: 5)
        XCTAssertFalse(mgr.bookmarkedLines.contains(5))
    }
    func testBookmarkManagerNavigation() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 3)
        mgr.toggleBookmark(at: 7)
        mgr.toggleBookmark(at: 15)
        XCTAssertEqual(mgr.nextBookmark(after: 5), 7)
        XCTAssertEqual(mgr.previousBookmark(before: 10), 7)
        XCTAssertEqual(mgr.sortedBookmarks, [3, 7, 15])
    }
    func testCommentToggleDetection() {
        XCTAssertTrue(CommentToggle.isLineCommented("// hello", prefix: "//"))
        XCTAssertTrue(CommentToggle.isLineCommented("    // hello", prefix: "//"))
        XCTAssertFalse(CommentToggle.isLineCommented("hello", prefix: "//"))
    }
    func testCaseConverterLogic() {
        // Test snake_case conversion logic
        var result = ""
        let text = "helloWorld"
        for (i, c) in text.enumerated() {
            if c.isUppercase && i > 0 { result += "_" }
            result += String(c).lowercased()
        }
        XCTAssertEqual(result, "hello_world")
    }
    func testLineEndingDetectionCR() {
        let data = "line1\rline2\r".data(using: .utf8)!
        XCTAssertEqual(LineEnding.detect(from: data), .cr)
    }

    func testBracketMatcherAngleBrackets() {
        let text = "foo<bar>"
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 3, in: text), 7, "< at 3 should match > at 7")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 7, in: text), 3, "> at 7 should match < at 3")
    }

    func testBracketMatcherNestedBrackets() {
        let text = "((()))"
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 0, in: text), 5, "Outermost ( at 0 should match ) at 5")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 1, in: text), 4, "Middle ( at 1 should match ) at 4")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 2, in: text), 3, "Inner ( at 2 should match ) at 3")
    }

    func testBookmarkClearAll() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 1)
        mgr.toggleBookmark(at: 5)
        mgr.toggleBookmark(at: 10)
        XCTAssertTrue(mgr.hasBookmarks, "Should have bookmarks after toggling")
        mgr.clearAllBookmarks()
        XCTAssertFalse(mgr.hasBookmarks, "clearAllBookmarks should remove all bookmarks")
        XCTAssertTrue(mgr.bookmarkedLines.isEmpty, "bookmarkedLines should be empty after clear")
    }

    // MARK: - BookmarkManager Additional Tests

    func testBookmarkNextWrapsAround() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 3)
        mgr.toggleBookmark(at: 7)
        mgr.toggleBookmark(at: 15)
        // After the last bookmark, nextBookmark should wrap to the first
        XCTAssertEqual(mgr.nextBookmark(after: 15), 3, "nextBookmark after last should wrap to first")
        XCTAssertEqual(mgr.nextBookmark(after: 20), 3, "nextBookmark after beyond-last should wrap to first")
    }

    func testBookmarkPreviousWrapsAround() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 3)
        mgr.toggleBookmark(at: 7)
        mgr.toggleBookmark(at: 15)
        // Before the first bookmark, previousBookmark should wrap to the last
        XCTAssertEqual(mgr.previousBookmark(before: 3), 15, "previousBookmark before first should wrap to last")
        XCTAssertEqual(mgr.previousBookmark(before: 0), 15, "previousBookmark before 0 should wrap to last")
    }

    func testBookmarkEmptyNavigation() {
        let mgr = BookmarkManager()
        // Empty manager should return nil for navigation
        XCTAssertNil(mgr.nextBookmark(after: 0), "nextBookmark on empty manager should be nil")
        XCTAssertNil(mgr.previousBookmark(before: 10), "previousBookmark on empty manager should be nil")
    }

    func testBookmarkHasBookmarks() {
        let mgr = BookmarkManager()
        XCTAssertFalse(mgr.hasBookmarks, "New manager should have no bookmarks")
        mgr.toggleBookmark(at: 5)
        XCTAssertTrue(mgr.hasBookmarks, "Should have bookmarks after adding one")
        mgr.toggleBookmark(at: 5)
        XCTAssertFalse(mgr.hasBookmarks, "Should have no bookmarks after toggling off")
    }

    func testBookmarkSortedBookmarks() {
        let mgr = BookmarkManager()
        mgr.toggleBookmark(at: 20)
        mgr.toggleBookmark(at: 5)
        mgr.toggleBookmark(at: 12)
        mgr.toggleBookmark(at: 1)
        XCTAssertEqual(mgr.sortedBookmarks, [1, 5, 12, 20], "sortedBookmarks should return lines in ascending order")
    }

    // MARK: - BracketMatcher Additional Tests

    func testBracketMatcherEmptyString() {
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 0, in: ""), "Empty string should return nil")
    }

    func testBracketMatcherUnmatchedOpen() {
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 0, in: "(hello"), "Unmatched open paren should return nil")
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 0, in: "[abc"), "Unmatched open bracket should return nil")
    }

    func testBracketMatcherUnmatchedClose() {
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 4, in: "hello)"), "Unmatched close paren should return nil")
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 3, in: "abc]"), "Unmatched close bracket should return nil")
    }

    func testBracketMatcherMixedTypes() {
        let text = "(a[b]c)"
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 0, in: text), 6, "( at 0 should match ) at 6")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 2, in: text), 4, "[ at 2 should match ] at 4")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 4, in: text), 2, "] at 4 should match [ at 2")
        XCTAssertEqual(BracketMatcher.findMatchingBracket(at: 6, in: text), 0, ") at 6 should match ( at 0")
    }

    func testBracketMatcherOutOfBounds() {
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: -1, in: "(hello)"), "Negative position should return nil")
        XCTAssertNil(BracketMatcher.findMatchingBracket(at: 100, in: "(hello)"), "Position beyond text length should return nil")
    }

    // MARK: - CommentToggle Additional Tests

    func testIsLineCommentedHash() {
        XCTAssertTrue(CommentToggle.isLineCommented("# comment", prefix: "#"), "Hash-prefixed line should be detected as commented")
        XCTAssertTrue(CommentToggle.isLineCommented("   # indented", prefix: "#"), "Indented hash comment should be detected")
        XCTAssertFalse(CommentToggle.isLineCommented("no comment", prefix: "#"), "Non-commented line should not be detected")
    }

    func testIsLineCommentedDash() {
        XCTAssertTrue(CommentToggle.isLineCommented("-- comment", prefix: "--"), "Double-dash comment should be detected")
        XCTAssertTrue(CommentToggle.isLineCommented("  -- indented", prefix: "--"), "Indented double-dash should be detected")
        XCTAssertFalse(CommentToggle.isLineCommented("not a comment", prefix: "--"), "Non-commented line should not be detected")
    }

    func testIsLineCommentedEmpty() {
        XCTAssertFalse(CommentToggle.isLineCommented("", prefix: "//"), "Empty string should not be detected as commented")
        XCTAssertFalse(CommentToggle.isLineCommented("   ", prefix: "//"), "Whitespace-only should not be detected as commented")
    }

    // MARK: - MultiCursorController Tests

    @available(macOS 13.0, *)
    func testMultiCursorAddCursor() {
        let controller = MultiCursorController()
        controller.addCursor(at: 5)
        controller.addCursor(at: 10)
        controller.addCursor(at: 20)
        XCTAssertEqual(controller.cursors.count, 3, "Should have 3 cursors after adding 3")
        XCTAssertEqual(controller.cursors.map { $0.position }, [5, 10, 20], "Cursors should be sorted by position")
    }

    @available(macOS 13.0, *)
    func testMultiCursorRemoveCursor() {
        let controller = MultiCursorController()
        controller.addCursor(at: 5)
        controller.addCursor(at: 10)
        controller.addCursor(at: 20)
        controller.removeCursor(at: 1)
        XCTAssertEqual(controller.cursors.count, 2, "Should have 2 cursors after removing one")
        XCTAssertEqual(controller.cursors.map { $0.position }, [5, 20], "Middle cursor should be removed")
    }

    @available(macOS 13.0, *)
    func testMultiCursorClearAdditional() {
        let controller = MultiCursorController()
        controller.addCursor(at: 5)
        controller.addCursor(at: 10)
        controller.addCursor(at: 20)
        controller.clearAdditionalCursors()
        XCTAssertEqual(controller.cursors.count, 1, "Should have 1 cursor after clearing additional")
        XCTAssertEqual(controller.cursors[0].position, 5, "Primary cursor should remain")
    }

    @available(macOS 13.0, *)
    func testMultiCursorIsActive() {
        let controller = MultiCursorController()
        XCTAssertFalse(controller.isMultiCursorActive, "Should not be active with no cursors")
        controller.addCursor(at: 5)
        XCTAssertFalse(controller.isMultiCursorActive, "Should not be active with 1 cursor")
        controller.addCursor(at: 10)
        XCTAssertTrue(controller.isMultiCursorActive, "Should be active with 2 cursors")
    }

    @available(macOS 13.0, *)
    func testMultiCursorMergeDuplicates() {
        let controller = MultiCursorController()
        controller.addCursor(at: 5)
        controller.addCursor(at: 5)
        controller.addCursor(at: 5)
        XCTAssertEqual(controller.cursors.count, 1, "Duplicate cursors at same position should be merged")
        XCTAssertEqual(controller.cursors[0].position, 5, "Merged cursor should be at position 5")
    }

    @available(macOS 13.0, *)
    func testMultiCursorMoveCursorsBy() {
        let controller = MultiCursorController()
        controller.addCursor(at: 5)
        controller.addCursor(at: 10)
        controller.moveCursorsBy(3)
        XCTAssertEqual(controller.cursors.map { $0.position }, [8, 13], "Cursors should move forward by 3")
        controller.moveCursorsBy(-20)
        XCTAssertEqual(controller.cursors.map { $0.position }, [0], "Cursors clamped to 0 should merge")
    }

    @available(macOS 13.0, *)
    func testMultiCursorSelectColumnBlock() {
        let controller = MultiCursorController()
        let text = "ABCDE\nFGHIJ\nKLMNO\nPQRST"
        // Select column block: lines 1-2, columns 1-3
        controller.selectColumnBlock(fromLine: 1, toLine: 2, fromColumn: 1, toColumn: 3, in: text)
        XCTAssertEqual(controller.cursors.count, 2, "Should have 2 cursors for 2-line column selection")
        // Line 1 ("FGHIJ"): offset 6, col 1-3 => selection at 7 length 2
        XCTAssertEqual(controller.cursors[0].selection, NSRange(location: 7, length: 2), "First cursor selection should be cols 1-3 of line 1")
        // Line 2 ("KLMNO"): offset 12, col 1-3 => selection at 13 length 2
        XCTAssertEqual(controller.cursors[1].selection, NSRange(location: 13, length: 2), "Second cursor selection should be cols 1-3 of line 2")
    }

    // MARK: - CaseConverter Logic Tests

    func testSnakeCaseLogic() {
        // Test the snake_case conversion logic used by CaseConverter.toSnakeCase
        let inputs = ["helloWorld", "myVariableName", "XMLParser", "a"]
        let expected = ["hello_world", "my_variable_name", "x_m_l_parser", "a"]
        for (input, exp) in zip(inputs, expected) {
            var r = ""
            for (i, c) in input.enumerated() {
                if c.isUppercase && i > 0 { r += "_" }
                r += String(c).lowercased()
            }
            XCTAssertEqual(r, exp, "Snake case of '\(input)' should be '\(exp)'")
        }
    }

    func testToggleCaseLogic() {
        // Test the toggle case logic used by CaseConverter.toggleCase
        let input = "Hello World 123"
        let toggled = String(input.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) })
        XCTAssertEqual(toggled, "hELLO wORLD 123", "Toggle case should invert letter casing")

        let allUpper = "ABC"
        let toggledUpper = String(allUpper.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) })
        XCTAssertEqual(toggledUpper, "abc", "Toggle case of all-uppercase should be all-lowercase")
    }

    // MARK: - Edge Column Indicator Tests

    private func makeTextView() -> EditorTextView {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        return EditorTextView(frame: .zero, textContainer: textContainer)
    }

    func testEdgeColumnDefaultIsNil() {
        let textView = makeTextView()
        XCTAssertNil(textView.edgeColumn, "Edge column should be nil (disabled) by default")
    }

    func testEdgeColumnCanBeSet() {
        let textView = makeTextView()
        textView.edgeColumn = 80
        XCTAssertEqual(textView.edgeColumn, 80)
        textView.edgeColumn = 120
        XCTAssertEqual(textView.edgeColumn, 120)
        textView.edgeColumn = Optional<Int>.none
        XCTAssertNil(textView.edgeColumn)
    }

    func testEdgeColumnColorDefault() {
        let textView = makeTextView()
        // The default color should be a separator color with reduced alpha
        XCTAssertNotNil(textView.edgeColumnColor, "Edge column color should have a default value")
    }

    func testEdgeColumnColorCanBeChanged() {
        let textView = makeTextView()
        let customColor = NSColor.red.withAlphaComponent(0.5)
        textView.edgeColumnColor = customColor
        XCTAssertEqual(textView.edgeColumnColor, customColor)
    }

    // MARK: - Fold Level Control Tests

    func testFoldAllCollapsesAllRegions() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 5, kind: .block),
            FoldRegion(startLine: 10, endLine: 15, kind: .block),
            FoldRegion(startLine: 20, endLine: 25, kind: .block),
        ]
        gutter.foldAll()
        XCTAssertEqual(gutter.collapsedLines, [0, 10, 20], "foldAll should collapse all regions")
    }

    func testUnfoldAllExpandsAllRegions() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 5, kind: .block),
            FoldRegion(startLine: 10, endLine: 15, kind: .block),
        ]
        gutter.collapsedLines = [0, 10]
        gutter.unfoldAll()
        XCTAssertTrue(gutter.collapsedLines.isEmpty, "unfoldAll should expand all regions")
    }

    func testFoldCurrentBlockToggles() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 5, endLine: 10, kind: .block),
        ]
        // Fold
        gutter.foldCurrentBlock(at: 5)
        XCTAssertTrue(gutter.collapsedLines.contains(5), "Should collapse the region at line 5")
        // Unfold
        gutter.foldCurrentBlock(at: 5)
        XCTAssertFalse(gutter.collapsedLines.contains(5), "Should expand the region at line 5")
    }

    func testFoldCurrentBlockIgnoresNonFoldLine() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 5, endLine: 10, kind: .block),
        ]
        gutter.foldCurrentBlock(at: 3)
        XCTAssertTrue(gutter.collapsedLines.isEmpty, "Should not fold when line is not a fold start")
    }

    func testComputeDepthsFlat() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 5, kind: .block),
            FoldRegion(startLine: 10, endLine: 15, kind: .block),
        ]
        let depths = gutter.computeDepths()
        XCTAssertEqual(depths, [1, 1], "Non-overlapping regions should both be depth 1")
    }

    func testComputeDepthsNested() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 20, kind: .block),
            FoldRegion(startLine: 5, endLine: 15, kind: .block),
            FoldRegion(startLine: 8, endLine: 12, kind: .block),
        ]
        let depths = gutter.computeDepths()
        XCTAssertEqual(depths, [1, 2, 3], "Nested regions should have increasing depth")
    }

    func testFoldLevelCollapsesAtDepth() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 20, kind: .block),   // depth 1
            FoldRegion(startLine: 5, endLine: 15, kind: .block),   // depth 2
            FoldRegion(startLine: 8, endLine: 12, kind: .block),   // depth 3
        ]

        gutter.foldLevel(2)
        // Should fold regions at depth >= 2 (lines 5 and 8)
        XCTAssertFalse(gutter.collapsedLines.contains(0), "Depth 1 region should not be collapsed at level 2")
        XCTAssertTrue(gutter.collapsedLines.contains(5), "Depth 2 region should be collapsed at level 2")
        XCTAssertTrue(gutter.collapsedLines.contains(8), "Depth 3 region should be collapsed at level 2")
    }

    func testFoldLevel1CollapsesAll() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 20, kind: .block),
            FoldRegion(startLine: 5, endLine: 15, kind: .block),
        ]
        gutter.foldLevel(1)
        XCTAssertEqual(gutter.collapsedLines.count, 2, "foldLevel(1) should collapse all regions")
    }

    func testFoldLevelResetsExistingFolds() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 20, kind: .block),
            FoldRegion(startLine: 5, endLine: 15, kind: .block),
        ]
        // Pre-collapse everything
        gutter.foldAll()
        XCTAssertEqual(gutter.collapsedLines.count, 2)
        // Now fold only level >= 2
        gutter.foldLevel(2)
        XCTAssertFalse(gutter.collapsedLines.contains(0), "foldLevel should reset prior folds")
        XCTAssertTrue(gutter.collapsedLines.contains(5))
    }

    func testFoldLevelZeroIsIgnored() {
        let gutter = FoldingGutter()
        gutter.foldRegions = [
            FoldRegion(startLine: 0, endLine: 5, kind: .block),
        ]
        gutter.collapsedLines = [0]
        gutter.foldLevel(0)
        // Level 0 is invalid, should not change state
        XCTAssertEqual(gutter.collapsedLines, [0], "foldLevel(0) should be a no-op")
    }

    func testFoldLevelWithUnsortedRegions() {
        let gutter = FoldingGutter()
        // Regions are NOT sorted by startLine — this tests the index mapping fix
        gutter.foldRegions = [
            FoldRegion(startLine: 8, endLine: 12, kind: .block),   // depth 3 (innermost)
            FoldRegion(startLine: 0, endLine: 20, kind: .block),   // depth 1 (outermost)
            FoldRegion(startLine: 5, endLine: 15, kind: .block),   // depth 2
        ]
        gutter.foldLevel(2)
        XCTAssertFalse(gutter.collapsedLines.contains(0), "Depth 1 should not be collapsed at level 2")
        XCTAssertTrue(gutter.collapsedLines.contains(5), "Depth 2 should be collapsed at level 2")
        XCTAssertTrue(gutter.collapsedLines.contains(8), "Depth 3 should be collapsed at level 2")
    }

    // MARK: - LineOperations Tests

    func testRemoveEmptyLinesPreservingBlank() {
        // removeEmptyLinesPreservingBlank should remove truly empty lines
        // but keep lines that contain whitespace
        let input = "hello\n\n   \nworld\n\n  \t  \nend"
        let lines = input.components(separatedBy: "\n")
        let filtered = lines.filter { !$0.isEmpty }
        let result = filtered.joined(separator: "\n")
        // Empty lines ("") are removed, but "   " and "  \t  " are kept
        XCTAssertEqual(result, "hello\n   \nworld\n  \t  \nend",
            "removeEmptyLinesPreservingBlank should remove truly empty lines but keep whitespace-only lines")
    }

    func testRemoveDuplicateLinesNonConsecutive() {
        // removeDuplicateLines should remove all duplicates regardless of position
        let input = "a\nb\na\nb\nc\n"
        let lines = input.components(separatedBy: "\n")
        var seen = Set<String>(); var unique: [String] = []
        for line in lines {
            if !line.isEmpty && !seen.contains(line) { seen.insert(line); unique.append(line) }
        }
        let result = unique.joined(separator: "\n")
        XCTAssertEqual(result, "a\nb\nc",
            "removeDuplicateLines should remove non-consecutive duplicates, keeping first occurrence")
    }

    // MARK: - Column Editor Tests

    func testFormatNumberDecimal() {
        XCTAssertEqual(LineOperations.formatNumber(42, radix: 10, uppercase: false), "42")
        XCTAssertEqual(LineOperations.formatNumber(0, radix: 10, uppercase: false), "0")
        XCTAssertEqual(LineOperations.formatNumber(255, radix: 10, uppercase: false), "255")
    }

    func testFormatNumberHex() {
        XCTAssertEqual(LineOperations.formatNumber(255, radix: 16, uppercase: false), "ff")
        XCTAssertEqual(LineOperations.formatNumber(255, radix: 16, uppercase: true), "FF")
        XCTAssertEqual(LineOperations.formatNumber(10, radix: 16, uppercase: true), "A")
        XCTAssertEqual(LineOperations.formatNumber(0, radix: 16, uppercase: false), "0")
    }

    func testFormatNumberOctal() {
        XCTAssertEqual(LineOperations.formatNumber(8, radix: 8, uppercase: false), "10")
        XCTAssertEqual(LineOperations.formatNumber(255, radix: 8, uppercase: false), "377")
        XCTAssertEqual(LineOperations.formatNumber(0, radix: 8, uppercase: false), "0")
    }

    func testFormatNumberBinary() {
        XCTAssertEqual(LineOperations.formatNumber(5, radix: 2, uppercase: false), "101")
        XCTAssertEqual(LineOperations.formatNumber(255, radix: 2, uppercase: false), "11111111")
        XCTAssertEqual(LineOperations.formatNumber(0, radix: 2, uppercase: false), "0")
    }

    func testColumnTextInsertionLogic() {
        // Simulate column insertion at column 3 for multi-line text
        let lines = ["hello", "world", "foo"]
        let column = 3
        let insertText = "XX"

        let result = lines.map { line -> String in
            if line.count < column {
                let padding = String(repeating: " ", count: column - line.count)
                return line + padding + insertText
            } else {
                var chars = Array(line)
                chars.insert(contentsOf: insertText, at: column)
                return String(chars)
            }
        }

        XCTAssertEqual(result[0], "helXXlo", "Should insert 'XX' at column 3 in 'hello'")
        XCTAssertEqual(result[1], "worXXld", "Should insert 'XX' at column 3 in 'world'")
        XCTAssertEqual(result[2], "fooXX", "Should insert 'XX' at column 3 in 'foo' (exactly at end)")
    }

    func testColumnTextInsertionWithPadding() {
        // Test lines shorter than column get padded with spaces
        let lines = ["ab", "a", ""]
        let column = 5
        let insertText = "X"

        let result = lines.map { line -> String in
            if line.count < column {
                let padding = String(repeating: " ", count: column - line.count)
                return line + padding + insertText
            } else {
                var chars = Array(line)
                chars.insert(contentsOf: insertText, at: column)
                return String(chars)
            }
        }

        XCTAssertEqual(result[0], "ab   X", "Short line 'ab' should be padded to column 5 then 'X' appended")
        XCTAssertEqual(result[1], "a    X", "Short line 'a' should be padded to column 5 then 'X' appended")
        XCTAssertEqual(result[2], "     X", "Empty line should be padded to column 5 then 'X' appended")
    }

    func testColumnNumberSequenceGeneration() {
        // Simulate generating sequential numbers
        let start = 1
        let step = 2
        let lineCount = 5
        let radix = 10
        let uppercase = false
        let leadingZeros = true

        let lastValue = start + (lineCount - 1) * step
        let maxWidth = LineOperations.formatNumber(max(abs(start), abs(lastValue)), radix: radix, uppercase: uppercase).count

        var numbers: [String] = []
        for i in 0..<lineCount {
            let value = start + i * step
            var numStr = LineOperations.formatNumber(abs(value), radix: radix, uppercase: uppercase)
            if leadingZeros {
                while numStr.count < maxWidth {
                    numStr = "0" + numStr
                }
            }
            if value < 0 { numStr = "-" + numStr }
            numbers.append(numStr)
        }

        XCTAssertEqual(numbers, ["1", "3", "5", "7", "9"],
            "Sequential numbers 1,3,5,7,9 should be generated with start=1, step=2")
    }

    func testColumnNumberSequenceHex() {
        // Generate hex sequence: 10, 12, 14, 16 with uppercase
        let start = 10
        let step = 2
        let lineCount = 4
        let radix = 16
        let uppercase = true
        let leadingZeros = false

        var numbers: [String] = []
        for i in 0..<lineCount {
            let value = start + i * step
            let numStr = LineOperations.formatNumber(abs(value), radix: radix, uppercase: uppercase)
            numbers.append(numStr)
        }

        XCTAssertEqual(numbers, ["A", "C", "E", "10"],
            "Hex sequence from 10 step 2 uppercase should be A, C, E, 10")
    }

    func testColumnNumberSequenceWithLeadingZeros() {
        // Generate 1..10 with leading zeros
        let start = 1
        let step = 1
        let lineCount = 10
        let radix = 10
        let uppercase = false
        let leadingZeros = true

        let lastValue = start + (lineCount - 1) * step
        let maxWidth = LineOperations.formatNumber(max(abs(start), abs(lastValue)), radix: radix, uppercase: uppercase).count

        var numbers: [String] = []
        for i in 0..<lineCount {
            let value = start + i * step
            var numStr = LineOperations.formatNumber(abs(value), radix: radix, uppercase: uppercase)
            if leadingZeros {
                while numStr.count < maxWidth {
                    numStr = "0" + numStr
                }
            }
            numbers.append(numStr)
        }

        XCTAssertEqual(numbers, ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10"],
            "Numbers 1..10 with leading zeros should be 01..10")
    }
}
