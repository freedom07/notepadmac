import XCTest
@testable import SearchKit
import TextCore
import CommonKit

final class SearchKitTests: XCTestCase {

    let engine = SearchEngine()

    // MARK: - Basic Find

    func testBasicFind() {
        let results = engine.find(pattern: "hello", in: "hello world hello", options: SearchOptions())
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].matchedText, "hello")
        XCTAssertEqual(results[1].matchedText, "hello")
    }

    // MARK: - Case Insensitive

    func testCaseInsensitive() {
        let options = SearchOptions(caseSensitive: false)
        let results = engine.find(pattern: "Hello", in: "hello HELLO Hello", options: options)
        XCTAssertEqual(results.count, 3, "Case-insensitive search should match all variants")
    }

    // MARK: - Whole Word

    func testWholeWord() {
        let options = SearchOptions(wholeWord: true)
        let results = engine.find(pattern: "the", in: "the cat sat on the mat there", options: options)
        XCTAssertEqual(results.count, 2, "Whole-word search should not match 'there'")
    }

    // MARK: - Regex

    func testRegex() {
        let options = SearchOptions(useRegex: true)
        let results = engine.find(pattern: "\\d+", in: "abc 123 def 456", options: options)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].matchedText, "123")
        XCTAssertEqual(results[1].matchedText, "456")
    }

    // MARK: - Find Next / Previous

    func testFindNext() {
        let result = engine.findNext(pattern: "hello", in: "hello world hello", from: 6, options: SearchOptions())
        XCTAssertNotNil(result, "Should find match after offset 6")
        XCTAssertEqual(result?.matchedText, "hello")
    }

    func testFindPrevious() {
        let result = engine.findPrevious(pattern: "hello", in: "hello world hello", from: 16, options: SearchOptions())
        XCTAssertNotNil(result, "Should find match before offset 16")
        XCTAssertEqual(result?.matchedText, "hello")
    }

    // MARK: - Replace

    func testReplace() {
        let result = engine.replace(in: "foo baz foo", pattern: "foo", replacement: "bar", options: SearchOptions())
        XCTAssertEqual(result.newText, "bar baz foo", "Only the first occurrence should be replaced")
        XCTAssertEqual(result.count, 1)
    }

    func testReplaceAll() {
        let result = engine.replaceAll(in: "foo baz foo", pattern: "foo", replacement: "bar", options: SearchOptions())
        XCTAssertEqual(result.newText, "bar baz bar")
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - No Match

    func testNoMatch() {
        let results = engine.find(pattern: "xyz", in: "hello world", options: SearchOptions())
        XCTAssertTrue(results.isEmpty, "No matches should return empty results")
    }

    // MARK: - Edge Cases

    func testEmptyPattern() {
        let results = engine.find(pattern: "", in: "hello world", options: SearchOptions())
        XCTAssertTrue(results.isEmpty, "Empty pattern should return empty results")
    }

    func testEmptyText() {
        let results = engine.find(pattern: "hello", in: "", options: SearchOptions())
        XCTAssertTrue(results.isEmpty, "Search in empty text should return empty results")
    }

    func testInvalidRegex() {
        let options = SearchOptions(useRegex: true)
        let results = engine.find(pattern: "[invalid(", in: "hello world", options: options)
        XCTAssertTrue(results.isEmpty, "Invalid regex should not crash and should return empty results")
    }

    // MARK: - Extended Search Mode

    func testExtendedSearchNewline() {
        let options = SearchOptions(searchMode: .extended)
        let text = "hello\nworld"
        let results = engine.find(pattern: "hello\\nworld", in: text, options: options)
        XCTAssertEqual(results.count, 1, "Extended mode should match \\n as newline")
        XCTAssertEqual(results.first?.matchedText, "hello\nworld")
    }

    func testExtendedSearchTab() {
        let options = SearchOptions(searchMode: .extended)
        let text = "col1\tcol2"
        let results = engine.find(pattern: "col1\\tcol2", in: text, options: options)
        XCTAssertEqual(results.count, 1, "Extended mode should match \\t as tab")
        XCTAssertEqual(results.first?.matchedText, "col1\tcol2")
    }

    func testExtendedSearchCarriageReturn() {
        let options = SearchOptions(searchMode: .extended)
        let text = "line1\r\nline2"
        let results = engine.find(pattern: "line1\\r\\nline2", in: text, options: options)
        XCTAssertEqual(results.count, 1, "Extended mode should match \\r as carriage return")
        XCTAssertEqual(results.first?.matchedText, "line1\r\nline2")
    }

    func testExtendedSearchNull() {
        let options = SearchOptions(searchMode: .extended)
        let text = "a\0b"
        let results = engine.find(pattern: "a\\0b", in: text, options: options)
        XCTAssertEqual(results.count, 1, "Extended mode should match \\0 as null character")
        XCTAssertEqual(results.first?.matchedText, "a\0b")
    }

    func testExtendedSearchHex() {
        let options = SearchOptions(searchMode: .extended)
        // \x41 is 'A'
        let results = engine.find(pattern: "\\x41", in: "Hello A world", options: options)
        XCTAssertEqual(results.count, 1, "Extended mode \\x41 should match 'A'")
        XCTAssertEqual(results.first?.matchedText, "A")
    }

    func testExtendedSearchUnicode() {
        let options = SearchOptions(searchMode: .extended)
        // \u0041 is 'A'
        let results = engine.find(pattern: "\\u0041", in: "Hello A world", options: options)
        XCTAssertEqual(results.count, 1, "Extended mode \\u0041 should match 'A'")
        XCTAssertEqual(results.first?.matchedText, "A")
    }

    func testExtendedSearchBackslash() {
        let options = SearchOptions(searchMode: .extended)
        let text = "path\\to\\file"
        let results = engine.find(pattern: "path\\\\to\\\\file", in: text, options: options)
        XCTAssertEqual(results.count, 1, "Extended mode \\\\ should match literal backslash")
        XCTAssertEqual(results.first?.matchedText, "path\\to\\file")
    }

    func testExtendedSearchUnknownEscape() {
        let options = SearchOptions(searchMode: .extended)
        // \q is not a recognized escape — should be treated as literal 'q'
        let results = engine.find(pattern: "\\q", in: "q", options: options)
        XCTAssertEqual(results.count, 1, "Unknown escape \\q should match literal 'q'")
    }

    // MARK: - Backward Compatibility

    func testBackwardCompatibilityUseRegexGetter() {
        var options = SearchOptions(searchMode: .regex)
        XCTAssertTrue(options.useRegex, "useRegex should be true when searchMode is .regex")

        options.searchMode = .normal
        XCTAssertFalse(options.useRegex, "useRegex should be false when searchMode is .normal")

        options.searchMode = .extended
        XCTAssertFalse(options.useRegex, "useRegex should be false when searchMode is .extended")
    }

    func testBackwardCompatibilityUseRegexSetter() {
        var options = SearchOptions()
        options.useRegex = true
        XCTAssertEqual(options.searchMode, .regex, "Setting useRegex=true should set searchMode to .regex")

        options.useRegex = false
        XCTAssertEqual(options.searchMode, .normal, "Setting useRegex=false should set searchMode to .normal")
    }

    func testBackwardCompatibilityUseRegexInit() {
        let options = SearchOptions(useRegex: true)
        XCTAssertEqual(options.searchMode, .regex, "Init with useRegex=true should set searchMode to .regex")
        XCTAssertTrue(options.useRegex)
    }

    func testSearchModeEnum() {
        XCTAssertEqual(SearchMode.normal.rawValue, "normal")
        XCTAssertEqual(SearchMode.extended.rawValue, "extended")
        XCTAssertEqual(SearchMode.regex.rawValue, "regex")
    }

    // MARK: - Extended Mode with Other Options

    func testExtendedSearchCaseSensitive() {
        let options = SearchOptions(caseSensitive: true, searchMode: .extended)
        let results = engine.find(pattern: "\\x41", in: "a A a", options: options)
        XCTAssertEqual(results.count, 1, "Case-sensitive extended search for \\x41 should find only 'A'")
        XCTAssertEqual(results.first?.matchedText, "A")
    }

    func testExtendedSearchCaseInsensitive() {
        let options = SearchOptions(caseSensitive: false, searchMode: .extended)
        let results = engine.find(pattern: "\\x41", in: "a A a", options: options)
        XCTAssertEqual(results.count, 3, "Case-insensitive extended search for \\x41 should find 'a' and 'A'")
    }
}
