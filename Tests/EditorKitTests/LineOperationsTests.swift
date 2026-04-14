import XCTest
import AppKit
@testable import EditorKit

final class LineOperationsTests: XCTestCase {

    // MARK: - Helper

    /// Creates an NSTextView with the given text and selects all content.
    private func makeTextView(_ content: String) -> NSTextView {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        tv.string = content
        tv.setSelectedRange(NSRange(location: 0, length: (content as NSString).length))
        return tv
    }

    /// Returns the full string from a text view after an operation.
    private func text(of tv: NSTextView) -> String {
        return tv.string
    }

    // MARK: - Trim Trailing Whitespace

    func testTrimTrailingWhitespace_removesTrailingSpaces() {
        let tv = makeTextView("hello   \nworld\t\t\nfoo\n")
        LineOperations.trimTrailingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\nfoo\n")
    }

    func testTrimTrailingWhitespace_noTrailingSpaces() {
        let tv = makeTextView("hello\nworld\n")
        LineOperations.trimTrailingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\n")
    }

    func testTrimTrailingWhitespace_mixedWhitespace() {
        let tv = makeTextView("abc \t \n  def  \n")
        LineOperations.trimTrailingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "abc\n  def\n")
    }

    // MARK: - Trim Leading Whitespace

    func testTrimLeadingWhitespace_removesLeadingSpaces() {
        let tv = makeTextView("   hello\n\t\tworld\n  foo\n")
        LineOperations.trimLeadingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\nfoo\n")
    }

    func testTrimLeadingWhitespace_noLeadingSpaces() {
        let tv = makeTextView("hello\nworld\n")
        LineOperations.trimLeadingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\n")
    }

    func testTrimLeadingWhitespace_preservesTrailing() {
        let tv = makeTextView("  hello  \n\tworld\t\n")
        LineOperations.trimLeadingWhitespace(in: tv)
        XCTAssertEqual(text(of: tv), "hello  \nworld\t\n")
    }

    // MARK: - Insert Blank Line Above

    func testInsertBlankLineAbove() {
        let tv = makeTextView("hello\nworld\n")
        // Select first line
        tv.setSelectedRange(NSRange(location: 0, length: 1))
        LineOperations.insertBlankLineAbove(in: tv)
        XCTAssertEqual(text(of: tv), "\nhello\nworld\n")
    }

    // MARK: - Insert Blank Line Below

    func testInsertBlankLineBelow() {
        let tv = makeTextView("hello\nworld\n")
        // Select first line
        tv.setSelectedRange(NSRange(location: 0, length: 1))
        LineOperations.insertBlankLineBelow(in: tv)
        XCTAssertEqual(text(of: tv), "hello\n\nworld\n")
    }

    // MARK: - Tabs to Spaces

    func testTabsToSpaces_defaultWidth() {
        let tv = makeTextView("\thello\n\t\tworld\n")
        LineOperations.tabsToSpaces(in: tv)
        XCTAssertEqual(text(of: tv), "    hello\n        world\n")
    }

    func testTabsToSpaces_customWidth() {
        let tv = makeTextView("\thello\n")
        LineOperations.tabsToSpaces(in: tv, tabWidth: 2)
        XCTAssertEqual(text(of: tv), "  hello\n")
    }

    func testTabsToSpaces_noTabs() {
        let tv = makeTextView("hello\nworld\n")
        LineOperations.tabsToSpaces(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\n")
    }

    func testTabsToSpaces_tabInMiddle() {
        let tv = makeTextView("he\tllo\n")
        LineOperations.tabsToSpaces(in: tv)
        XCTAssertEqual(text(of: tv), "he    llo\n")
    }

    // MARK: - Spaces to Tabs

    func testSpacesToTabs_defaultWidth() {
        let tv = makeTextView("    hello\n        world\n")
        LineOperations.spacesToTabs(in: tv)
        XCTAssertEqual(text(of: tv), "\thello\n\t\tworld\n")
    }

    func testSpacesToTabs_customWidth() {
        let tv = makeTextView("  hello\n")
        LineOperations.spacesToTabs(in: tv, tabWidth: 2)
        XCTAssertEqual(text(of: tv), "\thello\n")
    }

    func testSpacesToTabs_partialGroup() {
        let tv = makeTextView("   hello\n")  // 3 spaces, tabWidth=4
        LineOperations.spacesToTabs(in: tv)
        XCTAssertEqual(text(of: tv), "   hello\n")  // not enough for a tab
    }

    func testSpacesToTabs_noLeadingSpaces() {
        let tv = makeTextView("hello\nworld\n")
        LineOperations.spacesToTabs(in: tv)
        XCTAssertEqual(text(of: tv), "hello\nworld\n")
    }

    // MARK: - Sort Lines Case Insensitive

    func testSortLinesCaseInsensitive_ascending() {
        let tv = makeTextView("Banana\napple\nCherry\n")
        LineOperations.sortLinesCaseInsensitive(in: tv)
        XCTAssertEqual(text(of: tv), "apple\nBanana\nCherry\n")
    }

    func testSortLinesCaseInsensitive_descending() {
        let tv = makeTextView("Banana\napple\nCherry\n")
        LineOperations.sortLinesCaseInsensitive(in: tv, ascending: false)
        XCTAssertEqual(text(of: tv), "Cherry\nBanana\napple\n")
    }

    func testSortLinesCaseInsensitive_alreadySorted() {
        let tv = makeTextView("alpha\nbeta\ngamma\n")
        LineOperations.sortLinesCaseInsensitive(in: tv)
        XCTAssertEqual(text(of: tv), "alpha\nbeta\ngamma\n")
    }

    // MARK: - Sort Lines by Length

    func testSortLinesByLength_ascending() {
        let tv = makeTextView("medium\nhi\nlongstring\n")
        LineOperations.sortLinesByLength(in: tv)
        XCTAssertEqual(text(of: tv), "hi\nmedium\nlongstring\n")
    }

    func testSortLinesByLength_descending() {
        let tv = makeTextView("medium\nhi\nlongstring\n")
        LineOperations.sortLinesByLength(in: tv, ascending: false)
        XCTAssertEqual(text(of: tv), "longstring\nmedium\nhi\n")
    }

    func testSortLinesByLength_sameLength() {
        let tv = makeTextView("abc\ndef\nghi\n")
        LineOperations.sortLinesByLength(in: tv)
        // All same length, order should be stable (or at least consistent)
        let result = text(of: tv)
        XCTAssertTrue(result.hasSuffix("\n"))
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 3)
    }

    // MARK: - Sort Lines as Integers

    func testSortLinesAsIntegers_ascending() {
        let tv = makeTextView("10\n2\n30\n1\n")
        LineOperations.sortLinesAsIntegers(in: tv)
        XCTAssertEqual(text(of: tv), "1\n2\n10\n30\n")
    }

    func testSortLinesAsIntegers_descending() {
        let tv = makeTextView("10\n2\n30\n1\n")
        LineOperations.sortLinesAsIntegers(in: tv, ascending: false)
        XCTAssertEqual(text(of: tv), "30\n10\n2\n1\n")
    }

    func testSortLinesAsIntegers_nonNumericGoToEnd() {
        let tv = makeTextView("5\nabc\n1\nxyz\n3\n")
        LineOperations.sortLinesAsIntegers(in: tv)
        let result = text(of: tv)
        let lines = result.components(separatedBy: "\n").filter { !$0.isEmpty }
        // Numeric lines should come first in order
        XCTAssertEqual(lines[0], "1")
        XCTAssertEqual(lines[1], "3")
        XCTAssertEqual(lines[2], "5")
        // Non-numeric at end
        XCTAssertTrue(lines[3] == "abc" || lines[3] == "xyz")
    }

    func testSortLinesAsIntegers_negativeNumbers() {
        let tv = makeTextView("5\n-3\n0\n-10\n")
        LineOperations.sortLinesAsIntegers(in: tv)
        XCTAssertEqual(text(of: tv), "-10\n-3\n0\n5\n")
    }

    // MARK: - Shuffle Lines

    func testShuffleLines_sameContent() {
        let tv = makeTextView("a\nb\nc\nd\ne\n")
        LineOperations.shuffleLines(in: tv)
        let result = text(of: tv)
        let lines = Set(result.components(separatedBy: "\n").filter { !$0.isEmpty })
        XCTAssertEqual(lines, Set(["a", "b", "c", "d", "e"]))
    }

    func testShuffleLines_singleLine() {
        let tv = makeTextView("only\n")
        LineOperations.shuffleLines(in: tv)
        XCTAssertEqual(text(of: tv), "only\n")
    }

    // MARK: - Remove Consecutive Duplicate Lines

    func testRemoveConsecutiveDuplicateLines_basic() {
        let tv = makeTextView("aaa\naaa\nbbb\nbbb\nbbb\nccc\n")
        LineOperations.removeConsecutiveDuplicateLines(in: tv)
        XCTAssertEqual(text(of: tv), "aaa\nbbb\nccc\n")
    }

    func testRemoveConsecutiveDuplicateLines_nonConsecutive() {
        let tv = makeTextView("aaa\nbbb\naaa\n")
        LineOperations.removeConsecutiveDuplicateLines(in: tv)
        XCTAssertEqual(text(of: tv), "aaa\nbbb\naaa\n")
    }

    func testRemoveConsecutiveDuplicateLines_allSame() {
        let tv = makeTextView("dup\ndup\ndup\n")
        LineOperations.removeConsecutiveDuplicateLines(in: tv)
        XCTAssertEqual(text(of: tv), "dup\n")
    }

    func testRemoveConsecutiveDuplicateLines_noDuplicates() {
        let tv = makeTextView("a\nb\nc\n")
        LineOperations.removeConsecutiveDuplicateLines(in: tv)
        XCTAssertEqual(text(of: tv), "a\nb\nc\n")
    }

    // MARK: - Copy Operations

    func testCopyFilePath() {
        let url = URL(fileURLWithPath: "/tmp/test/file.txt")
        LineOperations.copyFilePath(from: url)
        let pb = NSPasteboard.general
        XCTAssertEqual(pb.string(forType: .string), "/tmp/test/file.txt")
    }

    func testCopyFilePath_nil() {
        // Clear pasteboard first
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("before", forType: .string)
        LineOperations.copyFilePath(from: nil)
        // Should not change pasteboard
        XCTAssertEqual(pb.string(forType: .string), "before")
    }

    func testCopyFileName() {
        let url = URL(fileURLWithPath: "/tmp/test/file.txt")
        LineOperations.copyFileName(from: url)
        let pb = NSPasteboard.general
        XCTAssertEqual(pb.string(forType: .string), "file.txt")
    }

    func testCopyFileName_nil() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("before", forType: .string)
        LineOperations.copyFileName(from: nil)
        XCTAssertEqual(pb.string(forType: .string), "before")
    }

    func testCopyFileDirectory() {
        let url = URL(fileURLWithPath: "/tmp/test/file.txt")
        LineOperations.copyFileDirectory(from: url)
        let pb = NSPasteboard.general
        XCTAssertEqual(pb.string(forType: .string), "/tmp/test")
    }

    func testCopyFileDirectory_nil() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("before", forType: .string)
        LineOperations.copyFileDirectory(from: nil)
        XCTAssertEqual(pb.string(forType: .string), "before")
    }

    func testCopyFileDirectory_rootFile() {
        let url = URL(fileURLWithPath: "/file.txt")
        LineOperations.copyFileDirectory(from: url)
        let pb = NSPasteboard.general
        XCTAssertEqual(pb.string(forType: .string), "/")
    }
}
