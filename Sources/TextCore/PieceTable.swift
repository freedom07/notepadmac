// PieceTable.swift
// TextCore — NotepadNext
//
// A piece table data structure for efficient text editing.
// The original buffer is immutable (suitable for mmap); edits append
// to a separate add buffer. An ordered array of pieces describes the
// logical document. (A Red-Black tree can replace the array later for
// O(log n) piece lookup.)

import Foundation
import CommonKit

// MARK: - BufferType

/// Identifies which backing buffer a piece references.
public enum BufferType: Sendable {
    /// The immutable original content loaded from disk.
    case original
    /// The append-only buffer that accumulates inserted text.
    case add
}

// MARK: - Piece

/// A descriptor pointing into one of the two buffers.
public struct Piece: Sendable {
    /// Which buffer this piece reads from.
    public let buffer: BufferType
    /// Byte offset into the buffer where this piece begins.
    public let start: Int
    /// Length of this piece in bytes.
    public let length: Int
    /// Number of line breaks (`\n`, `\r\n`, or `\r`) contained in this piece.
    public let lineBreakCount: Int

    public init(buffer: BufferType, start: Int, length: Int, lineBreakCount: Int) {
        self.buffer = buffer
        self.start = start
        self.length = length
        self.lineBreakCount = lineBreakCount
    }
}

// MARK: - PieceTable

/// A piece-table–based text storage.
///
/// The logical document is described by an ordered list of ``Piece`` values.
/// The original buffer is immutable; all mutations append to the add buffer
/// and adjust the piece list.
public final class PieceTable {

    // MARK: Buffers

    /// Immutable buffer holding the initial document content.
    public private(set) var originalBuffer: Data

    /// Append-only buffer for inserted text.
    public private(set) var addBuffer: Data

    /// Ordered list of pieces that describe the logical document.
    /// (Array for simplicity; can be replaced by a Red-Black tree for
    /// O(log n) lookup on very large documents.)
    public private(set) var pieces: [Piece]

    // MARK: - Initializers

    /// Create a piece table from a Swift `String`.
    public init(string: String = "") {
        let data = Data(string.utf8)
        self.originalBuffer = data
        self.addBuffer = Data()

        if data.isEmpty {
            self.pieces = []
        } else {
            let lineBreaks = PieceTable.countLineBreaks(in: data, start: 0, length: data.count)
            self.pieces = [
                Piece(buffer: .original, start: 0, length: data.count, lineBreakCount: lineBreaks)
            ]
        }
    }

    /// Create a piece table from raw `Data` (e.g. an mmap'd file).
    public init(data: Data) {
        self.originalBuffer = data
        self.addBuffer = Data()

        if data.isEmpty {
            self.pieces = []
        } else {
            let lineBreaks = PieceTable.countLineBreaks(in: data, start: 0, length: data.count)
            self.pieces = [
                Piece(buffer: .original, start: 0, length: data.count, lineBreakCount: lineBreaks)
            ]
        }
    }

    // MARK: - Public properties

    /// The total byte length of the logical document.
    public var length: Int {
        pieces.reduce(0) { $0 + $1.length }
    }

    /// The full text of the document reconstructed from the piece table.
    public var text: String {
        var result = Data()
        result.reserveCapacity(length)
        for piece in pieces {
            let buf = bufferData(for: piece.buffer)
            let start = buf.startIndex.advanced(by: piece.start)
            let end = start.advanced(by: piece.length)
            result.append(buf[start..<end])
        }
        return String(decoding: result, as: UTF8.self)
    }

    /// The number of lines in the document.
    /// An empty document has 1 line. A trailing newline adds an extra line.
    public var lineCount: Int {
        let breaks = pieces.reduce(0) { $0 + $1.lineBreakCount }
        return breaks + 1
    }

    // MARK: - Editing

    /// Insert `text` at the given byte `offset`.
    ///
    /// - Parameters:
    ///   - offset: A byte offset in the logical document (0 ... length).
    ///   - text: The string to insert.
    public func insert(at offset: Int, text insertedText: String) {
        precondition(offset >= 0 && offset <= length, "Insert offset out of bounds")
        guard !insertedText.isEmpty else { return }

        let insertData = Data(insertedText.utf8)
        let addStart = addBuffer.count
        addBuffer.append(insertData)

        let newLineBreaks = PieceTable.countLineBreaks(in: addBuffer, start: addStart, length: insertData.count)
        let newPiece = Piece(buffer: .add, start: addStart, length: insertData.count, lineBreakCount: newLineBreaks)

        if pieces.isEmpty {
            pieces.append(newPiece)
            return
        }

        let (pieceIndex, offsetInPiece) = findPiece(at: offset)

        if offsetInPiece == 0 {
            // Insert before the piece at pieceIndex
            pieces.insert(newPiece, at: pieceIndex)
        } else {
            let existing = pieces[pieceIndex]
            if offsetInPiece == existing.length {
                // Insert right after this piece
                pieces.insert(newPiece, at: pieceIndex + 1)
            } else {
                // Split the existing piece
                let (left, right) = splitPiece(existing, at: offsetInPiece)
                pieces.replaceSubrange(pieceIndex...pieceIndex, with: [left, newPiece, right])
            }
        }
    }

    /// Delete bytes in the given range.
    ///
    /// - Parameter range: A half-open byte range within `0 ..< length`.
    public func delete(range: Range<Int>) {
        precondition(range.lowerBound >= 0 && range.upperBound <= length, "Delete range out of bounds")
        guard !range.isEmpty else { return }

        let start = range.lowerBound
        let end = range.upperBound

        let (startPieceIdx, startOffset) = findPiece(at: start)
        let (endPieceIdx, endOffset) = findPiece(at: end)

        var newPieces: [Piece] = []

        // Left remnant of the start piece
        if startOffset > 0 {
            let p = pieces[startPieceIdx]
            let leftData = sliceData(piece: p, offset: 0, length: startOffset)
            let lb = PieceTable.countLineBreaks(in: leftData, start: 0, length: leftData.count)
            newPieces.append(Piece(buffer: p.buffer, start: p.start, length: startOffset, lineBreakCount: lb))
        }

        // Right remnant of the end piece
        if endOffset > 0, endPieceIdx < pieces.count {
            let p = pieces[endPieceIdx]
            let remaining = p.length - endOffset
            if remaining > 0 {
                let rightStart = p.start + endOffset
                let rightData = sliceData(piece: p, offset: endOffset, length: remaining)
                let lb = PieceTable.countLineBreaks(in: rightData, start: 0, length: rightData.count)
                newPieces.append(Piece(buffer: p.buffer, start: rightStart, length: remaining, lineBreakCount: lb))
            }
        } else if endOffset == 0, endPieceIdx < pieces.count {
            // The end piece is untouched; keep everything from endPieceIdx onward
        }

        // Determine the replacement range
        let replaceEnd: Int
        if endOffset == 0 {
            replaceEnd = endPieceIdx
        } else {
            replaceEnd = min(endPieceIdx + 1, pieces.count)
        }

        let replaceRange = startPieceIdx..<replaceEnd
        pieces.replaceSubrange(replaceRange, with: newPieces)
    }

    /// Return the substring for the given byte range.
    ///
    /// - Parameter range: A half-open byte range within `0 ..< length`.
    /// - Returns: The text within that range.
    public func text(in range: Range<Int>) -> String {
        precondition(range.lowerBound >= 0 && range.upperBound <= length, "Range out of bounds")
        guard !range.isEmpty else { return "" }

        var result = Data()
        result.reserveCapacity(range.count)

        var currentOffset = 0
        for piece in pieces {
            let pieceEnd = currentOffset + piece.length
            defer { currentOffset = pieceEnd }

            // Skip pieces entirely before the range
            if pieceEnd <= range.lowerBound { continue }
            // Stop once we pass the range
            if currentOffset >= range.upperBound { break }

            let sliceStart = max(range.lowerBound - currentOffset, 0)
            let sliceEnd = min(range.upperBound - currentOffset, piece.length)
            let data = sliceData(piece: piece, offset: sliceStart, length: sliceEnd - sliceStart)
            result.append(data)
        }

        return String(decoding: result, as: UTF8.self)
    }

    // MARK: - Piece Finding

    /// Locate the piece that contains the given byte offset.
    ///
    /// - Parameter offset: A byte offset (0 ... length).
    /// - Returns: A tuple of (piece index, offset within that piece).
    ///   When `offset == length`, returns `(pieces.count, 0)`.
    public func findPiece(at offset: Int) -> (pieceIndex: Int, offsetInPiece: Int) {
        var running = 0
        for (index, piece) in pieces.enumerated() {
            if offset < running + piece.length {
                return (index, offset - running)
            }
            running += piece.length
        }
        // offset == length (end of document)
        return (pieces.count, 0)
    }

    // MARK: - Private Helpers

    /// Return the backing data for the given buffer type.
    private func bufferData(for type: BufferType) -> Data {
        switch type {
        case .original: return originalBuffer
        case .add:      return addBuffer
        }
    }

    /// Extract raw bytes from a piece.
    private func sliceData(piece: Piece, offset: Int, length: Int) -> Data {
        let buf = bufferData(for: piece.buffer)
        let start = buf.startIndex.advanced(by: piece.start + offset)
        let end = start.advanced(by: length)
        return buf[start..<end]
    }

    /// Split a piece at the given internal byte offset.
    private func splitPiece(_ piece: Piece, at offset: Int) -> (Piece, Piece) {
        let leftData = sliceData(piece: piece, offset: 0, length: offset)
        let leftLB = PieceTable.countLineBreaks(in: leftData, start: 0, length: leftData.count)

        let rightLen = piece.length - offset
        let rightData = sliceData(piece: piece, offset: offset, length: rightLen)
        let rightLB = PieceTable.countLineBreaks(in: rightData, start: 0, length: rightData.count)

        let left = Piece(buffer: piece.buffer, start: piece.start, length: offset, lineBreakCount: leftLB)
        let right = Piece(buffer: piece.buffer, start: piece.start + offset, length: rightLen, lineBreakCount: rightLB)
        return (left, right)
    }

    /// Count line breaks (`\n`, `\r\n`, `\r`) in a data slice.
    internal static func countLineBreaks(in data: Data, start: Int, length: Int) -> Int {
        guard length > 0 else { return 0 }
        var count = 0
        let startIdx = data.startIndex.advanced(by: start)
        let endIdx = startIdx.advanced(by: length)
        var i = startIdx
        while i < endIdx {
            let byte = data[i]
            if byte == 0x0A { // \n
                count += 1
            } else if byte == 0x0D { // \r
                count += 1
                // Skip the following \n if this is \r\n
                let next = data.index(after: i)
                if next < endIdx && data[next] == 0x0A {
                    i = next // will be advanced again below
                }
            }
            i = data.index(after: i)
        }
        return count
    }
}
