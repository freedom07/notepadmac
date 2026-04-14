// CompletionProvider.swift
// EditorKit — NotepadNext
//
// Provides auto-completion suggestions from language keywords and
// document words. Integrates with NSTextView's built-in completion
// support via `completions(forPartialWordRange:indexOfSelectedItem:)`.

import Foundation
import SyntaxKit

// MARK: - CompletionProvider

/// Supplies auto-completion candidates by combining language keywords
/// with words found in the current document.
///
/// Usage:
/// ```swift
/// let provider = CompletionProvider()
/// provider.loadKeywords(from: swiftLanguage)
/// let suggestions = provider.completions(forPartialWord: "gu", in: documentText)
/// // ["guard"]
/// ```
@available(macOS 13.0, *)
public final class CompletionProvider {

    // MARK: - Public Properties

    /// The language keywords available for completion.
    public var languageKeywords: [String] = []

    /// Master toggle. When `false`, `completions(forPartialWord:in:)` returns
    /// an empty array.
    public var isEnabled: Bool = true

    /// Minimum partial word length required to trigger completions.
    /// Defaults to 2 to avoid noisy single-character suggestions.
    public var minPrefixLength: Int = 2

    /// Maximum number of completions to return.
    public var maxResults: Int = 20

    // MARK: - Init

    public init() {}

    // MARK: - Keyword Loading

    /// Extracts keywords from a ``LanguageDefinition``'s highlight rules.
    ///
    /// Parses keyword and type rules that use the `\b(word1|word2|...)\b`
    /// pattern and collects individual words.
    ///
    /// - Parameter language: The language definition to extract keywords from.
    public func loadKeywords(from language: LanguageDefinition) {
        var keywords: Set<String> = []

        for rule in language.rules {
            guard rule.tokenType == .keyword || rule.tokenType == .type else {
                continue
            }
            let extracted = extractWords(from: rule.pattern)
            keywords.formUnion(extracted)
        }

        languageKeywords = keywords.sorted()
    }

    // MARK: - Completion

    /// Provides completion candidates for the given partial word.
    ///
    /// The results combine language keywords and unique document words
    /// that start with the partial prefix. Results are deduplicated,
    /// sorted alphabetically, and capped at ``maxResults``.
    ///
    /// - Parameters:
    ///   - partial: The partial word typed by the user.
    ///   - text: The full document text to scan for additional words.
    /// - Returns: An array of completion strings, or empty if disabled or
    ///   the prefix is too short.
    public func completions(forPartialWord partial: String, in text: String) -> [String] {
        guard isEnabled, partial.count >= minPrefixLength else { return [] }

        let lowercasePartial = partial.lowercased()

        // 1. Match language keywords starting with partial (case-insensitive).
        var candidates: Set<String> = []
        for keyword in languageKeywords {
            if keyword.lowercased().hasPrefix(lowercasePartial) && keyword != partial {
                candidates.insert(keyword)
            }
        }

        // 2. Scan document for unique words starting with partial.
        let documentWords = extractDocumentWords(from: text)
        for word in documentWords {
            if word.lowercased().hasPrefix(lowercasePartial) && word != partial {
                candidates.insert(word)
            }
        }

        // 3. Sort and cap results.
        let sorted = candidates.sorted { lhs, rhs in
            // Prioritize exact-case matches
            let lhsExact = lhs.hasPrefix(partial)
            let rhsExact = rhs.hasPrefix(partial)
            if lhsExact != rhsExact { return lhsExact }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return Array(sorted.prefix(maxResults))
    }

    // MARK: - Internal (visible for testing)

    /// Extracts individual words from a `\b(word1|word2|...)\b` regex pattern.
    ///
    /// Also handles case-insensitive SQL-style patterns like `\b(?i:SELECT|FROM|...)\b`.
    ///
    /// - Parameter pattern: The regex pattern string.
    /// - Returns: An array of extracted words.
    internal func extractWords(from pattern: String) -> [String] {
        // Match content inside \b(...)\b or \b(?i:...)\b
        guard let regex = try? NSRegularExpression(
            pattern: #"\\b\((?:\?[imsxU]*:)?([^)]+)\)\\b"#,
            options: []
        ) else { return [] }

        let nsPattern = pattern as NSString
        let fullRange = NSRange(location: 0, length: nsPattern.length)

        guard let match = regex.firstMatch(in: pattern, range: fullRange) else {
            return []
        }

        let captureRange = match.range(at: 1)
        guard captureRange.location != NSNotFound else { return [] }

        let captured = nsPattern.substring(with: captureRange)
        let words = captured.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0 == "_" || $0.isNumber || $0 == "?" || $0 == "." } }

        return words
    }

    /// Extracts unique words (identifier-like tokens) from document text.
    ///
    /// - Parameter text: The document text.
    /// - Returns: A set of unique words found in the document.
    internal func extractDocumentWords(from text: String) -> Set<String> {
        guard !text.isEmpty else { return [] }

        guard let regex = try? NSRegularExpression(
            pattern: "[a-zA-Z_][a-zA-Z0-9_]*",
            options: []
        ) else { return [] }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)

        var words: Set<String> = []
        for match in matches {
            let word = nsText.substring(with: match.range)
            if word.count >= minPrefixLength {
                words.insert(word)
            }
        }

        return words
    }
}
