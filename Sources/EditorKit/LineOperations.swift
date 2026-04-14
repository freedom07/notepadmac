import AppKit
import CommonKit

public class LineOperations {
    public static func duplicateLine(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let lineText = text.substring(with: lineRange)
        textView.insertText(lineText, replacementRange: NSRange(location: lineRange.upperBound, length: 0))
    }
    public static func deleteLine(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        textView.insertText("", replacementRange: lineRange)
    }
    public static func moveLineUp(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        guard lineRange.location > 0 else { return }
        let prevLineRange = text.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        let currentLine = text.substring(with: lineRange)
        let prevLine = text.substring(with: prevLineRange)
        let combined = NSRange(location: prevLineRange.location, length: prevLineRange.length + lineRange.length)
        textView.insertText(currentLine + prevLine, replacementRange: combined)
    }
    public static func moveLineDown(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let end = lineRange.location + lineRange.length
        guard end < text.length else { return }
        let nextLineRange = text.lineRange(for: NSRange(location: end, length: 0))
        let currentLine = text.substring(with: lineRange)
        let nextLine = text.substring(with: nextLineRange)
        let combined = NSRange(location: lineRange.location, length: lineRange.length + nextLineRange.length)
        textView.insertText(nextLine + currentLine, replacementRange: combined)
    }
    public static func sortLinesAscending(in textView: NSTextView) { sortLines(in: textView, ascending: true) }
    public static func sortLinesDescending(in textView: NSTextView) { sortLines(in: textView, ascending: false) }
    private static func sortLines(in textView: NSTextView, ascending: Bool) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        var lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.sort { ascending ? $0 < $1 : $0 > $1 }
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }
    public static func removeDuplicateLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        var seen = Set<String>(); var unique: [String] = []
        for line in text.substring(with: lineRange).components(separatedBy: "\n") {
            if !line.isEmpty && !seen.contains(line) { seen.insert(line); unique.append(line) }
        }
        textView.insertText(unique.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }
    public static func removeEmptyLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let lines = text.substring(with: lineRange).components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }
    public static func reverseLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        var lines = text.substring(with: lineRange).components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.reverse()
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }
    public static func joinLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let joined = text.substring(with: lineRange).components(separatedBy: "\n").filter { !$0.isEmpty }.joined(separator: " ")
        textView.insertText(joined, replacementRange: lineRange)
    }

    // MARK: - Whitespace Operations

    public static func trimTrailingWhitespace(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        let lines = selected.components(separatedBy: "\n")
        let trimmed = lines.map { line -> String in
            var s = line
            while s.hasSuffix(" ") || s.hasSuffix("\t") {
                s.removeLast()
            }
            return s
        }
        textView.insertText(trimmed.joined(separator: "\n"), replacementRange: lineRange)
    }

    public static func trimLeadingWhitespace(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        let lines = selected.components(separatedBy: "\n")
        let trimmed = lines.map { line -> String in
            var s = line
            while s.hasPrefix(" ") || s.hasPrefix("\t") {
                s.removeFirst()
            }
            return s
        }
        textView.insertText(trimmed.joined(separator: "\n"), replacementRange: lineRange)
    }

    public static func insertBlankLineAbove(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        textView.insertText("\n", replacementRange: NSRange(location: lineRange.location, length: 0))
    }

    public static func insertBlankLineBelow(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let end = lineRange.location + lineRange.length
        textView.insertText("\n", replacementRange: NSRange(location: end, length: 0))
    }

    // MARK: - Tab/Space Conversion

    public static func tabsToSpaces(in textView: NSTextView, tabWidth: Int = 4) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        let replacement = selected.replacingOccurrences(of: "\t", with: String(repeating: " ", count: tabWidth))
        textView.insertText(replacement, replacementRange: lineRange)
    }

    public static func spacesToTabs(in textView: NSTextView, tabWidth: Int = 4) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        let lines = selected.components(separatedBy: "\n")
        let converted = lines.map { line -> String in
            let spaceGroup = String(repeating: " ", count: tabWidth)
            var result = line
            // Replace only leading space groups with tabs
            var prefix = ""
            var rest = result[result.startIndex...]
            while rest.hasPrefix(spaceGroup) {
                prefix += "\t"
                rest = rest.dropFirst(tabWidth)
            }
            result = prefix + String(rest)
            return result
        }
        textView.insertText(converted.joined(separator: "\n"), replacementRange: lineRange)
    }

    // MARK: - Sort Variants

    public static func sortLinesCaseInsensitive(in textView: NSTextView, ascending: Bool = true) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        var lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.sort { a, b in
            let result = a.localizedCaseInsensitiveCompare(b)
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    public static func sortLinesByLength(in textView: NSTextView, ascending: Bool = true) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        var lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.sort { a, b in
            ascending ? a.count < b.count : a.count > b.count
        }
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    public static func sortLinesAsIntegers(in textView: NSTextView, ascending: Bool = true) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        var lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.sort { a, b in
            let aInt = Int(a.trimmingCharacters(in: .whitespaces))
            let bInt = Int(b.trimmingCharacters(in: .whitespaces))
            switch (aInt, bInt) {
            case let (aVal?, bVal?):
                return ascending ? aVal < bVal : aVal > bVal
            case (nil, _?):
                return false  // non-numeric goes to end
            case (_?, nil):
                return true   // numeric before non-numeric
            default:
                return a < b  // both non-numeric: alphabetical
            }
        }
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    public static func shuffleLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        var lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        lines.shuffle()
        textView.insertText(lines.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    public static func removeEmptyLinesPreservingBlank(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let lines = text.substring(with: lineRange).components(separatedBy: "\n")
        let filtered = lines.filter { !$0.isEmpty } // keep lines with any content including whitespace
        textView.insertText(filtered.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    public static func removeConsecutiveDuplicateLines(in textView: NSTextView) {
        let text = textView.string as NSString
        let lineRange = text.lineRange(for: textView.selectedRange())
        let selected = text.substring(with: lineRange)
        let lines = selected.components(separatedBy: "\n").filter { !$0.isEmpty }
        var result: [String] = []
        for line in lines {
            if result.last != line {
                result.append(line)
            }
        }
        textView.insertText(result.joined(separator: "\n") + "\n", replacementRange: lineRange)
    }

    // MARK: - Copy Operations

    public static func copyFilePath(from url: URL?) {
        guard let url = url else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.path, forType: .string)
    }

    public static func copyFileName(from url: URL?) {
        guard let url = url else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.lastPathComponent, forType: .string)
    }

    public static func copyFileDirectory(from url: URL?) {
        guard let url = url else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(url.deletingLastPathComponent().path, forType: .string)
    }

    // MARK: - Date/Time Insertion

    public static func insertDateTime(in textView: NSTextView, format: String = "yyyy-MM-dd HH:mm:ss") {
        let dateString = formatDate(Date(), format: format)
        textView.insertText(dateString, replacementRange: textView.selectedRange())
    }

    /// Cached formatters keyed by format string to avoid repeated allocation.
    private static let dateFormatterLock = NSLock()
    private static var dateFormatters: [String: DateFormatter] = [:]

    /// Format a date with the given format string. Exposed for testing.
    public static func formatDate(_ date: Date, format: String) -> String {
        dateFormatterLock.lock()
        defer { dateFormatterLock.unlock() }
        if let formatter = dateFormatters[format] {
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        dateFormatters[format] = formatter
        return formatter.string(from: date)
    }

    /// Short date format: "MM/dd/yyyy"
    public static func insertDateTimeShort(in textView: NSTextView) {
        insertDateTime(in: textView, format: "MM/dd/yyyy")
    }

    /// Long date format: "MMMM d, yyyy h:mm a"
    public static func insertDateTimeLong(in textView: NSTextView) {
        insertDateTime(in: textView, format: "MMMM d, yyyy h:mm a")
    }

    /// ISO 8601 format: "yyyy-MM-dd'T'HH:mm:ssZ"
    public static func insertDateTimeISO(in textView: NSTextView) {
        insertDateTime(in: textView, format: "yyyy-MM-dd'T'HH:mm:ssZ")
    }

    // MARK: - Column Editor Operations

    /// Insert the same text at a given column position across a range of lines.
    /// The column is determined by the cursor position within its starting line.
    /// Lines shorter than the column are padded with spaces.
    public static func insertColumnText(in textView: NSTextView, text: String) {
        let selectedRange = textView.selectedRange()
        let nsString = textView.string as NSString
        guard nsString.length > 0 else { return }

        let startLineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let column = selectedRange.location - startLineRange.location

        let endLocation = max(selectedRange.location, NSMaxRange(selectedRange) - (selectedRange.length > 0 ? 1 : 0))
        let endLineRange = nsString.lineRange(for: NSRange(location: min(endLocation, nsString.length - 1), length: 0))

        let result = buildColumnInsertedText(
            nsString: nsString,
            startLineLocation: startLineRange.location,
            endLineLocation: endLineRange.location,
            column: column,
            generator: { _ in text }
        )

        let combinedRange = NSRange(
            location: startLineRange.location,
            length: NSMaxRange(endLineRange) - startLineRange.location
        )
        textView.insertText(result, replacementRange: combinedRange)
    }

    /// Insert sequential numbers at the cursor column across lines.
    /// Lines shorter than the column are padded with spaces.
    public static func insertColumnNumbers(
        in textView: NSTextView,
        start: Int, step: Int, radix: Int,
        leadingZeros: Bool, uppercase: Bool
    ) {
        let selectedRange = textView.selectedRange()
        let nsString = textView.string as NSString
        guard nsString.length > 0 else { return }

        let startLineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let column = selectedRange.location - startLineRange.location

        let endLocation = max(selectedRange.location, NSMaxRange(selectedRange) - (selectedRange.length > 0 ? 1 : 0))
        let endLineRange = nsString.lineRange(for: NSRange(location: min(endLocation, nsString.length - 1), length: 0))

        // Pre-calculate the max width for leading zeros padding
        var lineCount = 0
        var scanLocation = startLineRange.location
        while scanLocation <= endLineRange.location && scanLocation < nsString.length {
            lineCount += 1
            let lr = nsString.lineRange(for: NSRange(location: scanLocation, length: 0))
            let nextStart = NSMaxRange(lr)
            if nextStart <= scanLocation { break }
            scanLocation = nextStart
        }

        let lastValue = start + (lineCount - 1) * step
        let maxWidth = formatNumber(max(abs(start), abs(lastValue)), radix: radix, uppercase: uppercase).count

        var lineIndex = 0
        let result = buildColumnInsertedText(
            nsString: nsString,
            startLineLocation: startLineRange.location,
            endLineLocation: endLineRange.location,
            column: column,
            generator: { _ in
                let value = start + lineIndex * step
                lineIndex += 1
                var numStr = formatNumber(abs(value), radix: radix, uppercase: uppercase)
                if leadingZeros {
                    while numStr.count < maxWidth {
                        numStr = "0" + numStr
                    }
                }
                if value < 0 {
                    numStr = "-" + numStr
                }
                return numStr
            }
        )

        let combinedRange = NSRange(
            location: startLineRange.location,
            length: NSMaxRange(endLineRange) - startLineRange.location
        )
        textView.insertText(result, replacementRange: combinedRange)
    }

    /// Format a number in the given radix.
    public static func formatNumber(_ value: Int, radix: Int, uppercase: Bool) -> String {
        let str = String(value, radix: radix)
        return uppercase ? str.uppercased() : str
    }

    /// Build the resulting text after inserting generated strings at a column position
    /// across lines from startLineLocation to endLineLocation (inclusive).
    /// Lines shorter than column are padded with spaces.
    private static func buildColumnInsertedText(
        nsString: NSString,
        startLineLocation: Int,
        endLineLocation: Int,
        column: Int,
        generator: (Int) -> String
    ) -> String {
        var resultLines: [String] = []
        var currentLocation = startLineLocation
        var lineIndex = 0

        while currentLocation <= endLineLocation && currentLocation < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: currentLocation, length: 0))
            let lineText = nsString.substring(with: lineRange)

            // Strip trailing newline for manipulation
            let hasNewline = lineText.hasSuffix("\n")
            let lineContent = hasNewline ? String(lineText.dropLast()) : lineText

            let insertText = generator(lineIndex)

            let modifiedLine: String
            if lineContent.count < column {
                // Pad with spaces up to the column, then insert
                let padding = String(repeating: " ", count: column - lineContent.count)
                modifiedLine = lineContent + padding + insertText
            } else {
                // Insert at the column position
                var chars = Array(lineContent)
                let insertionPoint = min(column, chars.count)
                chars.insert(contentsOf: insertText, at: insertionPoint)
                modifiedLine = String(chars)
            }

            resultLines.append(modifiedLine + (hasNewline ? "\n" : ""))
            lineIndex += 1

            let nextStart = NSMaxRange(lineRange)
            if nextStart <= currentLocation { break }
            currentLocation = nextStart
        }

        return resultLines.joined()
    }
}
