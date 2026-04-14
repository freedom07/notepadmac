import AppKit
import CommonKit

public struct BracketPair: Sendable {
    public let open: Int
    public let close: Int
    public init(open: Int, close: Int) { self.open = open; self.close = close }
}

public class BracketMatcher {
    public static let pairs: [(Character, Character)] = [("(", ")"), ("[", "]"), ("{", "}"), ("<", ">")]

    /// Find the matching bracket for the bracket at the given position.
    /// Skips brackets inside string literals and comments.
    public static func findMatchingBracket(at position: Int, in text: String) -> Int? {
        let chars = Array(text)
        guard position >= 0 && position < chars.count else { return nil }
        let ch = chars[position]

        for (open, close) in pairs {
            if ch == open {
                return searchForward(from: position, open: open, close: close, in: chars)
            }
            if ch == close {
                return searchBackward(from: position, open: open, close: close, in: chars)
            }
        }
        return nil
    }

    /// Highlight matching brackets at cursor position in the text view.
    /// Clears previous highlights before applying new ones.
    public static func highlightMatchingBrackets(in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager else { return }
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        // Clear previous bracket highlights
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

        let pos = textView.selectedRange().location
        guard pos > 0 else { return }
        if let match = findMatchingBracket(at: pos - 1, in: textView.string) {
            let color = NSColor.systemYellow.withAlphaComponent(0.3)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color,
                                                forCharacterRange: NSRange(location: pos - 1, length: 1))
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color,
                                                forCharacterRange: NSRange(location: match, length: 1))
        }
    }

    /// Jump cursor to the matching bracket.
    public static func jumpToMatchingBracket(in textView: NSTextView) {
        let pos = textView.selectedRange().location
        guard pos > 0 else { return }
        if let match = findMatchingBracket(at: pos - 1, in: textView.string) {
            textView.setSelectedRange(NSRange(location: match + 1, length: 0))
            textView.scrollRangeToVisible(NSRange(location: match, length: 1))
        }
    }

    // MARK: - Private

    /// Check if a position is inside a string literal or comment.
    private static func isInsideStringOrComment(at position: Int, in chars: [Character]) -> Bool {
        var inSingleQuote = false
        var inDoubleQuote = false
        var inLineComment = false
        var inBlockComment = false
        var i = 0

        while i < position && i < chars.count {
            let ch = chars[i]

            if inLineComment {
                if ch == "\n" { inLineComment = false }
                i += 1; continue
            }
            if inBlockComment {
                if ch == "*" && i + 1 < chars.count && chars[i + 1] == "/" {
                    inBlockComment = false; i += 2; continue
                }
                i += 1; continue
            }
            if inDoubleQuote {
                if ch == "\\" { i += 2; continue } // skip escaped character
                if ch == "\"" { inDoubleQuote = false }
                i += 1; continue
            }
            if inSingleQuote {
                if ch == "\\" { i += 2; continue }
                if ch == "'" { inSingleQuote = false }
                i += 1; continue
            }

            // Not in any string/comment context
            if ch == "\"" { inDoubleQuote = true }
            else if ch == "'" { inSingleQuote = true }
            else if ch == "/" && i + 1 < chars.count {
                if chars[i + 1] == "/" { inLineComment = true; i += 2; continue }
                if chars[i + 1] == "*" { inBlockComment = true; i += 2; continue }
            }
            i += 1
        }

        return inSingleQuote || inDoubleQuote || inLineComment || inBlockComment
    }

    private static func searchForward(from pos: Int, open: Character, close: Character, in chars: [Character]) -> Int? {
        var depth = 0
        for i in pos..<chars.count {
            if isInsideStringOrComment(at: i, in: chars) { continue }
            if chars[i] == open { depth += 1 }
            else if chars[i] == close { depth -= 1; if depth == 0 { return i } }
        }
        return nil
    }

    private static func searchBackward(from pos: Int, open: Character, close: Character, in chars: [Character]) -> Int? {
        var depth = 0
        for i in stride(from: pos, through: 0, by: -1) {
            if isInsideStringOrComment(at: i, in: chars) { continue }
            if chars[i] == close { depth += 1 }
            else if chars[i] == open { depth -= 1; if depth == 0 { return i } }
        }
        return nil
    }
}
