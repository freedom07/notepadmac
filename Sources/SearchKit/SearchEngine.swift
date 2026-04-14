// SearchEngine.swift
// SearchKit
//
// Copyright © 2026 NotepadNext. All rights reserved.
//

import Foundation
import TextCore
import CommonKit

// MARK: - SearchScope

/// Defines the scope in which a search operation is performed.
public enum SearchScope: Sendable, Equatable {
    /// Search within the currently active document.
    case currentDocument
    /// Search across all documents that are currently open.
    case allOpenDocuments
    /// Search only within the user's current text selection.
    case selection
}

// MARK: - SearchMode

/// Determines how the search pattern is interpreted.
public enum SearchMode: String, Sendable, Equatable {
    /// Plain text search — the pattern is matched literally.
    case normal
    /// Extended search — supports escape sequences such as `\n`, `\t`, `\r`, `\0`,
    /// `\xHH`, `\uHHHH`, and `\\`.
    case extended
    /// Regular expression search — the pattern is interpreted as an `NSRegularExpression`.
    case regex
}

// MARK: - SearchOptions

/// Configuration options that control search behavior.
public struct SearchOptions: Sendable, Equatable {

    /// When `true`, the search distinguishes between uppercase and lowercase characters.
    public var caseSensitive: Bool

    /// When `true`, the pattern matches only at word boundaries
    /// (e.g., searching for "test" will not match "testing").
    public var wholeWord: Bool

    /// Determines how the search pattern is interpreted.
    public var searchMode: SearchMode

    /// When `true`, the search wraps around to the beginning (or end) of the text
    /// after reaching the opposite boundary.
    public var wrapAround: Bool

    /// The scope in which the search is performed.
    public var searchScope: SearchScope

    /// Backward-compatible computed property.
    ///
    /// - Getting returns `true` when `searchMode` is `.regex`.
    /// - Setting `true` switches to `.regex`; setting `false` switches to `.normal`.
    public var useRegex: Bool {
        get { searchMode == .regex }
        set { searchMode = newValue ? .regex : .normal }
    }

    /// Creates a new `SearchOptions` instance with the specified parameters.
    ///
    /// - Parameters:
    ///   - caseSensitive: Whether the search is case-sensitive. Defaults to `false`.
    ///   - wholeWord: Whether to match whole words only. Defaults to `false`.
    ///   - searchMode: How the pattern is interpreted. Defaults to `.normal`.
    ///   - wrapAround: Whether the search wraps around. Defaults to `true`.
    ///   - searchScope: The scope of the search. Defaults to `.currentDocument`.
    public init(
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        searchMode: SearchMode = .normal,
        wrapAround: Bool = true,
        searchScope: SearchScope = .currentDocument
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.searchMode = searchMode
        self.wrapAround = wrapAround
        self.searchScope = searchScope
    }

    /// Backward-compatible initializer that accepts `useRegex` instead of `searchMode`.
    public init(
        caseSensitive: Bool = false,
        wholeWord: Bool = false,
        useRegex: Bool,
        wrapAround: Bool = true,
        searchScope: SearchScope = .currentDocument
    ) {
        self.caseSensitive = caseSensitive
        self.wholeWord = wholeWord
        self.searchMode = useRegex ? .regex : .normal
        self.wrapAround = wrapAround
        self.searchScope = searchScope
    }
}

// MARK: - SearchResult

/// Represents a single match found by a search operation.
public struct SearchResult: Sendable, Equatable {

    /// The character range of the match within the searched text.
    public let range: NSRange

    /// The 1-based line number where the match occurs.
    public let lineNumber: Int

    /// The full content of the line containing the match.
    public let lineContent: String

    /// The exact text that was matched.
    public let matchedText: String

    /// Creates a new `SearchResult`.
    ///
    /// - Parameters:
    ///   - range: The `NSRange` of the match in the source text.
    ///   - lineNumber: The 1-based line number of the match.
    ///   - lineContent: The full line containing the match.
    ///   - matchedText: The matched substring.
    public init(range: NSRange, lineNumber: Int, lineContent: String, matchedText: String) {
        self.range = range
        self.lineNumber = lineNumber
        self.lineContent = lineContent
        self.matchedText = matchedText
    }
}

// MARK: - SearchEngine

/// A search engine that provides find and replace capabilities for text content.
///
/// `SearchEngine` supports plain text search, whole-word matching, and regular expression
/// patterns. It can locate all matches in a body of text, navigate forward and backward
/// through matches, and perform single or bulk replacements.
///
/// Example usage:
/// ```swift
/// let engine = SearchEngine()
/// let options = SearchOptions(caseSensitive: true)
/// let results = engine.find(pattern: "Hello", in: "Hello, World! Hello!", options: options)
/// // results.count == 2
/// ```
@available(macOS 13.0, *)
public final class SearchEngine: Sendable {

    // MARK: - Initialization

    /// Creates a new `SearchEngine` instance.
    public init() {}

    // MARK: - Find All

    /// Finds all occurrences of the given pattern in the provided text.
    ///
    /// - Parameters:
    ///   - pattern: The search pattern (plain text or regular expression).
    ///   - text: The text to search within.
    ///   - options: The search options controlling match behavior.
    /// - Returns: An array of ``SearchResult`` values for each match found, ordered by position.
    public func find(pattern: String, in text: String, options: SearchOptions) -> [SearchResult] {
        guard !pattern.isEmpty, !text.isEmpty else { return [] }

        guard let regex = buildRegex(for: pattern, options: options) else { return [] }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)

        return matches.compactMap { match in
            buildResult(from: match.range, in: text, nsText: nsText)
        }
    }

    // MARK: - Find Next

    /// Finds the next occurrence of the pattern starting from the given character offset.
    ///
    /// When `options.wrapAround` is `true` and no match is found between the offset and
    /// the end of the text, the search continues from the beginning.
    ///
    /// - Parameters:
    ///   - pattern: The search pattern.
    ///   - text: The text to search within.
    ///   - offset: The character offset from which to begin searching forward.
    ///   - options: The search options.
    /// - Returns: The next ``SearchResult``, or `nil` if no match is found.
    public func findNext(
        pattern: String,
        in text: String,
        from offset: Int,
        options: SearchOptions
    ) -> SearchResult? {
        guard !pattern.isEmpty, !text.isEmpty else { return nil }
        guard let regex = buildRegex(for: pattern, options: options) else { return nil }

        let nsText = text as NSString
        let clampedOffset = min(max(offset, 0), nsText.length)

        // Search from offset to end.
        let forwardRange = NSRange(location: clampedOffset, length: nsText.length - clampedOffset)
        if let match = regex.firstMatch(in: text, range: forwardRange) {
            return buildResult(from: match.range, in: text, nsText: nsText)
        }

        // Wrap around: search from start to offset.
        if options.wrapAround, clampedOffset > 0 {
            let wrapRange = NSRange(location: 0, length: clampedOffset)
            if let match = regex.firstMatch(in: text, range: wrapRange) {
                return buildResult(from: match.range, in: text, nsText: nsText)
            }
        }

        return nil
    }

    // MARK: - Find Previous

    /// Finds the previous occurrence of the pattern searching backward from the given offset.
    ///
    /// When `options.wrapAround` is `true` and no match is found between the beginning
    /// of the text and the offset, the search continues from the end.
    ///
    /// - Parameters:
    ///   - pattern: The search pattern.
    ///   - text: The text to search within.
    ///   - offset: The character offset from which to begin searching backward.
    ///   - options: The search options.
    /// - Returns: The previous ``SearchResult``, or `nil` if no match is found.
    public func findPrevious(
        pattern: String,
        in text: String,
        from offset: Int,
        options: SearchOptions
    ) -> SearchResult? {
        guard !pattern.isEmpty, !text.isEmpty else { return nil }
        guard let regex = buildRegex(for: pattern, options: options) else { return nil }

        let nsText = text as NSString
        let clampedOffset = min(max(offset, 0), nsText.length)

        // Collect all matches before the offset and return the last one.
        let beforeRange = NSRange(location: 0, length: clampedOffset)
        let matchesBefore = regex.matches(in: text, range: beforeRange)
        if let lastMatch = matchesBefore.last {
            return buildResult(from: lastMatch.range, in: text, nsText: nsText)
        }

        // Wrap around: search from offset to end and return the last match.
        if options.wrapAround, clampedOffset < nsText.length {
            let afterRange = NSRange(location: clampedOffset, length: nsText.length - clampedOffset)
            let matchesAfter = regex.matches(in: text, range: afterRange)
            if let lastMatch = matchesAfter.last {
                return buildResult(from: lastMatch.range, in: text, nsText: nsText)
            }
        }

        return nil
    }

    // MARK: - Replace (Single)

    /// Replaces the first occurrence of the pattern with the given replacement string.
    ///
    /// - Parameters:
    ///   - text: The source text.
    ///   - pattern: The search pattern.
    ///   - replacement: The replacement string. When `options.useRegex` is `true`,
    ///     back-references such as `$1` are supported.
    ///   - options: The search options.
    /// - Returns: A tuple containing the modified text and the number of replacements made (0 or 1).
    public func replace(
        in text: String,
        pattern: String,
        replacement: String,
        options: SearchOptions
    ) -> (newText: String, count: Int) {
        guard !pattern.isEmpty, !text.isEmpty else { return (text, 0) }
        guard let regex = buildRegex(for: pattern, options: options) else { return (text, 0) }

        let effectiveReplacement: String
        if options.searchMode == .extended {
            effectiveReplacement = expandExtendedEscapes(replacement)
        } else {
            effectiveReplacement = replacement
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        guard let match = regex.firstMatch(in: text, range: fullRange) else {
            return (text, 0)
        }

        let replacementString = regex.replacementString(
            for: match,
            in: text,
            offset: 0,
            template: effectiveReplacement
        )

        let mutableText = NSMutableString(string: text)
        mutableText.replaceCharacters(in: match.range, with: replacementString)

        return (mutableText as String, 1)
    }

    // MARK: - Replace All

    /// Replaces all occurrences of the pattern with the given replacement string.
    ///
    /// Replacements are applied from last to first to preserve character offsets.
    ///
    /// - Parameters:
    ///   - text: The source text.
    ///   - pattern: The search pattern.
    ///   - replacement: The replacement string. When `options.useRegex` is `true`,
    ///     back-references such as `$1` are supported.
    ///   - options: The search options.
    /// - Returns: A tuple containing the modified text and the total number of replacements made.
    public func replaceAll(
        in text: String,
        pattern: String,
        replacement: String,
        options: SearchOptions
    ) -> (newText: String, count: Int) {
        guard !pattern.isEmpty, !text.isEmpty else { return (text, 0) }
        guard let regex = buildRegex(for: pattern, options: options) else { return (text, 0) }

        let effectiveReplacement: String
        if options.searchMode == .extended {
            effectiveReplacement = expandExtendedEscapes(replacement)
        } else {
            effectiveReplacement = replacement
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)

        guard !matches.isEmpty else { return (text, 0) }

        let mutableText = NSMutableString(string: text)

        // Apply replacements in reverse order to maintain valid ranges.
        for match in matches.reversed() {
            let replacementString = regex.replacementString(
                for: match,
                in: text,
                offset: 0,
                template: effectiveReplacement
            )
            mutableText.replaceCharacters(in: match.range, with: replacementString)
        }

        return (mutableText as String, matches.count)
    }

    // MARK: - Private Helpers

    /// Builds an `NSRegularExpression` from the given pattern and options.
    ///
    /// Behavior depends on the current ``SearchMode``:
    /// - `.normal`: the pattern is escaped for literal matching.
    /// - `.extended`: escape sequences are expanded first, then the result is escaped.
    /// - `.regex`: the pattern is used as-is.
    ///
    /// When `wholeWord` is enabled the pattern is wrapped with `\b` anchors.
    ///
    /// - Parameters:
    ///   - pattern: The raw search pattern.
    ///   - options: The search options.
    /// - Returns: A compiled `NSRegularExpression`, or `nil` if the pattern is invalid.
    private func buildRegex(
        for pattern: String,
        options: SearchOptions
    ) -> NSRegularExpression? {
        var regexPattern: String

        switch options.searchMode {
        case .normal:
            regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        case .extended:
            let expanded = expandExtendedEscapes(pattern)
            regexPattern = NSRegularExpression.escapedPattern(for: expanded)
        case .regex:
            regexPattern = pattern
        }

        if options.wholeWord {
            regexPattern = "\\b\(regexPattern)\\b"
        }

        var regexOptions: NSRegularExpression.Options = []
        if !options.caseSensitive {
            regexOptions.insert(.caseInsensitive)
        }

        return try? NSRegularExpression(pattern: regexPattern, options: regexOptions)
    }

    /// Expands escape sequences used in extended search mode.
    ///
    /// Recognized sequences:
    /// - `\n` → line feed (U+000A)
    /// - `\r` → carriage return (U+000D)
    /// - `\t` → horizontal tab (U+0009)
    /// - `\0` → null (U+0000)
    /// - `\xHH` → Unicode scalar from two hex digits
    /// - `\uHHHH` → Unicode scalar from four hex digits
    /// - `\\` → literal backslash
    /// - Any other `\X` → literal `X`
    ///
    /// - Parameter pattern: The raw extended-mode pattern.
    /// - Returns: A string with escape sequences replaced by their literal characters.
    public func expandExtendedEscapes(_ pattern: String) -> String {
        var result = ""
        var iterator = pattern.makeIterator()

        while let ch = iterator.next() {
            guard ch == "\\" else {
                result.append(ch)
                continue
            }

            // Consume the character after the backslash.
            guard let next = iterator.next() else {
                // Trailing backslash with nothing after it — keep literal backslash.
                result.append("\\")
                break
            }

            switch next {
            case "n":
                result.append("\u{000A}")
            case "r":
                result.append("\u{000D}")
            case "t":
                result.append("\u{0009}")
            case "0":
                result.append("\u{0000}")
            case "\\":
                result.append("\\")
            case "x":
                // Expect exactly 2 hex digits.
                var hex = ""
                for _ in 0..<2 {
                    guard let h = iterator.next() else { break }
                    hex.append(h)
                }
                if hex.count == 2, let value = UInt32(hex, radix: 16),
                   let scalar = Unicode.Scalar(value) {
                    result.append(Character(scalar))
                } else {
                    // Invalid hex — emit the raw characters.
                    result.append("\\x")
                    result.append(hex)
                }
            case "u":
                // Expect exactly 4 hex digits.
                var hex = ""
                for _ in 0..<4 {
                    guard let h = iterator.next() else { break }
                    hex.append(h)
                }
                if hex.count == 4, let value = UInt32(hex, radix: 16),
                   let scalar = Unicode.Scalar(value) {
                    result.append(Character(scalar))
                } else {
                    // Invalid unicode escape — emit the raw characters.
                    result.append("\\u")
                    result.append(hex)
                }
            default:
                // Unknown escape — emit the character literally.
                result.append(next)
            }
        }

        return result
    }

    /// Constructs a ``SearchResult`` from a match range and the source text.
    ///
    /// - Parameters:
    ///   - range: The `NSRange` of the match.
    ///   - text: The full source text as a Swift `String`.
    ///   - nsText: The source text as an `NSString` for efficient range operations.
    /// - Returns: A ``SearchResult``, or `nil` if the range is invalid.
    private func buildResult(
        from range: NSRange,
        in text: String,
        nsText: NSString
    ) -> SearchResult? {
        guard range.location != NSNotFound,
              range.location + range.length <= nsText.length else {
            return nil
        }

        let matchedText = nsText.substring(with: range)

        // Determine the 1-based line number by counting newlines before the match.
        let prefixRange = NSRange(location: 0, length: range.location)
        let prefix = nsText.substring(with: prefixRange)
        // Normalize CRLF to LF before counting lines to avoid double-counting
        let normalizedPrefix = prefix.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lineNumber = normalizedPrefix.components(separatedBy: "\n").count

        // Extract the full line containing the match.
        let lineRange = nsText.lineRange(for: range)
        var lineContent = nsText.substring(with: lineRange)

        // Strip trailing newline characters from the line content.
        while lineContent.hasSuffix("\n") || lineContent.hasSuffix("\r") {
            lineContent.removeLast()
        }

        return SearchResult(
            range: range,
            lineNumber: lineNumber,
            lineContent: lineContent,
            matchedText: matchedText
        )
    }
}
