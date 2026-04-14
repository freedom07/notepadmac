import AppKit
import CommonKit

public class CommentToggle {
    public static func toggleLineComment(in textView: NSTextView, commentPrefix: String) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let rawText = text.substring(with: lineRange)
        let hasTrailingNewline = rawText.hasSuffix("\n")
        let strippedText = hasTrailingNewline ? String(rawText.dropLast()) : rawText
        let lines = strippedText.components(separatedBy: "\n")
        let prefix = commentPrefix + " "
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allCommented = nonEmpty.allSatisfy { isLineCommented($0, prefix: commentPrefix) }
        var result: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { result.append(line) }
            else if allCommented {
                var l = line; if let r = l.range(of: prefix) { l.removeSubrange(r) }
                else if let r = l.range(of: commentPrefix) { l.removeSubrange(r) }
                result.append(l)
            } else {
                let indent = line.prefix(while: { $0 == " " || $0 == "\t" })
                result.append(String(indent) + prefix + String(line.dropFirst(indent.count)))
            }
        }
        var output = result.joined(separator: "\n")
        if hasTrailingNewline { output += "\n" }
        textView.insertText(output, replacementRange: lineRange)
    }
    public static func toggleBlockComment(in textView: NSTextView, start: String, end: String) {
        let range = textView.selectedRange(); guard range.length > 0 else { return }
        let text = (textView.string as NSString).substring(with: range)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(start) && trimmed.hasSuffix(end) {
            let content = String(trimmed.dropFirst(start.count).dropLast(end.count))
            textView.insertText(content, replacementRange: range)
        } else { textView.insertText(start + " " + text + " " + end, replacementRange: range) }
    }
    public static func isLineCommented(_ line: String, prefix: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
    }
}
