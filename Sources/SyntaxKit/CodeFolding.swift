// CodeFolding.swift
// SyntaxKit — NotepadNext
//
// Detects foldable regions in source code: brace-delimited blocks,
// indentation-based blocks (Python, YAML), multi-line comments,
// and explicit #region / #endregion markers.

import Foundation
import CommonKit

// MARK: - FoldRegion

/// A contiguous range of source lines that can be collapsed in the editor.
public struct FoldRegion: Sendable, Equatable {

    /// Kinds of foldable regions.
    public enum Kind: String, Sendable {
        /// A block delimited by braces `{ }` or by indentation level.
        case block
        /// A multi-line comment.
        case comment
        /// An explicit region marker (`#region` / `#endregion`).
        case region
    }

    /// Zero-based index of the first line in the fold.
    public let startLine: Int

    /// Zero-based index of the last line in the fold (inclusive).
    public let endLine: Int

    /// What kind of construct this fold represents.
    public let kind: Kind

    /// Whether the region is currently collapsed in the editor.
    public var isCollapsed: Bool

    public init(startLine: Int, endLine: Int, kind: Kind, isCollapsed: Bool = false) {
        self.startLine = startLine
        self.endLine = endLine
        self.kind = kind
        self.isCollapsed = isCollapsed
    }
}

// MARK: - CodeFoldingProvider

/// Computes ``FoldRegion``s for a given source text.
public final class CodeFoldingProvider {

    public init() {}

    /// Compute all foldable regions in `text` using the supplied language
    /// definition (if any) to choose a folding strategy.
    ///
    /// The returned array is sorted by `startLine`.
    ///
    /// - Parameters:
    ///   - text: The full source text.
    ///   - language: An optional language definition. When `nil`, only
    ///     brace-based and `#region` folding are attempted.
    /// - Returns: An array of fold regions.
    public func computeFoldRegions(text: String, language: LanguageDefinition?) -> [FoldRegion] {
        let lines = text.components(separatedBy: "\n")
        var regions: [FoldRegion] = []

        // 1. Brace-based folding { }
        regions.append(contentsOf: braceFoldRegions(lines: lines))

        // 2. Indent-based folding (for Python, YAML, and similar languages).
        if let lang = language, isIndentBasedLanguage(lang) {
            regions.append(contentsOf: indentFoldRegions(lines: lines))
        }

        // 3. #region / #endregion markers.
        regions.append(contentsOf: regionMarkerFoldRegions(lines: lines))

        // 4. Multi-line comment blocks.
        if let lang = language {
            regions.append(contentsOf: commentFoldRegions(lines: lines, language: lang))
        }

        // Sort by start line.
        regions.sort { $0.startLine < $1.startLine }
        return regions
    }

    // MARK: - Brace Folding

    /// Detect fold regions delimited by `{` and `}`.
    ///
    /// Uses a stack to pair opening and closing braces while ignoring
    /// braces inside full-line comments (basic heuristic).
    private func braceFoldRegions(lines: [String]) -> [FoldRegion] {
        var regions: [FoldRegion] = []
        var stack: [Int] = []

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip full-line comments.
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") || trimmed.hasPrefix("--") {
                continue
            }

            for char in line {
                if char == "{" {
                    stack.append(index)
                } else if char == "}" {
                    if let openLine = stack.popLast(), openLine < index {
                        regions.append(FoldRegion(
                            startLine: openLine,
                            endLine: index,
                            kind: .block
                        ))
                    }
                }
            }
        }

        return regions
    }

    // MARK: - Indent-Based Folding

    /// Returns `true` for languages that use significant indentation.
    private func isIndentBasedLanguage(_ language: LanguageDefinition) -> Bool {
        let indentIDs: Set<String> = ["python", "yaml"]
        return indentIDs.contains(language.id)
    }

    /// Detect fold regions based on indentation level changes.
    private func indentFoldRegions(lines: [String]) -> [FoldRegion] {
        var regions: [FoldRegion] = []

        func indentLevel(_ line: String) -> Int {
            var count = 0
            for ch in line {
                if ch == " " { count += 1 }
                else if ch == "\t" { count += CommonKit.defaultTabWidth }
                else { break }
            }
            return count
        }

        func isBlank(_ line: String) -> Bool {
            line.trimmingCharacters(in: .whitespaces).isEmpty
        }

        var i = 0
        while i < lines.count {
            let currentLine = lines[i]
            if isBlank(currentLine) {
                i += 1
                continue
            }

            let currentIndent = indentLevel(currentLine)

            // Find the next non-blank line.
            var nextNonBlank = i + 1
            while nextNonBlank < lines.count && isBlank(lines[nextNonBlank]) {
                nextNonBlank += 1
            }

            if nextNonBlank < lines.count {
                let nextIndent = indentLevel(lines[nextNonBlank])
                if nextIndent > currentIndent {
                    var endLine = nextNonBlank
                    var j = nextNonBlank + 1
                    while j < lines.count {
                        if isBlank(lines[j]) {
                            j += 1
                            continue
                        }
                        if indentLevel(lines[j]) > currentIndent {
                            endLine = j
                            j += 1
                        } else {
                            break
                        }
                    }

                    if endLine > i {
                        regions.append(FoldRegion(
                            startLine: i,
                            endLine: endLine,
                            kind: .block
                        ))
                    }
                }
            }

            i += 1
        }

        return regions
    }

    // MARK: - Region Markers

    /// Detect `#region` / `#endregion` fold markers.
    private func regionMarkerFoldRegions(lines: [String]) -> [FoldRegion] {
        var regions: [FoldRegion] = []
        var stack: [Int] = []

        let startPatterns = ["#region", "// region", "//region", "#pragma region"]
        let endPatterns   = ["#endregion", "// endregion", "//endregion", "#pragma endregion"]

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if startPatterns.contains(where: { trimmed.hasPrefix($0) }) {
                stack.append(index)
            } else if endPatterns.contains(where: { trimmed.hasPrefix($0) }) {
                if let openLine = stack.popLast(), openLine < index {
                    regions.append(FoldRegion(
                        startLine: openLine,
                        endLine: index,
                        kind: .region
                    ))
                }
            }
        }

        return regions
    }

    // MARK: - Multi-line Comment Folding

    /// Detect multi-line comment blocks using the language's block comment
    /// delimiters.
    private func commentFoldRegions(lines: [String], language: LanguageDefinition) -> [FoldRegion] {
        guard let start = language.blockCommentStart,
              let end = language.blockCommentEnd else {
            return []
        }

        var regions: [FoldRegion] = []
        var openLine: Int? = nil

        for (index, line) in lines.enumerated() {
            if openLine == nil && line.contains(start) {
                if line.contains(end),
                   let startRange = line.range(of: start),
                   let endRange = line.range(of: end),
                   endRange.lowerBound > startRange.lowerBound {
                    // Single-line block comment — do not fold.
                    continue
                }
                openLine = index
            } else if let open = openLine, line.contains(end) {
                if index > open {
                    regions.append(FoldRegion(
                        startLine: open,
                        endLine: index,
                        kind: .comment
                    ))
                }
                openLine = nil
            }
        }

        // Also fold consecutive single-line comments (3+ lines).
        regions.append(contentsOf: consecutiveLineCommentRegions(lines: lines, language: language))

        return regions
    }

    /// Fold runs of 3 or more consecutive single-line comments.
    private func consecutiveLineCommentRegions(lines: [String], language: LanguageDefinition) -> [FoldRegion] {
        guard let prefix = language.lineComment else { return [] }

        var regions: [FoldRegion] = []
        var runStart: Int? = nil

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                if runStart == nil {
                    runStart = index
                }
            } else {
                if let start = runStart, index - start >= 3 {
                    regions.append(FoldRegion(
                        startLine: start,
                        endLine: index - 1,
                        kind: .comment
                    ))
                }
                runStart = nil
            }
        }

        // Handle a run that extends to the end of the file.
        if let start = runStart, lines.count - start >= 3 {
            regions.append(FoldRegion(
                startLine: start,
                endLine: lines.count - 1,
                kind: .comment
            ))
        }

        return regions
    }
}
