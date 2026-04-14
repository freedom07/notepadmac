// TextBuffer.swift
// TextCore — NotepadNext
//
// High-level document model that wraps a PieceTable with undo/redo,
// encoding metadata, line-ending awareness, and change notification.

import Foundation
import CommonKit

// MARK: - EditOperation

/// A single reversible edit operation recorded for undo/redo.
public enum EditOperation {
    /// An insertion at the given offset. To undo, delete `text.utf8.count` bytes
    /// starting at `offset`.
    case insert(offset: Int, text: String)

    /// A deletion of `text` that formerly occupied the byte range starting at
    /// `offset`. To undo, re-insert `text` at `offset`.
    case delete(offset: Int, text: String)

    /// A full-document replacement. To undo, restore `oldText`; to redo,
    /// restore `newText`.
    case replaceAll(oldText: String, newText: String)
}

// MARK: - TextBuffer

/// A high-level document buffer built on top of ``PieceTable``.
///
/// Provides undo/redo, encoding metadata, line-ending awareness,
/// per-line access, and an observable change callback.
public final class TextBuffer {

    // MARK: - Storage

    /// The underlying piece table that stores document content.
    private var pieceTable: PieceTable

    /// A cached line index rebuilt after every edit.
    private var lineIndex: LineIndex

    // MARK: - Metadata

    /// The string encoding of the document (informational; internal storage
    /// is always UTF-8).
    public var encoding: String.Encoding

    /// The dominant line ending style for this document.
    public var lineEnding: LineEnding

    /// Whether the buffer has been modified since it was created or last
    /// marked clean.
    public private(set) var isModified: Bool = false

    // MARK: - Undo / Redo

    /// Stack of operations that can be undone (most recent last).
    private var undoStack: [EditOperation] = []

    /// Stack of operations that can be redone (most recent last).
    private var redoStack: [EditOperation] = []

    /// Whether there are operations available to undo.
    public var canUndo: Bool { !undoStack.isEmpty }

    /// Whether there are operations available to redo.
    public var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Observation

    /// Called after every mutation (insert, delete, replaceAll, undo, redo).
    public var onDidChange: ((TextBuffer) -> Void)?

    // MARK: - Initialization

    /// Create a buffer from a string, optionally specifying encoding and
    /// line ending. If `lineEnding` is nil the dominant ending is auto-detected.
    public init(
        string: String = "",
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding? = nil
    ) {
        self.pieceTable = PieceTable(string: string)
        self.encoding = encoding
        self.lineEnding = lineEnding ?? LineEnding.detect(from: Data(string.utf8))
        self.lineIndex = LineIndex(from: string)
    }

    /// Create a buffer from raw data.
    public init(
        data: Data,
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding? = nil
    ) {
        self.pieceTable = PieceTable(data: data)
        self.encoding = encoding
        self.lineEnding = lineEnding ?? LineEnding.detect(from: data)
        self.lineIndex = LineIndex(from: data)
    }

    // MARK: - Properties

    /// The full text of the document.
    public var text: String {
        pieceTable.text
    }

    /// The total byte length of the document (UTF-8).
    public var length: Int {
        pieceTable.length
    }

    /// The number of lines in the document.
    public var lineCount: Int {
        lineIndex.lineCount
    }

    // MARK: - Line Access

    /// Return the text content of a specific line (zero-based), including the
    /// line ending if present.
    ///
    /// - Parameter line: A zero-based line number.
    /// - Returns: The line's content as a string.
    public func lineContent(at line: Int) -> String {
        precondition(line >= 0 && line < lineCount,
                     "Line \(line) out of range 0..<\(lineCount)")

        let range = lineIndex.lineRange(forLine: line)
        let clampedEnd = min(range.upperBound, pieceTable.length)
        let clampedRange = range.lowerBound..<clampedEnd
        guard !clampedRange.isEmpty else { return "" }
        return pieceTable.text(in: clampedRange)
    }

    // MARK: - Editing

    /// Insert text at the given byte offset.
    ///
    /// - Parameters:
    ///   - offset: A byte offset in `0 ... length`.
    ///   - text: The string to insert.
    public func insert(at offset: Int, text insertedText: String) {
        guard !insertedText.isEmpty else { return }

        pieceTable.insert(at: offset, text: insertedText)

        // Record for undo
        undoStack.append(.insert(offset: offset, text: insertedText))
        redoStack.removeAll()

        rebuildLineIndex()
        isModified = true
        onDidChange?(self)
    }

    /// Delete bytes in the given range.
    ///
    /// - Parameter range: A half-open byte range within `0 ..< length`.
    public func delete(range: Range<Int>) {
        guard !range.isEmpty else { return }

        // Capture the text being deleted for undo
        let deletedText = pieceTable.text(in: range)

        pieceTable.delete(range: range)

        undoStack.append(.delete(offset: range.lowerBound, text: deletedText))
        redoStack.removeAll()

        rebuildLineIndex()
        isModified = true
        onDidChange?(self)
    }

    /// Replace the entire document content.
    ///
    /// - Parameter newText: The replacement string.
    public func replaceAll(with newText: String) {
        let oldText = pieceTable.text

        // Reset the piece table
        pieceTable = PieceTable(string: newText)

        // Record as a single compound undo operation
        undoStack.append(.replaceAll(oldText: oldText, newText: newText))
        redoStack.removeAll()

        rebuildLineIndex()
        isModified = true
        onDidChange?(self)
    }

    // MARK: - Undo / Redo

    /// Undo the last edit operation.
    public func undo() {
        guard let op = undoStack.popLast() else { return }

        switch op {
        case .insert(let offset, let text):
            let byteCount = text.utf8.count
            pieceTable.delete(range: offset..<(offset + byteCount))
            redoStack.append(op)

        case .delete(let offset, let text):
            pieceTable.insert(at: offset, text: text)
            redoStack.append(op)

        case .replaceAll(let oldText, _):
            pieceTable = PieceTable(string: oldText)
            redoStack.append(op)
        }

        rebuildLineIndex()
        isModified = !undoStack.isEmpty
        onDidChange?(self)
    }

    /// Redo the last undone operation.
    public func redo() {
        guard let op = redoStack.popLast() else { return }

        switch op {
        case .insert(let offset, let text):
            pieceTable.insert(at: offset, text: text)
            undoStack.append(op)

        case .delete(let offset, let text):
            let byteCount = text.utf8.count
            pieceTable.delete(range: offset..<(offset + byteCount))
            undoStack.append(op)

        case .replaceAll(_, let newText):
            pieceTable = PieceTable(string: newText)
            undoStack.append(op)
        }

        rebuildLineIndex()
        isModified = true
        onDidChange?(self)
    }

    // MARK: - State Management

    /// Mark the buffer as clean (not modified).
    /// Typically called after saving the document.
    public func markClean() {
        isModified = false
    }

    // MARK: - Private

    /// Rebuild the cached line index from the current document content.
    private func rebuildLineIndex() {
        lineIndex.rebuild(from: pieceTable.text)
    }
}
