import AppKit
import CommonKit

public class AutoClosePairs {
    public static let pairs: [(open: String, close: String)] = [("(", ")"), ("[", "]"), ("{", "}"), ("\"", "\""), ("'", "'"), ("`", "`")]

    /// Handle a key press. Returns true if the key was handled (pair inserted/skipped).
    public static func handleKeyPress(character: String, in textView: NSTextView) -> Bool {
        let sr = textView.selectedRange()
        let text = textView.string as NSString

        // Skip over closing character if it already exists at cursor
        for p in pairs where character == p.close && sr.length == 0 && sr.location < text.length {
            if text.substring(with: NSRange(location: sr.location, length: 1)) == p.close {
                textView.setSelectedRange(NSRange(location: sr.location + 1, length: 0))
                return true
            }
        }

        // Auto-insert closing character
        for p in pairs where character == p.open {
            // Wrap selection with pair
            if sr.length > 0 {
                let sel = text.substring(with: sr)
                textView.insertText(p.open + sel + p.close, replacementRange: sr)
                return true
            }
            // Self-closing pairs (quotes): auto-close if next char is whitespace, punctuation, or end of doc
            if p.open == p.close {
                let atEnd = sr.location >= text.length
                let nextIsSpace = !atEnd && {
                    let ch = text.character(at: sr.location)
                    guard let scalar = Unicode.Scalar(ch) else { return false }
                    return CharacterSet.whitespacesAndNewlines.contains(scalar) ||
                           CharacterSet.punctuationCharacters.contains(scalar)
                }()
                if atEnd || nextIsSpace {
                    textView.insertText(p.open + p.close, replacementRange: sr)
                    textView.setSelectedRange(NSRange(location: sr.location + 1, length: 0))
                    return true
                }
                return false
            }
            // Regular pairs: always auto-close
            textView.insertText(p.open + p.close, replacementRange: sr)
            textView.setSelectedRange(NSRange(location: sr.location + 1, length: 0))
            return true
        }
        return false
    }

    /// Handle backspace inside an empty pair — deletes both characters.
    /// Call this when the user presses backspace. Returns true if handled.
    public static func handleBackspace(in textView: NSTextView) -> Bool {
        let sr = textView.selectedRange()
        let text = textView.string as NSString
        guard sr.length == 0, sr.location > 0, sr.location < text.length else { return false }

        let before = text.substring(with: NSRange(location: sr.location - 1, length: 1))
        let after = text.substring(with: NSRange(location: sr.location, length: 1))

        for p in pairs where before == p.open && after == p.close {
            // Delete both the open and close characters
            textView.insertText("", replacementRange: NSRange(location: sr.location - 1, length: 2))
            return true
        }
        return false
    }
}
