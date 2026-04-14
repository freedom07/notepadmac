import XCTest
@testable import TextCore
import CommonKit

// MARK: - PieceTable Tests

final class PieceTableTests: XCTestCase {

    func testInitWithString() {
        let table = PieceTable(string: "Hello World")
        XCTAssertEqual(table.text, "Hello World")
        XCTAssertEqual(table.length, 11)
    }

    func testInsert() {
        let table = PieceTable(string: "Hello World")
        table.insert(at: 5, text: " Beautiful")
        XCTAssertEqual(table.text, "Hello Beautiful World")
    }

    func testDelete() {
        let table = PieceTable(string: "Hello World")
        table.delete(range: 5..<11)
        XCTAssertEqual(table.text, "Hello")
    }

    func testMultipleEdits() {
        let table = PieceTable(string: "Hello World")
        table.insert(at: 5, text: ",")
        // "Hello, World"
        table.delete(range: 6..<7)
        // "Hello,World"
        table.insert(at: 6, text: " Beautiful ")
        // "Hello, Beautiful World"
        XCTAssertEqual(table.text, "Hello, Beautiful World")
    }

    func testEmptyPieceTable() {
        let table = PieceTable(string: "")
        XCTAssertEqual(table.text, "")
        XCTAssertEqual(table.length, 0)
    }

    func testInsertAtBeginning() {
        let table = PieceTable(string: "World")
        table.insert(at: 0, text: "Hello ")
        XCTAssertEqual(table.text, "Hello World")
    }

    func testInsertAtEnd() {
        let table = PieceTable(string: "Hello")
        table.insert(at: 5, text: " World")
        XCTAssertEqual(table.text, "Hello World")
    }

    func testLineCount() {
        let table = PieceTable(string: "Line 1\nLine 2\nLine 3\n")
        XCTAssertEqual(table.lineCount, 4, "Three newlines should produce four lines")
    }

    func testPieceTableTextInRange() {
        let table = PieceTable(string: "Hello World")
        XCTAssertEqual(table.text(in: 0..<5), "Hello")
        XCTAssertEqual(table.text(in: 6..<11), "World")
        XCTAssertEqual(table.text(in: 0..<11), "Hello World")
        XCTAssertEqual(table.text(in: 3..<3), "", "Empty range should return empty string")
    }

    func testPieceTableDeleteAll() {
        let table = PieceTable(string: "Hello World")
        table.delete(range: 0..<11)
        XCTAssertEqual(table.text, "", "Deleting all content should yield empty string")
        XCTAssertEqual(table.length, 0, "Length should be 0 after full deletion")
        XCTAssertEqual(table.lineCount, 1, "Empty document should have 1 line")
    }

    func testPieceTableInsertAfterDelete() {
        let table = PieceTable(string: "Hello World")
        table.delete(range: 0..<11)
        XCTAssertEqual(table.text, "")
        table.insert(at: 0, text: "New Text")
        XCTAssertEqual(table.text, "New Text", "Inserting after full delete should work")
        XCTAssertEqual(table.length, 8)
    }

    func testPieceTableTextInRangeAcrossPieces() {
        let table = PieceTable(string: "ABCDEF")
        // Insert in the middle to create multiple pieces: "ABC" | "XY" | "DEF"
        table.insert(at: 3, text: "XY")
        XCTAssertEqual(table.text, "ABCXYDEF")
        // Read across the piece boundary
        XCTAssertEqual(table.text(in: 2..<6), "CXYD", "Should read across piece boundaries")
        XCTAssertEqual(table.text(in: 0..<8), "ABCXYDEF", "Full range across all pieces")
        XCTAssertEqual(table.text(in: 3..<5), "XY", "Exact inserted piece range")
    }

    func testPieceTableCountLineBreaksCRLF() {
        let table = PieceTable(string: "Line1\r\nLine2\r\nLine3")
        XCTAssertEqual(table.lineCount, 3, "Two CRLF should produce three lines")
    }

    func testPieceTableCountLineBreaksCR() {
        let table = PieceTable(string: "Line1\rLine2\rLine3")
        XCTAssertEqual(table.lineCount, 3, "Two bare CR should produce three lines")
    }

    func testPieceTableInsertEmptyString() {
        let table = PieceTable(string: "Hello")
        table.insert(at: 3, text: "")
        XCTAssertEqual(table.text, "Hello", "Inserting empty string should be a no-op")
        XCTAssertEqual(table.length, 5)
        XCTAssertEqual(table.pieces.count, 1, "No extra pieces should be created")
    }
}

// MARK: - TextBuffer Tests

final class TextBufferTests: XCTestCase {

    func testUndoRedo() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.insert(at: 5, text: " Beautiful")
        XCTAssertEqual(buffer.text, "Hello Beautiful World")

        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World", "Undo should restore original text")

        buffer.redo()
        XCTAssertEqual(buffer.text, "Hello Beautiful World", "Redo should re-apply the edit")
    }

    func testIsModified() {
        let buffer = TextBuffer(string: "Hello")
        XCTAssertFalse(buffer.isModified, "New buffer should not be modified")

        buffer.insert(at: 5, text: " World")
        XCTAssertTrue(buffer.isModified, "Buffer should be modified after an edit")
    }

    func testLineContent() {
        let buffer = TextBuffer(string: "First line\nSecond line\nThird line")
        // lineContent may include the trailing newline; strip it for comparison
        XCTAssertTrue(buffer.lineContent(at: 0).hasPrefix("First line"))
        XCTAssertTrue(buffer.lineContent(at: 1).hasPrefix("Second line"))
        XCTAssertTrue(buffer.lineContent(at: 2).hasPrefix("Third line"))
    }

    func testTextBufferDeleteUndo() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.delete(range: 5..<11)
        XCTAssertEqual(buffer.text, "Hello", "Delete should remove ' World'")
        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World", "Undo should restore deleted text")
    }

    func testTextBufferMarkClean() {
        let buffer = TextBuffer(string: "Hello")
        buffer.insert(at: 5, text: " World")
        XCTAssertTrue(buffer.isModified, "Buffer should be modified after an edit")
        buffer.markClean()
        XCTAssertFalse(buffer.isModified, "markClean should reset isModified to false")
    }

    func testTextBufferReplaceAll() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.replaceAll(with: "Goodbye")
        XCTAssertEqual(buffer.text, "Goodbye", "replaceAll should replace entire content")
        XCTAssertEqual(buffer.length, 7)
        XCTAssertTrue(buffer.isModified)
    }

    func testTextBufferReplaceAllUndo() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.replaceAll(with: "Goodbye")
        XCTAssertEqual(buffer.text, "Goodbye")
        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World", "Undo after replaceAll should restore original")
    }

    func testTextBufferReplaceAllRedo() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.replaceAll(with: "Goodbye")
        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World")
        buffer.redo()
        XCTAssertEqual(buffer.text, "Goodbye", "Redo after undo of replaceAll should re-apply")
    }

    func testTextBufferOnDidChangeCallback() {
        let buffer = TextBuffer(string: "Hello")
        var callCount = 0
        buffer.onDidChange = { _ in
            callCount += 1
        }

        buffer.insert(at: 5, text: " World")
        XCTAssertEqual(callCount, 1, "Callback should fire on insert")

        buffer.delete(range: 5..<11)
        XCTAssertEqual(callCount, 2, "Callback should fire on delete")

        buffer.replaceAll(with: "New")
        XCTAssertEqual(callCount, 3, "Callback should fire on replaceAll")

        buffer.undo()
        XCTAssertEqual(callCount, 4, "Callback should fire on undo")

        buffer.redo()
        XCTAssertEqual(callCount, 5, "Callback should fire on redo")
    }

    func testTextBufferCanUndoCanRedo() {
        let buffer = TextBuffer(string: "Hello")
        XCTAssertFalse(buffer.canUndo, "Fresh buffer should not be undoable")
        XCTAssertFalse(buffer.canRedo, "Fresh buffer should not be redoable")

        buffer.insert(at: 5, text: "!")
        XCTAssertTrue(buffer.canUndo, "After edit, canUndo should be true")
        XCTAssertFalse(buffer.canRedo, "After new edit, canRedo should be false")

        buffer.undo()
        XCTAssertFalse(buffer.canUndo, "After undoing the only edit, canUndo should be false")
        XCTAssertTrue(buffer.canRedo, "After undo, canRedo should be true")

        buffer.redo()
        XCTAssertTrue(buffer.canUndo, "After redo, canUndo should be true")
        XCTAssertFalse(buffer.canRedo, "After redo, canRedo should be false")
    }

    func testTextBufferMultipleUndoRedo() {
        let buffer = TextBuffer(string: "A")
        buffer.insert(at: 1, text: "B")  // "AB"
        buffer.insert(at: 2, text: "C")  // "ABC"
        buffer.insert(at: 3, text: "D")  // "ABCD"
        XCTAssertEqual(buffer.text, "ABCD")

        buffer.undo()
        XCTAssertEqual(buffer.text, "ABC", "First undo should remove D")
        buffer.undo()
        XCTAssertEqual(buffer.text, "AB", "Second undo should remove C")
        buffer.undo()
        XCTAssertEqual(buffer.text, "A", "Third undo should remove B")

        buffer.redo()
        XCTAssertEqual(buffer.text, "AB", "First redo should restore B")
        buffer.redo()
        XCTAssertEqual(buffer.text, "ABC", "Second redo should restore C")
        buffer.redo()
        XCTAssertEqual(buffer.text, "ABCD", "Third redo should restore D")
    }

    func testTextBufferDeleteUndoRedo() {
        let buffer = TextBuffer(string: "Hello World")
        buffer.delete(range: 5..<11)
        XCTAssertEqual(buffer.text, "Hello")

        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World", "Undo delete should restore text")

        buffer.redo()
        XCTAssertEqual(buffer.text, "Hello", "Redo delete should remove text again")

        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello World", "Second undo should restore again")
    }
}

// MARK: - LineIndex Tests

final class LineIndexTests: XCTestCase {

    func testLineOffsets() {
        let text = "Hello\nWorld\nFoo\n"
        let index = LineIndex(from: text)
        let offsets = index.lineOffsets

        XCTAssertEqual(offsets.count, 4, "Three newlines should yield four line offsets")
        XCTAssertEqual(offsets[0], 0, "First line starts at offset 0")
        XCTAssertEqual(offsets[1], 6, "Second line starts at offset 6")
        XCTAssertEqual(offsets[2], 12, "Third line starts at offset 12")
        XCTAssertEqual(offsets[3], 16, "Fourth (empty) line starts at offset 16")
    }

    func testLineNumberForOffset() {
        let text = "Hello\nWorld\nFoo"
        let index = LineIndex(from: text)

        XCTAssertEqual(index.lineNumber(forOffset: 0), 0, "Offset 0 should be line 0")
        XCTAssertEqual(index.lineNumber(forOffset: 3), 0, "Offset 3 should be line 0")
        XCTAssertEqual(index.lineNumber(forOffset: 6), 1, "Offset 6 should be line 1")
        XCTAssertEqual(index.lineNumber(forOffset: 12), 2, "Offset 12 should be line 2")
    }

    func testOffsetForLine() {
        let text = "Hello\nWorld\nFoo"
        let index = LineIndex(from: text)

        XCTAssertEqual(index.offset(forLine: 0), 0, "Line 0 should start at offset 0")
        XCTAssertEqual(index.offset(forLine: 1), 6, "Line 1 should start at offset 6")
        XCTAssertEqual(index.offset(forLine: 2), 12, "Line 2 should start at offset 12")
    }

    func testLineIndexRebuild() {
        var index = LineIndex(from: "Hello\nWorld")
        XCTAssertEqual(index.lineCount, 2)
        index.rebuild(from: "A\nB\nC\nD")
        XCTAssertEqual(index.lineCount, 4, "Rebuild should reflect the new text")
        XCTAssertEqual(index.offset(forLine: 2), 4, "Line 2 should start at offset 4 in 'A\\nB\\nC\\nD'")
    }

    func testLineIndexCRLF() {
        let text = "Line1\r\nLine2\r\nLine3"
        let index = LineIndex(from: text)
        XCTAssertEqual(index.lineCount, 3, "Two CRLF should produce three lines")
        XCTAssertEqual(index.offset(forLine: 0), 0)
        XCTAssertEqual(index.offset(forLine: 1), 7, "After 'Line1\\r\\n' (7 bytes)")
        XCTAssertEqual(index.offset(forLine: 2), 14, "After 'Line2\\r\\n' (7 bytes)")
    }

    func testLineIndexEmptyText() {
        let index = LineIndex(from: "")
        XCTAssertEqual(index.lineCount, 1, "Empty text should have exactly 1 line")
        XCTAssertEqual(index.offset(forLine: 0), 0, "Only line starts at offset 0")
    }

    func testLineIndexCRLineEnding() {
        let text = "AAA\rBBB\rCCC"
        let index = LineIndex(from: text)
        XCTAssertEqual(index.lineCount, 3, "Two bare CR should produce three lines")
        XCTAssertEqual(index.offset(forLine: 0), 0)
        XCTAssertEqual(index.offset(forLine: 1), 4, "After 'AAA\\r' (4 bytes)")
        XCTAssertEqual(index.offset(forLine: 2), 8, "After 'BBB\\r' (4 bytes)")
    }

    func testLineIndexLineRange() {
        let text = "Hello\nWorld\nFoo"
        let index = LineIndex(from: text)

        let range0 = index.lineRange(forLine: 0)
        XCTAssertEqual(range0.lowerBound, 0, "Line 0 starts at 0")
        XCTAssertEqual(range0.upperBound, 6, "Line 0 ends at 6 (includes newline)")

        let range1 = index.lineRange(forLine: 1)
        XCTAssertEqual(range1.lowerBound, 6, "Line 1 starts at 6")
        XCTAssertEqual(range1.upperBound, 12, "Line 1 ends at 12 (includes newline)")

        let range2 = index.lineRange(forLine: 2)
        XCTAssertEqual(range2.lowerBound, 12, "Line 2 starts at 12")
        // Last line returns Int.max as sentinel
        XCTAssertEqual(range2.upperBound, Int.max, "Last line range extends to Int.max sentinel")
    }

    func testLineIndexOffsetForLine() {
        let text = "AB\nCD\nEF\nGH"
        let index = LineIndex(from: text)
        XCTAssertEqual(index.lineCount, 4)

        // Verify round-trip: offset(forLine:) -> lineNumber(forOffset:) -> same line
        for line in 0..<index.lineCount {
            let offset = index.offset(forLine: line)
            let computedLine = index.lineNumber(forOffset: offset)
            XCTAssertEqual(computedLine, line,
                           "Round-trip failed: offset(forLine: \(line)) = \(offset), lineNumber(forOffset: \(offset)) = \(computedLine)")
        }

        // Also verify concrete values
        XCTAssertEqual(index.offset(forLine: 0), 0)
        XCTAssertEqual(index.offset(forLine: 1), 3, "After 'AB\\n'")
        XCTAssertEqual(index.offset(forLine: 2), 6, "After 'CD\\n'")
        XCTAssertEqual(index.offset(forLine: 3), 9, "After 'EF\\n'")
    }
}
