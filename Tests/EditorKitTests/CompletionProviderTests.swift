import XCTest
@testable import EditorKit
@testable import SyntaxKit
import CommonKit

@available(macOS 13.0, *)
final class CompletionProviderTests: XCTestCase {

    // MARK: - Keyword Extraction

    func testExtractWordsFromKeywordPattern() {
        let provider = CompletionProvider()
        let pattern = "\\b(if|else|while|for|return)\\b"
        let words = provider.extractWords(from: pattern)
        XCTAssertEqual(Set(words), Set(["if", "else", "while", "for", "return"]))
    }

    func testExtractWordsFromCaseInsensitivePattern() {
        let provider = CompletionProvider()
        // SQL-style case-insensitive pattern
        let pattern = "\\b(?i:SELECT|FROM|WHERE)\\b"
        let words = provider.extractWords(from: pattern)
        XCTAssertEqual(Set(words), Set(["SELECT", "FROM", "WHERE"]))
    }

    func testExtractWordsReturnsEmptyForNonMatchingPattern() {
        let provider = CompletionProvider()
        let pattern = "[a-z]+"
        let words = provider.extractWords(from: pattern)
        XCTAssertTrue(words.isEmpty, "Non-keyword pattern should return empty")
    }

    func testExtractWordsFromEmptyPattern() {
        let provider = CompletionProvider()
        let words = provider.extractWords(from: "")
        XCTAssertTrue(words.isEmpty, "Empty pattern should return empty")
    }

    // MARK: - Load Keywords from LanguageDefinition

    func testLoadKeywordsFromSwift() {
        let provider = CompletionProvider()
        provider.loadKeywords(from: BuiltinLanguages.swift)

        XCTAssertTrue(provider.languageKeywords.contains("guard"), "Should contain Swift keyword 'guard'")
        XCTAssertTrue(provider.languageKeywords.contains("class"), "Should contain Swift keyword 'class'")
        XCTAssertTrue(provider.languageKeywords.contains("String"), "Should contain Swift type 'String'")
        XCTAssertTrue(provider.languageKeywords.contains("Int"), "Should contain Swift type 'Int'")
    }

    func testLoadKeywordsFromPython() {
        let provider = CompletionProvider()
        provider.loadKeywords(from: BuiltinLanguages.python)

        XCTAssertTrue(provider.languageKeywords.contains("def"), "Should contain Python keyword 'def'")
        XCTAssertTrue(provider.languageKeywords.contains("class"), "Should contain Python keyword 'class'")
        XCTAssertTrue(provider.languageKeywords.contains("import"), "Should contain Python keyword 'import'")
    }

    func testLoadKeywordsAreSorted() {
        let provider = CompletionProvider()
        provider.loadKeywords(from: BuiltinLanguages.swift)

        let sorted = provider.languageKeywords.sorted()
        XCTAssertEqual(provider.languageKeywords, sorted, "Keywords should be sorted alphabetically")
    }

    func testLoadKeywordsDeduplicates() {
        let provider = CompletionProvider()
        provider.loadKeywords(from: BuiltinLanguages.swift)

        let uniqueCount = Set(provider.languageKeywords).count
        XCTAssertEqual(provider.languageKeywords.count, uniqueCount, "Keywords should be deduplicated")
    }

    // MARK: - Document Word Extraction

    func testExtractDocumentWords() {
        let provider = CompletionProvider()
        let text = "let foo = bar + baz"
        let words = provider.extractDocumentWords(from: text)

        XCTAssertTrue(words.contains("let"), "Should find 'let'")
        XCTAssertTrue(words.contains("foo"), "Should find 'foo'")
        XCTAssertTrue(words.contains("bar"), "Should find 'bar'")
        XCTAssertTrue(words.contains("baz"), "Should find 'baz'")
    }

    func testExtractDocumentWordsIgnoresShortWords() {
        let provider = CompletionProvider()
        provider.minPrefixLength = 3
        let text = "a b cd efg"
        let words = provider.extractDocumentWords(from: text)

        XCTAssertFalse(words.contains("a"), "Single char should be excluded")
        XCTAssertFalse(words.contains("b"), "Single char should be excluded")
        XCTAssertFalse(words.contains("cd"), "Two char should be excluded with min 3")
        XCTAssertTrue(words.contains("efg"), "Three char should be included")
    }

    func testExtractDocumentWordsEmptyText() {
        let provider = CompletionProvider()
        let words = provider.extractDocumentWords(from: "")
        XCTAssertTrue(words.isEmpty, "Empty text should return no words")
    }

    func testExtractDocumentWordsWithUnderscores() {
        let provider = CompletionProvider()
        let text = "my_variable other_func"
        let words = provider.extractDocumentWords(from: text)

        XCTAssertTrue(words.contains("my_variable"), "Should recognize underscore identifiers")
        XCTAssertTrue(words.contains("other_func"), "Should recognize underscore identifiers")
    }

    // MARK: - Completions

    func testCompletionsMatchKeywords() {
        let provider = CompletionProvider()
        provider.languageKeywords = ["guard", "goto", "global", "get", "group"]

        let results = provider.completions(forPartialWord: "gu", in: "")
        XCTAssertTrue(results.contains("guard"), "Should suggest 'guard' for 'gu'")
        XCTAssertFalse(results.contains("get"), "'get' does not start with 'gu'")
    }

    func testCompletionsMatchDocumentWords() {
        let provider = CompletionProvider()
        let text = "let myVariable = 42\nprint(myVariable)"

        let results = provider.completions(forPartialWord: "myV", in: text)
        XCTAssertTrue(results.contains("myVariable"), "Should suggest 'myVariable' from document")
    }

    func testCompletionsCombineKeywordsAndDocumentWords() {
        let provider = CompletionProvider()
        provider.languageKeywords = ["function", "for", "finally"]

        let text = "let foo = 1\nlet fooBar = 2"
        let results = provider.completions(forPartialWord: "fo", in: text)

        XCTAssertTrue(results.contains("for"), "Should include keyword 'for'")
        XCTAssertTrue(results.contains("foo"), "Should include document word 'foo'")
        XCTAssertTrue(results.contains("fooBar"), "Should include document word 'fooBar'")
    }

    func testCompletionsDeduplicateResults() {
        let provider = CompletionProvider()
        provider.languageKeywords = ["return"]

        // 'return' appears both as keyword and in document
        let text = "return 42\nreturn nil"
        let results = provider.completions(forPartialWord: "ret", in: text)

        let returnCount = results.filter { $0 == "return" }.count
        XCTAssertEqual(returnCount, 1, "Should deduplicate 'return'")
    }

    func testCompletionsExcludeExactMatch() {
        let provider = CompletionProvider()
        provider.languageKeywords = ["for", "forEach"]

        let results = provider.completions(forPartialWord: "for", in: "")
        XCTAssertFalse(results.contains("for"), "Should not suggest exact same word")
        XCTAssertTrue(results.contains("forEach"), "Should suggest longer match")
    }

    func testCompletionsCappedAtMaxResults() {
        let provider = CompletionProvider()
        provider.maxResults = 5
        provider.languageKeywords = (0..<30).map { "keyword\($0)" }

        let results = provider.completions(forPartialWord: "ke", in: "")
        XCTAssertLesssThanOrEqual(results.count, 5, "Should cap at maxResults")
    }

    func testCompletionsReturnEmptyWhenDisabled() {
        let provider = CompletionProvider()
        provider.isEnabled = false
        provider.languageKeywords = ["guard", "goto"]

        let results = provider.completions(forPartialWord: "gu", in: "")
        XCTAssertTrue(results.isEmpty, "Should return empty when disabled")
    }

    func testCompletionsReturnEmptyForShortPrefix() {
        let provider = CompletionProvider()
        provider.minPrefixLength = 3
        provider.languageKeywords = ["if", "import", "in"]

        let results = provider.completions(forPartialWord: "i", in: "")
        XCTAssertTrue(results.isEmpty, "Should return empty for prefix shorter than minPrefixLength")
    }

    func testCompletionsCaseInsensitive() {
        let provider = CompletionProvider()
        provider.languageKeywords = ["String", "struct", "static"]

        let results = provider.completions(forPartialWord: "st", in: "")
        XCTAssertTrue(results.contains("String"), "Case-insensitive match should include 'String'")
        XCTAssertTrue(results.contains("struct"), "Should include 'struct'")
        XCTAssertTrue(results.contains("static"), "Should include 'static'")
    }

    // MARK: - Default Properties

    func testDefaultProperties() {
        let provider = CompletionProvider()
        XCTAssertTrue(provider.isEnabled, "Should be enabled by default")
        XCTAssertEqual(provider.minPrefixLength, 2, "Default minPrefixLength should be 2")
        XCTAssertEqual(provider.maxResults, 20, "Default maxResults should be 20")
        XCTAssertTrue(provider.languageKeywords.isEmpty, "Keywords should start empty")
    }

    // MARK: - Helpers

    /// XCTAssertLessThanOrEqual with a custom name to avoid conflicts.
    private func XCTAssertLesssThanOrEqual<T: Comparable>(
        _ a: T, _ b: T, _ message: String = "", file: StaticString = #file, line: UInt = #line
    ) {
        XCTAssertTrue(a <= b, "\(a) is not <= \(b). \(message)", file: file, line: line)
    }
}
