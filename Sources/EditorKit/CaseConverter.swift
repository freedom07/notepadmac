import AppKit
import CommonKit

public class CaseConverter {
    public static func toUpperCase(in textView: NSTextView) { transform(in: textView) { $0.uppercased() } }
    public static func toLowerCase(in textView: NSTextView) { transform(in: textView) { $0.lowercased() } }
    public static func toTitleCase(in textView: NSTextView) { transform(in: textView) { $0.capitalized } }
    public static func toCamelCase(in textView: NSTextView) {
        transform(in: textView) { text in
            let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            guard let first = words.first else { return text }
            return first.lowercased() + words.dropFirst().map { $0.capitalized }.joined()
        }
    }
    public static func toSnakeCase(in textView: NSTextView) {
        transform(in: textView) { text in
            var r = ""; for (i, c) in text.enumerated() { if c.isUppercase && i > 0 { r += "_" }; r += String(c).lowercased() }
            return r.replacingOccurrences(of: " ", with: "_")
        }
    }
    public static func toggleCase(in textView: NSTextView) {
        transform(in: textView) { String($0.map { $0.isUppercase ? Character($0.lowercased()) : Character($0.uppercased()) }) }
    }
    public static func toSentenceCase(in textView: NSTextView) {
        transform(in: textView) { text in
            sentenceCaseTransform(text)
        }
    }
    public static func toRandomCase(in textView: NSTextView) {
        transform(in: textView) { text in
            String(text.map { c in Bool.random() ? Character(c.uppercased()) : Character(c.lowercased()) })
        }
    }

    /// Pure-function sentence-case conversion (testable without NSTextView).
    public static func sentenceCaseTransform(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = ""
        var capitalizeNext = true
        for c in text {
            if capitalizeNext && c.isLetter {
                result.append(Character(c.uppercased()))
                capitalizeNext = false
            } else {
                result.append(Character(c.lowercased()))
            }
            if c == "." || c == "!" || c == "?" {
                capitalizeNext = true
            }
        }
        return result
    }

    /// Pure-function random-case conversion with a provided random generator.
    public static func randomCaseTransform(_ text: String, using rng: inout some RandomNumberGenerator) -> String {
        String(text.map { c in Bool.random(using: &rng) ? Character(c.uppercased()) : Character(c.lowercased()) })
    }
    private static func transform(in textView: NSTextView, _ fn: (String) -> String) {
        var range = textView.selectedRange()
        // If no selection, select the current word
        if range.length == 0 {
            let text = textView.string as NSString
            let cursor = range.location
            var bestRange = NSRange(location: NSNotFound, length: 0)
            let searchStart = max(0, cursor - 50)
            let searchLen = min(100, text.length - searchStart)
            let searchRange = NSRange(location: searchStart, length: searchLen)
            if let regex = try? NSRegularExpression(pattern: "\\w+") {
                for match in regex.matches(in: textView.string, range: searchRange) {
                    if match.range.location <= cursor && match.range.location + match.range.length >= cursor {
                        bestRange = match.range; break
                    }
                }
            }
            guard bestRange.location != NSNotFound else { return }
            range = bestRange
        }
        textView.insertText(fn((textView.string as NSString).substring(with: range)), replacementRange: range)
    }
}
