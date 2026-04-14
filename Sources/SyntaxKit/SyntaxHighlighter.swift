// SyntaxHighlighter.swift
// SyntaxKit — NotepadNext
//
// Applies regex-based syntax highlighting to an NSTextStorage.
// Evaluates HighlightRules in order and paints foreground colors
// according to the active theme. Multi-line constructs (block
// comments, multi-line strings) are handled by the rules' regexes
// which use [\s\S]*? to span lines.

import AppKit
import Foundation
import CommonKit

// MARK: - SyntaxHighlighter

/// Applies token-based syntax highlighting to an `NSTextStorage`.
///
/// Usage:
/// ```swift
/// let highlighter = SyntaxHighlighter()
/// highlighter.language = LanguageRegistry.shared.language(forExtension: "swift")
/// highlighter.setDefaultTheme()
/// highlighter.highlight(textStorage, in: textStorage.fullRange)
/// ```
public final class SyntaxHighlighter {

    // MARK: Properties

    /// The language definition whose rules drive highlighting.
    /// Set to `nil` to disable highlighting.
    public var language: LanguageDefinition?

    /// Maps each ``TokenType`` to a dictionary of `NSAttributedString.Key`
    /// attributes (typically `.foregroundColor`).
    public var theme: [TokenType: [NSAttributedString.Key: Any]] = [:]

    /// Base attributes applied to the entire range before token colors.
    /// Consumers should set `.font` and `.foregroundColor` for the plain
    /// text appearance.
    public var baseAttributes: [NSAttributedString.Key: Any] = [:]

    // MARK: Regex Cache

    /// Cached compiled regexes paired with their token types.
    /// Rebuilt only when the language changes.
    private var compiledRules: [(NSRegularExpression, TokenType)]?

    /// Tracks which language the cached regexes were compiled for.
    private var lastLanguageId: String?

    // MARK: Init

    public init() {}

    // MARK: Highlighting

    /// Apply syntax highlighting to `textStorage` within the given range.
    ///
    /// The method:
    /// 1. Clears existing foreground-color attributes in the range.
    /// 2. Re-applies `baseAttributes` so un-matched text keeps its default look.
    /// 3. Iterates through the language's rules in order. For each regex
    ///    match that has not already been claimed by an earlier rule the
    ///    token's theme attributes are applied.
    ///
    /// Because rules are evaluated in declaration order, put comments and
    /// strings first so that keywords inside them are not highlighted.
    ///
    /// - Parameters:
    ///   - textStorage: The text storage to modify.
    ///   - range: The character range to highlight. Pass the full range
    ///     for initial highlighting; pass an edited range for incremental
    ///     updates.
    public func highlight(_ textStorage: NSTextStorage, in range: NSRange) {
        guard let language = language else { return }

        let fullText = textStorage.string
        let nsString = fullText as NSString

        // Clamp the range to the text storage length.
        let clampedRange = NSIntersectionRange(range, NSRange(location: 0, length: nsString.length))
        guard clampedRange.length > 0 else { return }

        // Expand the working range to cover complete lines so that
        // multi-line constructs (block comments, strings) are handled
        // correctly even on incremental updates.
        let lineRange = nsString.lineRange(for: clampedRange)

        textStorage.beginEditing()

        // 1. Clear existing token attributes in the working range.
        textStorage.removeAttribute(.foregroundColor, range: lineRange)

        // 2. Apply base attributes.
        if !baseAttributes.isEmpty {
            textStorage.addAttributes(baseAttributes, range: lineRange)
        }

        // 3. Rebuild compiled regexes if the language changed.
        if language.id != lastLanguageId {
            compiledRules = language.rules.compactMap { rule in
                guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: [.anchorsMatchLines]) else { return nil }
                return (regex, rule.tokenType)
            }
            lastLanguageId = language.id
        }

        // 4. Track which character positions have already been claimed
        //    by an earlier rule so that, e.g., keywords inside strings
        //    or comments are not over-painted.
        var claimed = IndexSet()

        // Use cached compiled regexes.
        guard let rules = compiledRules else { return }
        for (regex, tokenType) in rules {
            guard let attrs = theme[tokenType], !attrs.isEmpty else { continue }

            regex.enumerateMatches(
                in: fullText,
                options: [],
                range: lineRange
            ) { match, _, _ in
                guard let matchRange = match?.range, matchRange.length > 0 else { return }

                // Skip if any part of the match is already claimed.
                let matchIndexRange = matchRange.location ..< (matchRange.location + matchRange.length)
                if claimed.contains(integersIn: matchIndexRange) {
                    return
                }

                // Apply attributes and claim the range.
                textStorage.addAttributes(attrs, range: matchRange)
                claimed.insert(integersIn: matchIndexRange)
            }
        }

        textStorage.endEditing()
    }

    // MARK: Default Theme

    /// Configures a default dark-mode color theme.
    ///
    /// The colors are inspired by popular dark editor themes and provide
    /// good contrast on a dark background.
    public func setDefaultTheme() {
        theme = [
            .keyword:       [.foregroundColor: NSColor(red: 0.78, green: 0.46, blue: 0.86, alpha: 1.0)],  // purple
            .string:        [.foregroundColor: NSColor(red: 0.81, green: 0.54, blue: 0.36, alpha: 1.0)],  // orange
            .comment:       [.foregroundColor: NSColor(red: 0.45, green: 0.50, blue: 0.55, alpha: 1.0)],  // grey
            .number:        [.foregroundColor: NSColor(red: 0.69, green: 0.78, blue: 0.45, alpha: 1.0)],  // green
            .type:          [.foregroundColor: NSColor(red: 0.31, green: 0.73, blue: 0.87, alpha: 1.0)],  // cyan
            .function:      [.foregroundColor: NSColor(red: 0.38, green: 0.65, blue: 0.89, alpha: 1.0)],  // blue
            .variable:      [.foregroundColor: NSColor(red: 0.90, green: 0.86, blue: 0.73, alpha: 1.0)],  // light yellow
            .`operator`:    [.foregroundColor: NSColor(red: 0.80, green: 0.80, blue: 0.80, alpha: 1.0)],  // light grey
            .punctuation:   [.foregroundColor: NSColor(red: 0.65, green: 0.65, blue: 0.65, alpha: 1.0)],  // mid grey
            .preprocessor:  [.foregroundColor: NSColor(red: 0.87, green: 0.44, blue: 0.46, alpha: 1.0)],  // red
            .attribute:     [.foregroundColor: NSColor(red: 0.60, green: 0.80, blue: 0.60, alpha: 1.0)],  // soft green
            .tag:           [.foregroundColor: NSColor(red: 0.87, green: 0.44, blue: 0.46, alpha: 1.0)],  // red
            .plain:         [.foregroundColor: NSColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)],  // off-white
        ]
    }
}
