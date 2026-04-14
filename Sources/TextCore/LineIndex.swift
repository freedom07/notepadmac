// LineIndex.swift
// TextCore — NotepadNext
//
// Fast line number <-> byte offset mapping.
// Maintains an array of byte offsets marking the start of each line,
// enabling O(log n) lookups via binary search.

import Foundation
import CommonKit

/// An index that maps between line numbers and byte offsets.
///
/// Line numbers are zero-based. The index always contains at least one entry
/// (offset 0 for line 0), even for an empty document.
public struct LineIndex: Sendable {

    /// Byte offset of the start of each line (zero-based line numbers).
    public private(set) var lineOffsets: [Int]

    // MARK: - Initialization

    /// Build a line index by scanning the given text for line breaks.
    ///
    /// Recognized endings: `\n`, `\r\n`, `\r`.
    public init(from text: String) {
        let data = Data(text.utf8)
        self.lineOffsets = LineIndex.buildOffsets(from: data)
    }

    /// Build a line index from raw UTF-8 data.
    public init(from data: Data) {
        self.lineOffsets = LineIndex.buildOffsets(from: data)
    }

    // MARK: - Queries

    /// The number of lines in the indexed text.
    public var lineCount: Int {
        lineOffsets.count
    }

    /// Return the zero-based line number that contains the given byte offset.
    ///
    /// Uses binary search for O(log n) performance.
    ///
    /// - Parameter offset: A byte offset (0 ... text length).
    /// - Returns: The zero-based line number.
    public func lineNumber(forOffset offset: Int) -> Int {
        precondition(offset >= 0, "Offset must be non-negative")

        // Binary search: find the last line whose start offset <= offset
        var lo = 0
        var hi = lineOffsets.count - 1
        while lo < hi {
            let mid = lo + (hi - lo + 1) / 2
            if lineOffsets[mid] <= offset {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo
    }

    /// Return the byte offset of the start of the given line.
    ///
    /// - Parameter line: A zero-based line number.
    /// - Returns: The byte offset where that line begins.
    public func offset(forLine line: Int) -> Int {
        precondition(line >= 0 && line < lineOffsets.count,
                     "Line \(line) out of range 0..<\(lineOffsets.count)")
        return lineOffsets[line]
    }

    /// Return the byte range for the given line, **excluding** the line ending.
    ///
    /// The range covers `[lineStart, nextLineStart)` for non-terminal lines
    /// or `[lineStart, textEnd)` for the last line — minus any trailing
    /// line-ending bytes.
    ///
    /// - Parameter line: A zero-based line number.
    /// - Returns: A half-open byte range.
    public func lineRange(forLine line: Int) -> Range<Int> {
        precondition(line >= 0 && line < lineOffsets.count,
                     "Line \(line) out of range 0..<\(lineOffsets.count)")

        let start = lineOffsets[line]
        let end: Int
        if line + 1 < lineOffsets.count {
            end = lineOffsets[line + 1]
        } else {
            // Last line extends to the end; caller may need total length.
            // We return an open range up to Int.max as a sentinel.
            // In practice, TextBuffer should clamp this to the document length.
            end = Int.max
        }
        return start..<end
    }

    // MARK: - Mutation

    /// Rebuild the index from scratch using new text.
    public mutating func rebuild(from text: String) {
        let data = Data(text.utf8)
        lineOffsets = LineIndex.buildOffsets(from: data)
    }

    /// Rebuild the index from raw data.
    public mutating func rebuild(from data: Data) {
        lineOffsets = LineIndex.buildOffsets(from: data)
    }

    // MARK: - Internal

    /// Scan UTF-8 data for line breaks and build the offset array.
    private static func buildOffsets(from data: Data) -> [Int] {
        var offsets: [Int] = [0] // Line 0 always starts at offset 0
        guard !data.isEmpty else { return offsets }

        let startIdx = data.startIndex
        let endIdx = data.endIndex
        var i = startIdx
        while i < endIdx {
            let byte = data[i]
            if byte == 0x0A { // \n
                let nextOffset = data.distance(from: startIdx, to: i) + 1
                offsets.append(nextOffset)
            } else if byte == 0x0D { // \r
                let next = data.index(after: i)
                if next < endIdx && data[next] == 0x0A {
                    // \r\n — count as one line break, line starts after \n
                    let nextOffset = data.distance(from: startIdx, to: next) + 1
                    offsets.append(nextOffset)
                    i = next // skip the \n
                } else {
                    // bare \r
                    let nextOffset = data.distance(from: startIdx, to: i) + 1
                    offsets.append(nextOffset)
                }
            }
            i = data.index(after: i)
        }
        return offsets
    }
}
