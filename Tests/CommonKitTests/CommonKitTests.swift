import XCTest
@testable import CommonKit

// MARK: - LineEnding Tests

final class LineEndingTests: XCTestCase {

    func testDetectLF() {
        let text = "Hello\nWorld\nFoo\n"
        let data = Data(text.utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .lf)
    }

    func testDetectCRLF() {
        let text = "Hello\r\nWorld\r\nFoo\r\n"
        let data = Data(text.utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .crlf)
    }

    func testDetectCR() {
        // Build CR-only data manually to avoid Swift interpreting \r\n as a pair
        let text = "Hello\rWorld\rFoo\r"
        let data = Data(text.utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .cr)
    }

    func testDetectEmpty() {
        let data = Data()
        XCTAssertEqual(LineEnding.detect(from: data), .lf, "Empty data should default to .lf")
    }

    func testLineEndingMixedCRLFAndLF() {
        // 3 CRLF + 2 LF → CRLF wins
        let text = "A\r\nB\r\nC\r\nD\nE\n"
        let data = Data(text.utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .crlf, "CRLF (3) should beat LF (2)")
    }

    func testLineEndingMixedCRAndLF() {
        // 3 CR + 2 LF → CR wins
        var bytes: [UInt8] = []
        bytes.append(contentsOf: "A".utf8); bytes.append(0x0D)
        bytes.append(contentsOf: "B".utf8); bytes.append(0x0D)
        bytes.append(contentsOf: "C".utf8); bytes.append(0x0D)
        bytes.append(contentsOf: "D".utf8); bytes.append(0x0A)
        bytes.append(contentsOf: "E".utf8); bytes.append(0x0A)
        let data = Data(bytes)
        XCTAssertEqual(LineEnding.detect(from: data), .cr, "CR (3) should beat LF (2)")
    }

    func testLineEndingNoNewlines() {
        let data = Data("Hello World".utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .lf, "No newlines should default to .lf")
    }

    func testLineEndingTie() {
        // 2 CRLF + 2 LF → CRLF wins on tie (>= comparison)
        let text = "A\r\nB\r\nC\nD\n"
        let data = Data(text.utf8)
        XCTAssertEqual(LineEnding.detect(from: data), .crlf, "CRLF should win on tie with LF")
    }

    func testDisplayName() {
        XCTAssertEqual(LineEnding.lf.displayName, "LF (Unix)")
        XCTAssertEqual(LineEnding.crlf.displayName, "CRLF (Windows)")
        XCTAssertEqual(LineEnding.cr.displayName, "CR (Classic Mac)")
    }
}

// MARK: - TextPosition Tests

final class TextPositionTests: XCTestCase {

    func testEquatable() {
        let a = TextPosition(line: 3, column: 7)
        let b = TextPosition(line: 3, column: 7)
        XCTAssertEqual(a, b)

        let c = TextPosition(line: 3, column: 8)
        XCTAssertNotEqual(a, c)
    }

    func testComparable() {
        let line1 = TextPosition(line: 1, column: 5)
        let line2 = TextPosition(line: 2, column: 0)
        XCTAssertTrue(line1 < line2, "Line 1 should be less than line 2")

        let sameLineColA = TextPosition(line: 4, column: 1)
        let sameLineColB = TextPosition(line: 4, column: 9)
        XCTAssertTrue(sameLineColA < sameLineColB, "Same line, smaller column should be less")

        // Equal positions are not less than each other
        let equal = TextPosition(line: 4, column: 1)
        XCTAssertFalse(sameLineColA < equal)
    }

    func testHashable() {
        let a = TextPosition(line: 0, column: 0)
        let b = TextPosition(line: 0, column: 0)
        let c = TextPosition(line: 1, column: 0)

        var set = Set<TextPosition>()
        set.insert(a)
        set.insert(b) // duplicate – should not increase count
        set.insert(c)

        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(a))
        XCTAssertTrue(set.contains(c))
    }
}

// MARK: - TextRange Tests

final class TextRangeTests: XCTestCase {

    func testIsEmpty() {
        let pos = TextPosition(line: 2, column: 5)
        let range = TextRange(start: pos, end: pos)
        XCTAssertTrue(range.isEmpty, "Range with same start and end should be empty")

        let range2 = TextRange(
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 1)
        )
        XCTAssertFalse(range2.isEmpty)
    }

    func testLineSpan() {
        let range = TextRange(
            start: TextPosition(line: 2, column: 0),
            end: TextPosition(line: 5, column: 10)
        )
        XCTAssertEqual(range.lineSpan, 4, "Lines 2-5 inclusive = 4 lines")

        let singleLine = TextRange(
            start: TextPosition(line: 3, column: 0),
            end: TextPosition(line: 3, column: 8)
        )
        XCTAssertEqual(singleLine.lineSpan, 1)
    }
}

// MARK: - Debouncer Tests

final class DebouncerTests: XCTestCase {

    func testDebouncerCallsAction() {
        let expectation = expectation(description: "Debouncer fires action")
        let debouncer = Debouncer(delay: 0.05, queue: .main)

        debouncer.debounce {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testDebouncerCancel() {
        let debouncer = Debouncer(delay: 0.05, queue: .main)
        var fired = false

        debouncer.debounce { fired = true }
        debouncer.cancel()

        // Wait long enough for the action to have fired if not cancelled
        let expectation = expectation(description: "Wait for potential fire")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(fired, "Action should not fire after cancel()")
    }

    func testDebouncerCancelsPrevious() {
        let expectation = expectation(description: "Only last call fires")
        var callCount = 0
        let debouncer = Debouncer(delay: 0.1, queue: .main)

        // Fire rapidly – only the last should execute
        for i in 0..<5 {
            debouncer.debounce {
                callCount += 1
                if i == 4 {
                    expectation.fulfill()
                }
            }
        }

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(callCount, 1, "Only the last debounced action should execute")
    }
}

// MARK: - Disposable Tests

final class DisposableTests: XCTestCase {

    func testActionDisposable() {
        var disposed = false
        let disposable = ActionDisposable { disposed = true }

        XCTAssertFalse(disposed)
        disposable.dispose()
        XCTAssertTrue(disposed, "Dispose should call the action")

        // Calling dispose again should be safe (action is nil'd)
        disposed = false
        disposable.dispose()
        XCTAssertFalse(disposed, "Second dispose should not call the action again")
    }

    func testDisposeBag() {
        var count = 0
        var bag: DisposeBag? = DisposeBag()

        let d1 = ActionDisposable { count += 1 }
        let d2 = ActionDisposable { count += 1 }
        let d3 = ActionDisposable { count += 1 }

        bag!.add(d1)
        bag!.add(d2)
        bag!.add(d3)

        // Setting bag to nil triggers deinit which calls disposeAll
        bag = nil

        XCTAssertEqual(count, 3, "All three disposables should be disposed on bag deinit")
    }
}

// MARK: - String Extension Tests

final class StringExtensionTests: XCTestCase {

    func testLineCount() {
        XCTAssertEqual("".lineCount, 1, "Empty string has 1 line")
        XCTAssertEqual("Hello".lineCount, 1, "Single line without newline")
        XCTAssertEqual("Hello\n".lineCount, 2, "Trailing newline adds an extra line")
        XCTAssertEqual("Hello\nWorld".lineCount, 2, "Two lines")
        XCTAssertEqual("A\nB\nC\n".lineCount, 4, "Three newlines = 4 lines")
    }

    func testLineCountCRLF() {
        XCTAssertEqual("Hello\r\nWorld\r\n".lineCount, 3, "Two CRLF = 3 lines")
    }

    func testLineCountCR() {
        XCTAssertEqual("Hello\rWorld\r".lineCount, 3, "Two CR = 3 lines")
    }

    func testLineCountMixed() {
        // LF + CRLF + CR = 4 lines total
        XCTAssertEqual("A\nB\r\nC\rD".lineCount, 4, "Mixed line endings: LF + CRLF + CR = 4 lines")
    }

    func testNSRangeConversion() {
        let str = "Hello, World!"
        let swiftRange = str.index(str.startIndex, offsetBy: 7)..<str.index(str.startIndex, offsetBy: 12)
        let nsRange = str.nsRange(from: swiftRange)
        XCTAssertEqual(nsRange.location, 7)
        XCTAssertEqual(nsRange.length, 5)

        // Convert back
        let recovered = str.range(from: nsRange)
        XCTAssertNotNil(recovered)
        XCTAssertEqual(String(str[recovered!]), "World")
    }

    func testNSRangeWithEmoji() {
        let str = "Hi 👋 there"
        // "Hi " = 3 chars, 👋 = 1 Swift Character but 2 UTF-16 code units
        let rangeStart = str.index(str.startIndex, offsetBy: 3) // 👋
        let rangeEnd = str.index(str.startIndex, offsetBy: 4)   // after 👋
        let nsRange = str.nsRange(from: rangeStart..<rangeEnd)
        XCTAssertEqual(nsRange.location, 3)
        XCTAssertEqual(nsRange.length, 2, "Emoji should be 2 UTF-16 code units")
    }

    func testNSRangeWithKorean() {
        let str = "안녕하세요 Hello"
        // "안녕" = 2 chars, each 1 UTF-16 code unit
        let rangeStart = str.startIndex
        let rangeEnd = str.index(str.startIndex, offsetBy: 2)
        let nsRange = str.nsRange(from: rangeStart..<rangeEnd)
        XCTAssertEqual(nsRange.location, 0)
        XCTAssertEqual(nsRange.length, 2, "Korean characters are 1 UTF-16 code unit each")

        // Round-trip
        let recovered = str.range(from: nsRange)
        XCTAssertNotNil(recovered)
        XCTAssertEqual(String(str[recovered!]), "안녕")
    }

    func testFullNSRange() {
        let str = "ABCDE"
        let range = str.fullNSRange
        XCTAssertEqual(range.location, 0)
        XCTAssertEqual(range.length, 5)
    }

    func testFullNSRangeEmoji() {
        let str = "🇰🇷🎉"
        let range = str.fullNSRange
        XCTAssertEqual(range.location, 0)
        // 🇰🇷 = flag emoji (4 UTF-16 code units: 2 regional indicators × 2 each)
        // 🎉 = 2 UTF-16 code units
        let expected = (str as NSString).length
        XCTAssertEqual(range.length, expected, "fullNSRange.length should match NSString length")
    }

    func testUTF16Offset() {
        let str = "Hello"
        let idx = str.index(str.startIndex, offsetBy: 3)
        XCTAssertEqual(str.utf16Offset(of: idx), 3)
    }

    func testStringIndexFromUTF16Offset() {
        let str = "Hello"
        let idx = str.stringIndex(fromUTF16Offset: 3)
        XCTAssertNotNil(idx)
        XCTAssertEqual(str[idx!], "l")

        // Out of range
        let bad = str.stringIndex(fromUTF16Offset: 100)
        XCTAssertNil(bad)
    }

    func testStringIndexFromUTF16OffsetZero() {
        let str = "Hello"
        let idx = str.stringIndex(fromUTF16Offset: 0)
        XCTAssertNotNil(idx)
        XCTAssertEqual(idx, str.startIndex)
    }

    func testSafeSubscript() {
        let str = "Hello"
        XCTAssertEqual(str[0..<5], "Hello")
        XCTAssertEqual(str[1..<4], "ell")
        // Out of range returns nil
        XCTAssertNil(str[0..<100])
    }

    func testTextPosition() {
        let str = "Line0\nLine1\nLine2"
        let target = str.index(str.startIndex, offsetBy: 12) // 'L' in "Line2"
        let pos = str.textPosition(at: target)
        XCTAssertEqual(pos.line, 2)
        XCTAssertEqual(pos.column, 0)

        // Middle of a line
        let target2 = str.index(str.startIndex, offsetBy: 8) // 'n' in "Line1"
        let pos2 = str.textPosition(at: target2)
        XCTAssertEqual(pos2.line, 1)
        XCTAssertEqual(pos2.column, 2)
    }

    func testTextPositionAtStart() {
        let str = "Hello\nWorld"
        let pos = str.textPosition(at: str.startIndex)
        XCTAssertEqual(pos.line, 0)
        XCTAssertEqual(pos.column, 0)
    }

    func testTextPositionAtEnd() {
        let str = "Hello\nWorld"
        let pos = str.textPosition(at: str.endIndex)
        XCTAssertEqual(pos.line, 1, "endIndex is on line 1")
        XCTAssertEqual(pos.column, 5, "endIndex column should be 5 (length of 'World')")
    }
}

// MARK: - Data Extension Tests (BOM Detection)

final class DataExtensionTests: XCTestCase {

    func testDetectUTF8BOM() {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let content: [UInt8] = Array("Hello".utf8)
        let data = Data(bom + content)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf8)
    }

    func testDetectUTF16LEBOM() {
        // UTF-16 LE BOM: FF FE (without 00 00 following – that would be UTF-32 LE)
        let bom: [UInt8] = [0xFF, 0xFE, 0x48, 0x00] // "H" in UTF-16 LE after BOM
        let data = Data(bom)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf16LittleEndian)
    }

    func testStrippingBOM() {
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let content: [UInt8] = Array("Hello".utf8)
        let data = Data(bom + content)

        let stripped = data.strippingBOM()
        XCTAssertEqual(stripped.count, content.count)
        XCTAssertEqual(String(data: stripped, encoding: .utf8), "Hello")
    }

    func testBOMDetectionUTF16BE() {
        let bom: [UInt8] = [0xFE, 0xFF, 0x00, 0x48] // BOM + "H" in UTF-16 BE
        let data = Data(bom)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf16BigEndian)
        XCTAssertEqual(data.bomLength, 2)
    }

    func testBOMDetectionUTF32BE() {
        let bom: [UInt8] = [0x00, 0x00, 0xFE, 0xFF, 0x00, 0x00, 0x00, 0x48]
        let data = Data(bom)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf32BigEndian)
        XCTAssertEqual(data.bomLength, 4)
    }

    func testBOMDetectionUTF32LE() {
        // UTF-32 LE BOM: FF FE 00 00 — must be distinguished from UTF-16 LE (FF FE)
        let bom: [UInt8] = [0xFF, 0xFE, 0x00, 0x00, 0x48, 0x00, 0x00, 0x00]
        let data = Data(bom)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf32LittleEndian,
                       "FF FE 00 00 should be detected as UTF-32 LE, not UTF-16 LE")
        XCTAssertEqual(data.bomLength, 4)
    }

    func testBOMOnlyData() {
        // UTF-8 BOM with no content
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        let data = Data(bom)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding.stringEncoding, .utf8)
        XCTAssertEqual(data.bomLength, 3)
        let stripped = data.strippingBOM()
        XCTAssertTrue(stripped.isEmpty, "Stripping BOM from BOM-only data should yield empty data")
    }

    func testNoBOM() {
        let data = Data("Hello".utf8)
        let encoding = data.detectEncoding()
        XCTAssertEqual(encoding, .unknown)
        XCTAssertEqual(data.bomLength, 0)
        XCTAssertEqual(data.strippingBOM(), data, "Data without BOM should be returned unchanged")
    }
}

// MARK: - NSRange Extension Tests

final class NSRangeExtensionTests: XCTestCase {

    func testUTF16StartEnd() {
        let range = NSRange(utf16Start: 5, utf16End: 10)
        XCTAssertEqual(range.location, 5)
        XCTAssertEqual(range.length, 5)
        XCTAssertEqual(range.end, 10)
    }

    func testIsEmpty() {
        let empty = NSRange(location: 3, length: 0)
        XCTAssertTrue(empty.isEmpty)

        let nonEmpty = NSRange(location: 3, length: 1)
        XCTAssertFalse(nonEmpty.isEmpty)
    }
}

