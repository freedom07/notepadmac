// TextMarker.swift
// SearchKit — NotepadNext
//
// Highlights all occurrences of a search pattern with colored marks,
// supporting up to 5 independent mark styles for simultaneous highlighting.
// Uses layoutManager.addTemporaryAttribute to avoid modifying text storage.

import AppKit
import CommonKit

// MARK: - TextMarker

/// Manages persistent "mark all occurrences" highlights in a text view.
///
/// Unlike ``SmartHighlighter`` (which auto-highlights the word under the cursor),
/// `TextMarker` lets the user explicitly mark all occurrences of a search pattern
/// using one of five color styles. Multiple patterns can be marked simultaneously
/// in different colors.
///
/// Uses `NSLayoutManager.addTemporaryAttribute` so marks don't interfere with
/// text storage attributes or syntax highlighting.
///
/// ```swift
/// let marker = TextMarker()
/// marker.markAll(
///     pattern: "TODO",
///     in: layoutManager,
///     textLength: text.count,
///     style: .style1,
///     options: SearchOptions()
/// )
/// ```
@available(macOS 13.0, *)
public final class TextMarker {

    // MARK: - MarkStyle

    /// One of five available mark styles, each with a distinct highlight color.
    public enum MarkStyle: Int, CaseIterable, Sendable {
        case style1 = 1, style2, style3, style4, style5
    }

    // MARK: - Style Colors

    /// The highlight colors associated with each mark style.
    public static let styleColors: [MarkStyle: NSColor] = [
        .style1: NSColor.systemOrange.withAlphaComponent(0.3),
        .style2: NSColor.systemGreen.withAlphaComponent(0.3),
        .style3: NSColor.systemBlue.withAlphaComponent(0.3),
        .style4: NSColor.systemPink.withAlphaComponent(0.3),
        .style5: NSColor.systemPurple.withAlphaComponent(0.3),
    ]

    // MARK: - State

    /// Tracks marked ranges per style for navigation and clearing.
    private(set) var marks: [MarkStyle: [NSRange]] = [:]

    // MARK: - Init

    public init() {}

    // MARK: - Mark All

    /// Highlights all occurrences of the given pattern in the layout manager.
    ///
    /// Any existing marks for the specified style are cleared first. The pattern
    /// is matched using the provided search options (case sensitivity, whole word,
    /// regex mode).
    ///
    /// - Parameters:
    ///   - pattern: The search pattern to highlight.
    ///   - layoutManager: The layout manager to apply temporary attributes to.
    ///   - textLength: The length of the text in UTF-16 code units.
    ///   - style: The mark style (color) to use.
    ///   - options: Search options controlling how the pattern is matched.
    /// - Returns: The number of occurrences marked.
    @discardableResult
    public func markAll(
        pattern: String,
        in layoutManager: NSLayoutManager,
        textLength: Int,
        style: MarkStyle,
        options: SearchOptions
    ) -> Int {
        // Clear existing marks for this style first.
        clearMarks(style: style, in: layoutManager, textLength: textLength)

        guard !pattern.isEmpty, textLength > 0 else { return 0 }

        // Build regex from pattern and options.
        guard let regex = buildRegex(for: pattern, options: options) else { return 0 }

        let textStorage = layoutManager.textStorage
        guard let text = textStorage?.string else { return 0 }

        let fullRange = NSRange(location: 0, length: textLength)
        let matches = regex.matches(in: text, range: fullRange)

        guard !matches.isEmpty else { return 0 }

        let color = Self.styleColors[style] ?? NSColor.systemOrange.withAlphaComponent(0.3)
        var ranges: [NSRange] = []

        for match in matches {
            let range = match.range
            guard range.location != NSNotFound,
                  range.location + range.length <= textLength else { continue }
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: color,
                forCharacterRange: range
            )
            ranges.append(range)
        }

        marks[style] = ranges
        return ranges.count
    }

    // MARK: - Clear Marks

    /// Removes all marks for the specified style.
    ///
    /// - Parameters:
    ///   - style: The mark style to clear.
    ///   - layoutManager: The layout manager to remove temporary attributes from.
    ///   - textLength: The length of the text in UTF-16 code units.
    public func clearMarks(style: MarkStyle, in layoutManager: NSLayoutManager, textLength: Int) {
        guard let ranges = marks[style], !ranges.isEmpty else {
            marks[style] = nil
            return
        }

        for range in ranges {
            let clamped = NSIntersectionRange(range, NSRange(location: 0, length: textLength))
            if clamped.length > 0 {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: clamped)
            }
        }

        marks[style] = nil
    }

    /// Removes all marks across all styles.
    ///
    /// - Parameters:
    ///   - layoutManager: The layout manager to remove temporary attributes from.
    ///   - textLength: The length of the text in UTF-16 code units.
    public func clearAllMarks(in layoutManager: NSLayoutManager, textLength: Int) {
        for style in MarkStyle.allCases {
            clearMarks(style: style, in: layoutManager, textLength: textLength)
        }
    }

    // MARK: - Navigation

    /// Finds the next mark after the given character offset for a style.
    ///
    /// Returns the first mark whose start location is strictly after `offset`.
    /// Wraps around to the beginning if no mark is found after the offset.
    ///
    /// - Parameters:
    ///   - offset: The current character offset.
    ///   - style: The mark style to navigate.
    /// - Returns: The range of the next mark, or `nil` if no marks exist.
    public func nextMark(after offset: Int, style: MarkStyle) -> NSRange? {
        guard let ranges = marks[style], !ranges.isEmpty else { return nil }

        let sorted = ranges.sorted { $0.location < $1.location }

        // Find the first mark after offset.
        if let found = sorted.first(where: { $0.location > offset }) {
            return found
        }

        // Wrap around to the first mark.
        return sorted.first
    }

    /// Finds the previous mark before the given character offset for a style.
    ///
    /// Returns the last mark whose start location is strictly before `offset`.
    /// Wraps around to the end if no mark is found before the offset.
    ///
    /// - Parameters:
    ///   - offset: The current character offset.
    ///   - style: The mark style to navigate.
    /// - Returns: The range of the previous mark, or `nil` if no marks exist.
    public func previousMark(before offset: Int, style: MarkStyle) -> NSRange? {
        guard let ranges = marks[style], !ranges.isEmpty else { return nil }

        let sorted = ranges.sorted { $0.location < $1.location }

        // Find the last mark before offset.
        if let found = sorted.last(where: { $0.location < offset }) {
            return found
        }

        // Wrap around to the last mark.
        return sorted.last
    }

    // MARK: - Query

    /// Returns the number of marks for the given style.
    public func markCount(for style: MarkStyle) -> Int {
        marks[style]?.count ?? 0
    }

    /// Returns `true` if any marks exist across all styles.
    public var hasMarks: Bool {
        marks.values.contains { !$0.isEmpty }
    }

    // MARK: - Private Helpers

    /// Builds an `NSRegularExpression` from the given pattern and options.
    private func buildRegex(
        for pattern: String,
        options: SearchOptions
    ) -> NSRegularExpression? {
        var regexPattern: String

        if options.useRegex {
            regexPattern = pattern
        } else {
            regexPattern = NSRegularExpression.escapedPattern(for: pattern)
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
}
