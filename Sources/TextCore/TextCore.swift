import Foundation
import CommonKit

/// Represents a text document with line-based storage and metadata.
///
/// This is a lightweight convenience type. For full editing support
/// (undo/redo, piece-table storage) use ``TextBuffer`` instead.
public final class TextDocument {
    public var content: String
    public var encoding: String.Encoding
    public var lineEnding: LineEnding
    public private(set) var lines: [String]

    public init(content: String = "", encoding: String.Encoding = .utf8, lineEnding: LineEnding = .lf) {
        self.content = content
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.lines = content.components(separatedBy: lineEnding.rawValue)
    }

    public func lineAndColumn(for characterIndex: Int) -> (line: Int, column: Int) {
        var currentIndex = 0
        for (lineNumber, line) in lines.enumerated() {
            let lineLength = line.count + lineEnding.rawValue.count
            if currentIndex + lineLength > characterIndex {
                return (lineNumber + 1, characterIndex - currentIndex + 1)
            }
            currentIndex += lineLength
        }
        return (lines.count, (lines.last?.count ?? 0) + 1)
    }

    public var lineCount: Int {
        return lines.count
    }

    public func updateContent(_ newContent: String) {
        self.content = newContent
        self.lines = newContent.components(separatedBy: lineEnding.rawValue)
    }
}
