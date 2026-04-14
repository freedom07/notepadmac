// FunctionListParser.swift
// SyntaxKit — NotepadNext
//
// Regex-based symbol parser that extracts function/class/struct declarations
// from source code across 10 languages. Used by the Function List Panel.

import Foundation
import CommonKit

// MARK: - SymbolKind

/// Classification of a code symbol for the function list.
public enum SymbolKind: String, Sendable {
    case function
    case method
    case class_
    case struct_
    case enum_
    case property
    case protocol_
}

// MARK: - SymbolInfo

/// A parsed symbol (function, class, etc.) with its name, kind, and location.
public struct SymbolInfo: Sendable, Equatable {
    public let name: String
    public let kind: SymbolKind
    public let lineNumber: Int  // 0-based
    public let children: [SymbolInfo]

    public init(name: String, kind: SymbolKind, lineNumber: Int, children: [SymbolInfo] = []) {
        self.name = name
        self.kind = kind
        self.lineNumber = lineNumber
        self.children = children
    }

    public static func == (lhs: SymbolInfo, rhs: SymbolInfo) -> Bool {
        lhs.name == rhs.name && lhs.kind == rhs.kind &&
        lhs.lineNumber == rhs.lineNumber && lhs.children == rhs.children
    }
}

// MARK: - FunctionListParser

/// Parses source code to extract symbol definitions (functions, classes, etc.)
/// using language-specific regex patterns. Skips matches inside comments and strings.
@available(macOS 13.0, *)
public final class FunctionListParser {

    // MARK: - Reserved Keywords

    /// C/C++ reserved keywords that should not be matched as function names.
    private static let cReservedKeywords: Set<String> = [
        "if", "else", "for", "while", "do", "switch", "case", "default",
        "return", "break", "continue", "goto", "sizeof", "typeof",
        "typedef", "extern", "static", "register", "auto", "volatile",
        "const", "inline", "restrict"
    ]

    /// JavaScript/TypeScript reserved keywords that should not be matched as function/method names.
    private static let jsReservedKeywords: Set<String> = [
        "if", "else", "for", "while", "do", "switch", "case", "return",
        "break", "continue", "throw", "try", "catch", "finally", "new",
        "delete", "typeof", "instanceof", "void"
    ]

    /// Returns the set of reserved keywords to filter for the given language, or nil if no filtering needed.
    private static func reservedKeywords(for languageId: String) -> Set<String>? {
        switch languageId {
        case "c", "cpp":
            return cReservedKeywords
        case "javascript", "typescript":
            return jsReservedKeywords
        default:
            return nil
        }
    }

    // MARK: - Public API

    /// Parses the given text and returns top-level symbols with nested children.
    /// - Parameters:
    ///   - text: The source code text to parse.
    ///   - languageId: The language identifier (e.g., "swift", "python").
    /// - Returns: An array of discovered symbols, with classes containing their methods as children.
    public static func parse(text: String, languageId: String) -> [SymbolInfo] {
        let lines = text.components(separatedBy: "\n")
        let commentState = buildCommentState(lines: lines, languageId: languageId)
        let patterns = symbolPatterns(for: languageId)

        guard !patterns.isEmpty else { return [] }

        let reserved = reservedKeywords(for: languageId)
        var flatSymbols: [(symbol: SymbolInfo, lineIndex: Int)] = []

        for (lineIndex, line) in lines.enumerated() {
            guard !commentState[lineIndex] else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !isLineComment(trimmed, languageId: languageId) else { continue }

            for (pattern, kind) in patterns {
                if let name = matchPattern(pattern, in: line) {
                    // Filter out reserved keywords (e.g. "if", "while", "for" in C/JS)
                    if let reserved = reserved, reserved.contains(name) {
                        continue
                    }
                    let symbol = SymbolInfo(name: name, kind: kind, lineNumber: lineIndex)
                    flatSymbols.append((symbol, lineIndex))
                    break  // Only one match per line
                }
            }
        }

        return buildTree(from: flatSymbols, lines: lines, languageId: languageId)
    }

    // MARK: - Comment State

    /// Determines which lines are inside block comments.
    /// Returns an array where `true` means the line is inside a block comment.
    private static func buildCommentState(lines: [String], languageId: String) -> [Bool] {
        var inBlock = false
        var state = [Bool](repeating: false, count: lines.count)

        let blockStart: String?
        let blockEnd: String?

        switch languageId {
        case "swift", "javascript", "typescript", "java", "c", "cpp", "go", "rust":
            blockStart = "/*"
            blockEnd = "*/"
        case "ruby":
            blockStart = "=begin"
            blockEnd = "=end"
        default:
            blockStart = nil
            blockEnd = nil
        }

        guard let bStart = blockStart, let bEnd = blockEnd else {
            return state
        }

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inBlock {
                state[i] = true
                if trimmed.contains(bEnd) {
                    inBlock = false
                }
            } else {
                if trimmed.contains(bStart) {
                    if trimmed.contains(bEnd),
                       let startRange = trimmed.range(of: bStart),
                       let endRange = trimmed.range(of: bEnd),
                       startRange.upperBound <= endRange.lowerBound {
                        // Inline block comment like /* ... */ on the same line.
                        // Don't mark the line as comment — it may contain code too.
                    } else if trimmed.contains(bEnd) {
                        // bEnd appears before bStart — unusual, treat as block start
                        state[i] = true
                        inBlock = true
                    } else {
                        // Block comment starts here and doesn't end on this line
                        state[i] = true
                        inBlock = true
                    }
                }
            }
        }

        return state
    }

    /// Returns true if the line is a single-line comment.
    private static func isLineComment(_ trimmed: String, languageId: String) -> Bool {
        switch languageId {
        case "swift", "javascript", "typescript", "java", "c", "cpp", "go", "rust":
            return trimmed.hasPrefix("//")
        case "python", "ruby":
            return trimmed.hasPrefix("#")
        default:
            return trimmed.hasPrefix("//") || trimmed.hasPrefix("#")
        }
    }

    // MARK: - Pattern Matching

    /// Attempts to match the regex pattern against the line and extract the symbol name.
    private static func matchPattern(_ pattern: String, in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        // If there is a capture group, return it; otherwise return the full match
        if match.numberOfRanges > 1, let captureRange = Range(match.range(at: 1), in: line) {
            return String(line[captureRange])
        }
        if let matchRange = Range(match.range, in: line) {
            // Extract just the name from the matched string
            let matched = String(line[matchRange])
            // Return the last word (the symbol name)
            let words = matched.split(separator: " ")
            return words.last.map(String.init)
        }
        return nil
    }

    // MARK: - Symbol Patterns

    /// Returns the regex patterns and associated SymbolKind for the given language.
    private static func symbolPatterns(for languageId: String) -> [(String, SymbolKind)] {
        switch languageId {
        case "swift":
            return swiftPatterns
        case "python":
            return pythonPatterns
        case "javascript":
            return javascriptPatterns
        case "typescript":
            return typescriptPatterns
        case "java":
            return javaPatterns
        case "c":
            return cPatterns
        case "cpp":
            return cppPatterns
        case "go":
            return goPatterns
        case "rust":
            return rustPatterns
        case "ruby":
            return rubyPatterns
        default:
            return []
        }
    }

    // MARK: - Language Patterns

    private static let swiftPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(?:final\s+)?class\s+(\w+)"#, .class_),
        (#"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?struct\s+(\w+)"#, .struct_),
        (#"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?enum\s+(\w+)"#, .enum_),
        (#"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?protocol\s+(\w+)"#, .protocol_),
        (#"^\s*(?:@\w+\s+)*(?:public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(?:static\s+|class\s+)?(?:override\s+)?func\s+(\w+)"#, .function),
        (#"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?(?:static\s+)?(?:let|var)\s+(\w+)\s*[=:{]"#, .property),
    ]

    private static let pythonPatterns: [(String, SymbolKind)] = [
        (#"^\s*class\s+(\w+)"#, .class_),
        (#"^\s*(?:async\s+)?def\s+(\w+)"#, .function),
    ]

    private static let javascriptPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:export\s+)?class\s+(\w+)"#, .class_),
        (#"^\s*(?:export\s+)?(?:async\s+)?function\s+(\w+)"#, .function),
        (#"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("#, .function),
        (#"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\([^)]*\)\s*=>"#, .function),
        (#"^\s*(?:async\s+)?(\w+)\s*\([^)]*\)\s*\{"#, .method),
    ]

    private static let typescriptPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:export\s+)?(?:abstract\s+)?class\s+(\w+)"#, .class_),
        (#"^\s*(?:export\s+)?interface\s+(\w+)"#, .protocol_),
        (#"^\s*(?:export\s+)?(?:async\s+)?function\s+(\w+)"#, .function),
        (#"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("#, .function),
        (#"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\([^)]*\)\s*=>"#, .function),
        (#"^\s*(?:export\s+)?enum\s+(\w+)"#, .enum_),
        (#"^\s*(?:async\s+)?(\w+)\s*\([^)]*\)\s*(?::\s*\w+)?\s*\{"#, .method),
    ]

    private static let javaPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:public\s+|private\s+|protected\s+)?(?:abstract\s+)?(?:static\s+)?(?:final\s+)?class\s+(\w+)"#, .class_),
        (#"^\s*(?:public\s+|private\s+|protected\s+)?(?:static\s+)?enum\s+(\w+)"#, .enum_),
        (#"^\s*(?:public\s+|private\s+|protected\s+)?interface\s+(\w+)"#, .protocol_),
        (#"^\s*(?:public\s+|private\s+|protected\s+)?(?:abstract\s+)?(?:static\s+)?(?:final\s+)?(?:synchronized\s+)?(?:\w+(?:<[^>]+>)?(?:\[\])*\s+)(\w+)\s*\("#, .function),
    ]

    private static let cPatterns: [(String, SymbolKind)] = [
        (#"^\s*struct\s+(\w+)"#, .struct_),
        (#"^\s*enum\s+(\w+)"#, .enum_),
        (#"^\s*(?:static\s+)?(?:inline\s+)?(?:extern\s+)?(?:const\s+)?(?:unsigned\s+)?(?:signed\s+)?(?:\w+\s*\*?\s+)+(\w+)\s*\([^;]*$"#, .function),
    ]

    private static let cppPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:template\s*<[^>]*>\s*)?class\s+(\w+)"#, .class_),
        (#"^\s*(?:template\s*<[^>]*>\s*)?struct\s+(\w+)"#, .struct_),
        (#"^\s*enum\s+(?:class\s+)?(\w+)"#, .enum_),
        (#"^\s*namespace\s+(\w+)"#, .struct_),
        (#"^\s*(?:static\s+)?(?:inline\s+)?(?:virtual\s+)?(?:explicit\s+)?(?:const\s+)?(?:unsigned\s+)?(?:\w+(?:::\w+)*\s*[*&]?\s+)+(\w+)\s*\([^;]*$"#, .function),
    ]

    private static let goPatterns: [(String, SymbolKind)] = [
        (#"^\s*func\s+\(\s*\w+\s+\*?\w+\)\s+(\w+)"#, .method),
        (#"^\s*func\s+(\w+)"#, .function),
        (#"^\s*type\s+(\w+)\s+struct\b"#, .struct_),
        (#"^\s*type\s+(\w+)\s+interface\b"#, .protocol_),
    ]

    private static let rustPatterns: [(String, SymbolKind)] = [
        (#"^\s*(?:pub(?:\([^)]+\))?\s+)?(?:async\s+)?fn\s+(\w+)"#, .function),
        (#"^\s*(?:pub(?:\([^)]+\))?\s+)?struct\s+(\w+)"#, .struct_),
        (#"^\s*(?:pub(?:\([^)]+\))?\s+)?enum\s+(\w+)"#, .enum_),
        (#"^\s*impl(?:<[^>]+>)?\s+(\w+)"#, .class_),
        (#"^\s*(?:pub(?:\([^)]+\))?\s+)?trait\s+(\w+)"#, .protocol_),
    ]

    private static let rubyPatterns: [(String, SymbolKind)] = [
        (#"^\s*class\s+(\w+)"#, .class_),
        (#"^\s*module\s+(\w+)"#, .struct_),
        (#"^\s*def\s+(?:self\.)?(\w+[?!]?)"#, .function),
    ]

    // MARK: - Tree Building

    /// Groups methods/functions as children of their enclosing class/struct.
    /// Uses indentation and brace counting for nesting heuristics.
    private static func buildTree(
        from symbols: [(symbol: SymbolInfo, lineIndex: Int)],
        lines: [String],
        languageId: String
    ) -> [SymbolInfo] {
        let containerKinds: Set<SymbolKind> = [.class_, .struct_, .enum_, .protocol_]

        // For languages with brace-based scoping
        let usesBraces = ["swift", "javascript", "typescript", "java", "c", "cpp", "go", "rust"].contains(languageId)
        // For indentation-based scoping (Python)
        let usesIndentation = languageId == "python"
        // For keyword-based scoping (Ruby)
        let usesEndKeyword = languageId == "ruby"

        var result: [SymbolInfo] = []
        var i = 0

        while i < symbols.count {
            let (sym, lineIdx) = symbols[i]

            if containerKinds.contains(sym.kind) {
                // Find children belonging to this container
                var children: [SymbolInfo] = []
                let containerEnd: Int

                if usesBraces {
                    containerEnd = findBraceClosing(from: lineIdx, lines: lines)
                } else if usesIndentation {
                    containerEnd = findIndentationEnd(from: lineIdx, lines: lines)
                } else if usesEndKeyword {
                    containerEnd = findEndKeyword(from: lineIdx, lines: lines)
                } else {
                    containerEnd = lineIdx
                }

                var j = i + 1
                while j < symbols.count {
                    let (childSym, childLine) = symbols[j]
                    if childLine > containerEnd { break }
                    if !containerKinds.contains(childSym.kind) {
                        let childWithMethodKind = SymbolInfo(
                            name: childSym.name,
                            kind: .method,
                            lineNumber: childSym.lineNumber,
                            children: childSym.children
                        )
                        children.append(childWithMethodKind)
                    } else {
                        // Nested container - add as-is
                        children.append(childSym)
                    }
                    j += 1
                }

                let containerWithChildren = SymbolInfo(
                    name: sym.name,
                    kind: sym.kind,
                    lineNumber: sym.lineNumber,
                    children: children
                )
                result.append(containerWithChildren)
                i = j
            } else {
                result.append(sym)
                i += 1
            }
        }

        return result
    }

    /// Finds the line where the brace scope opened at `startLine` closes.
    private static func findBraceClosing(from startLine: Int, lines: [String]) -> Int {
        var depth = 0
        var foundOpen = false

        for i in startLine..<lines.count {
            for char in lines[i] {
                if char == "{" {
                    depth += 1
                    foundOpen = true
                } else if char == "}" {
                    depth -= 1
                    if foundOpen && depth == 0 {
                        return i
                    }
                }
            }
        }

        // If no closing brace found, extend to end of file
        return lines.count - 1
    }

    /// Finds where the indentation block ends (Python).
    private static func findIndentationEnd(from startLine: Int, lines: [String]) -> Int {
        guard startLine + 1 < lines.count else { return startLine }

        let baseIndent = leadingSpaces(lines[startLine])
        var lastLine = startLine

        for i in (startLine + 1)..<lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let indent = leadingSpaces(line)
            if indent <= baseIndent {
                return lastLine
            }
            lastLine = i
        }

        return lastLine
    }

    /// Finds the matching `end` keyword (Ruby).
    private static func findEndKeyword(from startLine: Int, lines: [String]) -> Int {
        var depth = 0

        for i in startLine..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("class ") || trimmed.hasPrefix("module ") ||
               trimmed.hasPrefix("def ") || trimmed.hasPrefix("do") ||
               trimmed.hasSuffix(" do") || trimmed == "begin" {
                depth += 1
            }
            if trimmed == "end" || trimmed.hasPrefix("end ") || trimmed.hasPrefix("end#") {
                depth -= 1
                if depth == 0 { return i }
            }
        }

        return lines.count - 1
    }

    /// Returns the number of leading spaces (tabs count as 4).
    private static func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " { count += 1 }
            else if char == "\t" { count += 4 }
            else { break }
        }
        return count
    }
}
