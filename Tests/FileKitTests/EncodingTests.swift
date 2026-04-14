import XCTest
@testable import FileKit
import CommonKit

// MARK: - EncodingManager Tests

final class EncodingTests: XCTestCase {
    func testBOMDetectionUTF8() {
        let data = Data([0xEF, 0xBB, 0xBF]) + "hello".data(using: .utf8)!
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf8)
    }
    func testBOMDetectionUTF16LE() {
        let data = Data([0xFF, 0xFE]) + "hi".data(using: .utf16LittleEndian)!
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf16LittleEndian)
    }
    func testBOMDetectionUTF16BE() {
        let data = Data([0xFE, 0xFF]) + "hi".data(using: .utf16BigEndian)!
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf16BigEndian)
    }
    func testUTF8FallbackDetection() {
        let data = "Hello World".data(using: .utf8)!
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf8)
    }
    func testEncodingNameDisplay() {
        XCTAssertEqual(EncodingManager.encodingName(.utf8), "UTF-8")
    }
    func testLineEndingDetectionLF() {
        let data = "line1\nline2\n".data(using: .utf8)!
        XCTAssertEqual(LineEnding.detect(from: data), .lf)
    }
    func testLineEndingDetectionCRLF() {
        let data = "line1\r\nline2\r\n".data(using: .utf8)!
        XCTAssertEqual(LineEnding.detect(from: data), .crlf)
    }

    func testUTF32LEDetection() {
        let data = Data([0xFF, 0xFE, 0x00, 0x00]) + "hi".data(using: .utf32LittleEndian)!
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf32LittleEndian)
    }

    func testEmptyDataDetection() {
        let data = Data()
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf8, "Empty data should default to UTF-8")
    }

    func testEncodingConversion() {
        let text = "Hello World"
        let converted = EncodingManager.convert(text: text, to: .utf16LittleEndian)
        XCTAssertNotNil(converted, "Conversion to UTF-16 LE should succeed")
        let roundTrip = String(data: converted!, encoding: .utf16LittleEndian)
        XCTAssertEqual(roundTrip, text, "Round-trip conversion should preserve text")
    }

    // -- Additional EncodingManager tests --

    func testDetectEncodingUTF32BE() {
        let bom = Data([0x00, 0x00, 0xFE, 0xFF])
        let payload = "A".data(using: .utf32BigEndian)!
        let data = bom + payload
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .utf32BigEndian,
                       "UTF-32 BE BOM should be detected")
    }

    func testISOLatin1Fallback() {
        // Bytes 0x80-0xFF that are invalid as a UTF-8 sequence
        let data = Data([0xC0, 0xC1, 0xFE, 0xFF, 0x80, 0x81])
        XCTAssertEqual(EncodingManager.detectEncoding(from: data), .isoLatin1,
                       "Invalid UTF-8 bytes should fall back to ISO Latin-1")
    }

    func testDetectEncodingCR() {
        let data = "line1\rline2\rline3\r".data(using: .utf8)!
        XCTAssertEqual(LineEnding.detect(from: data), .cr,
                       "CR-only line endings should be detected")
    }

    func testBOMStrippingUTF8() {
        let bom = Data([0xEF, 0xBB, 0xBF])
        let text = "Hello"
        let payload = text.data(using: .utf8)!
        let data = bom + payload

        // Use FileIO's internal stripBOM via a write-then-read round-trip,
        // but we can also verify through readFile. Here we test the detection
        // path and ensure the BOM does not corrupt content.
        let encoding = EncodingManager.detectEncoding(from: data)
        XCTAssertEqual(encoding, .utf8)

        // Manually strip BOM the way FileIO does
        let stripped = data.dropFirst(3)
        let decoded = String(data: stripped, encoding: .utf8)
        XCTAssertEqual(decoded, text, "After stripping UTF-8 BOM, content should be intact")
    }

    func testBOMStrippingUTF16LE() {
        let bom = Data([0xFF, 0xFE])
        let text = "Hi"
        let payload = text.data(using: .utf16LittleEndian)!
        let data = bom + payload

        let encoding = EncodingManager.detectEncoding(from: data)
        XCTAssertEqual(encoding, .utf16LittleEndian)

        let stripped = data.dropFirst(2)
        let decoded = String(data: stripped, encoding: .utf16LittleEndian)
        XCTAssertEqual(decoded, text, "After stripping UTF-16 LE BOM, content should be intact")
    }

    func testHasUTF8BOM() {
        let withBOM = Data([0xEF, 0xBB, 0xBF]) + "test".data(using: .utf8)!
        XCTAssertTrue(EncodingManager.hasUTF8BOM(withBOM), "Data with UTF-8 BOM should return true")

        let withoutBOM = "test".data(using: .utf8)!
        XCTAssertFalse(EncodingManager.hasUTF8BOM(withoutBOM), "Data without BOM should return false")

        let tooShort = Data([0xEF, 0xBB])
        XCTAssertFalse(EncodingManager.hasUTF8BOM(tooShort), "Data shorter than 3 bytes should return false")

        let empty = Data()
        XCTAssertFalse(EncodingManager.hasUTF8BOM(empty), "Empty data should return false")
    }

    // MARK: - Extended Encoding Tests

    func testSupportedEncodingsCount() {
        // We should have at least 30 encodings after the expansion
        XCTAssertGreaterThanOrEqual(
            EncodingManager.supportedEncodings.count, 30,
            "Should have at least 30 supported encodings"
        )
    }

    func testAllEncodingNamesMatchSupportedEncodings() {
        let names = EncodingManager.allEncodingNames
        XCTAssertEqual(names.count, EncodingManager.supportedEncodings.count,
                       "allEncodingNames should match supportedEncodings count")
    }

    func testEncodingForName() {
        XCTAssertEqual(EncodingManager.encoding(forName: "UTF-8"), .utf8)
        XCTAssertEqual(EncodingManager.encoding(forName: "ASCII"), .ascii)
        XCTAssertEqual(EncodingManager.encoding(forName: "ISO 8859-1"), .isoLatin1)
        XCTAssertEqual(EncodingManager.encoding(forName: "Windows-1252"), .windowsCP1252)
        XCTAssertNil(EncodingManager.encoding(forName: "NonExistentEncoding"))
    }

    func testWindowsEncodingsExist() {
        // Verify all Windows codepages are available
        let windowsEncodings = [
            "Windows-1250", "Windows-1251", "Windows-1253", "Windows-1254",
            "Windows-1255", "Windows-1256", "Windows-1257", "Windows-1258",
        ]
        for name in windowsEncodings {
            XCTAssertNotNil(
                EncodingManager.encoding(forName: name),
                "\(name) should be available"
            )
        }
    }

    func testISOEncodingsExist() {
        // Verify ISO 8859 encodings are available
        let isoEncodings = [
            "ISO 8859-2", "ISO 8859-3", "ISO 8859-4", "ISO 8859-5",
            "ISO 8859-6", "ISO 8859-7", "ISO 8859-8", "ISO 8859-9",
            "ISO 8859-10", "ISO 8859-13", "ISO 8859-14", "ISO 8859-15",
        ]
        for name in isoEncodings {
            XCTAssertNotNil(
                EncodingManager.encoding(forName: name),
                "\(name) should be available"
            )
        }
    }

    func testDOSEncodingsExist() {
        let dosEncodings = ["DOS 437", "DOS 850", "DOS 866"]
        for name in dosEncodings {
            XCTAssertNotNil(
                EncodingManager.encoding(forName: name),
                "\(name) should be available"
            )
        }
    }

    func testEncodingGroupsContainAllNames() {
        // Every encoding name in a group should exist in supportedEncodings
        for group in EncodingManager.encodingGroups {
            for name in group.encodingNames {
                XCTAssertNotNil(
                    EncodingManager.encoding(forName: name),
                    "Group '\(group.title)' contains '\(name)' which is not in supportedEncodings"
                )
            }
        }
    }

    func testHeuristicDetectionWindows1252() {
        // Bytes 0x80-0x9F are control codes in ISO 8859-1 but printable in Windows-1252
        // Create data with multiple 0x80-0x9F bytes mixed with ASCII
        var bytes: [UInt8] = Array("Hello World ".utf8)
        // Add Windows-1252 specific characters: smart quotes, em-dash, etc.
        bytes.append(contentsOf: [0x93, 0x94, 0x96, 0x97, 0x85, 0x80, 0x93, 0x94])
        bytes.append(contentsOf: Array(" more text".utf8))
        let data = Data(bytes)
        let detected = EncodingManager.detectEncodingHeuristic(from: data)
        XCTAssertEqual(detected, .windowsCP1252,
                       "Data with many 0x80-0x9F bytes should be detected as Windows-1252")
    }

    func testHeuristicDetectionFallbackISO8859() {
        // Data with high bytes only in 0xA0-0xFF range (valid ISO 8859-1)
        var bytes: [UInt8] = Array("Caf".utf8)
        bytes.append(0xE9)  // 'e' with acute accent in ISO 8859-1
        bytes.append(contentsOf: Array(" au lait".utf8))
        let data = Data(bytes)
        let detected = EncodingManager.detectEncodingHeuristic(from: data)
        XCTAssertEqual(detected, .isoLatin1,
                       "Data with bytes only in 0xA0-0xFF should fall back to ISO 8859-1")
    }

    func testRoundTripWindows1250() {
        guard let encoding = EncodingManager.encoding(forName: "Windows-1250") else {
            XCTFail("Windows-1250 should be available")
            return
        }
        // Central European characters
        let text = "Zdroj"
        let encoded = EncodingManager.convert(text: text, to: encoding)
        XCTAssertNotNil(encoded, "Should encode ASCII text in Windows-1250")
        if let data = encoded {
            let decoded = EncodingManager.reinterpret(data: data, as: encoding)
            XCTAssertEqual(decoded, text, "Round-trip through Windows-1250 should preserve text")
        }
    }

    func testRoundTripWindows1251() {
        guard let encoding = EncodingManager.encoding(forName: "Windows-1251") else {
            XCTFail("Windows-1251 should be available")
            return
        }
        // Cyrillic text
        let text = "\u{041F}\u{0440}\u{0438}\u{0432}\u{0435}\u{0442}"  // "Привет"
        let encoded = EncodingManager.convert(text: text, to: encoding)
        XCTAssertNotNil(encoded, "Should encode Cyrillic text in Windows-1251")
        if let data = encoded {
            let decoded = EncodingManager.reinterpret(data: data, as: encoding)
            XCTAssertEqual(decoded, text, "Round-trip through Windows-1251 should preserve Cyrillic text")
        }
    }

    func testRoundTripISO8859_2() {
        guard let encoding = EncodingManager.encoding(forName: "ISO 8859-2") else {
            XCTFail("ISO 8859-2 should be available")
            return
        }
        let text = "Hello"
        let encoded = EncodingManager.convert(text: text, to: encoding)
        XCTAssertNotNil(encoded, "Should encode ASCII text in ISO 8859-2")
        if let data = encoded {
            let decoded = EncodingManager.reinterpret(data: data, as: encoding)
            XCTAssertEqual(decoded, text, "Round-trip through ISO 8859-2 should preserve text")
        }
    }

    func testRoundTripDOS437() {
        guard let encoding = EncodingManager.encoding(forName: "DOS 437") else {
            XCTFail("DOS 437 should be available")
            return
        }
        let text = "Hello DOS"
        let encoded = EncodingManager.convert(text: text, to: encoding)
        XCTAssertNotNil(encoded, "Should encode ASCII text in DOS 437")
        if let data = encoded {
            let decoded = EncodingManager.reinterpret(data: data, as: encoding)
            XCTAssertEqual(decoded, text, "Round-trip through DOS 437 should preserve ASCII text")
        }
    }

    func testReinterpretMethod() {
        let text = "Hello"
        let data = text.data(using: .utf8)!
        let result = EncodingManager.reinterpret(data: data, as: .utf8)
        XCTAssertEqual(result, text, "Reinterpret with same encoding should return same text")

        let asciiResult = EncodingManager.reinterpret(data: data, as: .ascii)
        XCTAssertEqual(asciiResult, text, "ASCII-safe text reinterpreted as ASCII should work")
    }

    func testEncodingNameForAllSupported() {
        // Every supported encoding should have a human-readable name
        for entry in EncodingManager.supportedEncodings {
            let name = EncodingManager.encodingName(entry.encoding)
            XCTAssertFalse(name.isEmpty, "Encoding name should not be empty for \(entry.name)")
        }
    }
}

// MARK: - FileIO Tests

final class FileIOTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileKitTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFileIOWriteAndRead() throws {
        let url = tempDir.appendingPathComponent("roundtrip.txt")
        let original = "Hello, FileIO!\nSecond line."

        try FileIO.writeFile(
            content: original,
            to: url,
            encoding: .utf8,
            lineEnding: .lf
        )

        let result = try FileIO.readFile(at: url)
        XCTAssertEqual(result.content, original, "Round-trip content should match")
        XCTAssertEqual(result.encoding, .utf8, "Encoding should be UTF-8")
        XCTAssertEqual(result.lineEnding, .lf, "Line ending should be LF")
    }

    func testFileIOFileNotFound() {
        let url = tempDir.appendingPathComponent("nonexistent.txt")
        XCTAssertThrowsError(try FileIO.readFile(at: url)) { error in
            guard let fileError = error as? FileIOError else {
                XCTFail("Expected FileIOError, got \(type(of: error))")
                return
            }
            if case .fileNotFound = fileError {
                // expected
            } else {
                XCTFail("Expected .fileNotFound, got \(fileError)")
            }
        }
    }

    func testFileIOLineEndingNormalization() throws {
        let url = tempDir.appendingPathComponent("crlf.txt")
        // Write with CRLF line endings
        let content = "first\nsecond\nthird"
        try FileIO.writeFile(
            content: content,
            to: url,
            encoding: .utf8,
            lineEnding: .crlf
        )

        // Read raw data and verify CRLF is present
        let rawData = try Data(contentsOf: url)
        let rawString = String(data: rawData, encoding: .utf8)!
        XCTAssertTrue(rawString.contains("\r\n"),
                      "Written file should contain CRLF line endings")
        XCTAssertFalse(rawString.replacingOccurrences(of: "\r\n", with: "").contains("\n"),
                       "There should be no bare LF after removing CRLFs")
    }

    func testFileIOAtomicWrite() throws {
        let url = tempDir.appendingPathComponent("atomic.txt")
        let content = "Atomic write test content."

        // Write with atomic = true (the default)
        try FileIO.writeFile(
            content: content,
            to: url,
            encoding: .utf8,
            lineEnding: .lf,
            atomic: true
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                       "File should exist after atomic write")

        let result = try FileIO.readFile(at: url)
        XCTAssertEqual(result.content, content, "Atomic write content should match")

        // Write with atomic = false
        let url2 = tempDir.appendingPathComponent("non-atomic.txt")
        try FileIO.writeFile(
            content: content,
            to: url2,
            encoding: .utf8,
            lineEnding: .lf,
            atomic: false
        )

        let result2 = try FileIO.readFile(at: url2)
        XCTAssertEqual(result2.content, content, "Non-atomic write content should also match")
    }
}

// MARK: - SessionManager Tests

final class SessionManagerTests: XCTestCase {

    func testSessionDataCodableRoundTrip() throws {
        let tab1 = SessionData.TabState(
            filePath: "/tmp/file1.txt",
            cursorPosition: 42,
            scrollOffset: 100.5,
            isActive: true
        )
        let tab2 = SessionData.TabState(
            filePath: "/tmp/file2.swift",
            cursorPosition: 0,
            scrollOffset: 0.0,
            isActive: false
        )
        let session = SessionData(tabs: [tab1, tab2], windowFrame: "{{0, 0}, {800, 600}}")

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(SessionData.self, from: encoded)

        XCTAssertEqual(decoded.tabs.count, 2)
        XCTAssertEqual(decoded.tabs[0].filePath, "/tmp/file1.txt")
        XCTAssertEqual(decoded.tabs[0].cursorPosition, 42)
        XCTAssertEqual(decoded.tabs[0].scrollOffset, 100.5)
        XCTAssertTrue(decoded.tabs[0].isActive)
        XCTAssertEqual(decoded.tabs[1].filePath, "/tmp/file2.swift")
        XCTAssertFalse(decoded.tabs[1].isActive)
        XCTAssertEqual(decoded.windowFrame, "{{0, 0}, {800, 600}}")
    }

    func testSessionManagerSaveAndLoad() {
        let manager = SessionManager.shared
        let tab = SessionData.TabState(
            filePath: "/tmp/session-test.txt",
            cursorPosition: 10,
            scrollOffset: 50.0,
            isActive: true
        )
        let session = SessionData(tabs: [tab], windowFrame: "{{100, 100}, {1024, 768}}")

        manager.saveSession(session)

        let loaded = manager.loadSession()
        XCTAssertNotNil(loaded, "Session should be loadable after save")
        XCTAssertEqual(loaded?.tabs.count, 1)
        XCTAssertEqual(loaded?.tabs.first?.filePath, "/tmp/session-test.txt")
        XCTAssertEqual(loaded?.windowFrame, "{{100, 100}, {1024, 768}}")
    }

    func testSessionManagerClearSession() {
        let manager = SessionManager.shared
        let tab = SessionData.TabState(
            filePath: "/tmp/clear-test.txt",
            cursorPosition: 0,
            scrollOffset: 0,
            isActive: true
        )
        let session = SessionData(tabs: [tab], windowFrame: "frame")

        manager.saveSession(session)
        XCTAssertNotNil(manager.loadSession(), "Session should exist before clear")

        manager.clearSession()
        XCTAssertNil(manager.loadSession(), "Session should be nil after clear")
    }

    // MARK: - Enhanced TabState Tests

    func testTabStateWithNewFieldsRoundTrip() throws {
        let tab = SessionData.TabState(
            filePath: "/tmp/enhanced.swift",
            cursorPosition: 100,
            scrollOffset: 250.5,
            isActive: true,
            collapsedLines: [5, 12, 30],
            bookmarkedLines: [1, 10, 20],
            colorTag: 3,
            encodingName: "UTF-8",
            lineEndingRaw: "LF"
        )
        let session = SessionData(tabs: [tab], windowFrame: "{{0, 0}, {1200, 800}}")

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(SessionData.self, from: encoded)

        XCTAssertEqual(decoded.tabs.count, 1)
        let decodedTab = decoded.tabs[0]
        XCTAssertEqual(decodedTab.filePath, "/tmp/enhanced.swift")
        XCTAssertEqual(decodedTab.cursorPosition, 100)
        XCTAssertEqual(decodedTab.scrollOffset, 250.5)
        XCTAssertTrue(decodedTab.isActive)
        XCTAssertEqual(decodedTab.collapsedLines, [5, 12, 30])
        XCTAssertEqual(decodedTab.bookmarkedLines, [1, 10, 20])
        XCTAssertEqual(decodedTab.colorTag, 3)
        XCTAssertEqual(decodedTab.encodingName, "UTF-8")
        XCTAssertEqual(decodedTab.lineEndingRaw, "LF")
    }

    func testTabStateBackwardCompatibility() throws {
        // Simulate old JSON without new fields
        let oldJSON = """
        {
            "tabs": [
                {
                    "filePath": "/tmp/old-format.txt",
                    "cursorPosition": 5,
                    "scrollOffset": 0.0,
                    "isActive": false
                }
            ],
            "windowFrame": "{{0, 0}, {800, 600}}"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SessionData.self, from: oldJSON)

        XCTAssertEqual(decoded.tabs.count, 1)
        let tab = decoded.tabs[0]
        XCTAssertEqual(tab.filePath, "/tmp/old-format.txt")
        XCTAssertEqual(tab.cursorPosition, 5)
        XCTAssertFalse(tab.isActive)
        XCTAssertNil(tab.collapsedLines, "Old format should decode collapsedLines as nil")
        XCTAssertNil(tab.bookmarkedLines, "Old format should decode bookmarkedLines as nil")
        XCTAssertNil(tab.colorTag, "Old format should decode colorTag as nil")
        XCTAssertNil(tab.encodingName, "Old format should decode encodingName as nil")
        XCTAssertNil(tab.lineEndingRaw, "Old format should decode lineEndingRaw as nil")
    }

    func testTabStateWithNilNewFields() throws {
        // TabState created with default nil values for new fields
        let tab = SessionData.TabState(
            filePath: "/tmp/defaults.txt",
            cursorPosition: 0,
            scrollOffset: 0.0,
            isActive: true
        )

        let encoded = try JSONEncoder().encode(tab)
        let decoded = try JSONDecoder().decode(SessionData.TabState.self, from: encoded)

        XCTAssertEqual(decoded.filePath, "/tmp/defaults.txt")
        XCTAssertNil(decoded.collapsedLines)
        XCTAssertNil(decoded.bookmarkedLines)
        XCTAssertNil(decoded.colorTag)
        XCTAssertNil(decoded.encodingName)
        XCTAssertNil(decoded.lineEndingRaw)
    }

    func testSessionSaveAndLoadWithBookmarksAndFolds() {
        let manager = SessionManager.shared
        let tab = SessionData.TabState(
            filePath: "/tmp/full-session.swift",
            cursorPosition: 42,
            scrollOffset: 120.0,
            isActive: true,
            collapsedLines: [3, 15, 28],
            bookmarkedLines: [5, 10],
            colorTag: 2
        )
        let session = SessionData(tabs: [tab], windowFrame: "{{50, 50}, {1024, 768}}")

        manager.saveSession(session)

        let loaded = manager.loadSession()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.tabs.count, 1)

        let loadedTab = loaded?.tabs.first
        XCTAssertEqual(loadedTab?.collapsedLines, [3, 15, 28])
        XCTAssertEqual(loadedTab?.bookmarkedLines, [5, 10])
        XCTAssertEqual(loadedTab?.colorTag, 2)
        XCTAssertNil(loadedTab?.encodingName)
        XCTAssertNil(loadedTab?.lineEndingRaw)

        // Cleanup
        manager.clearSession()
    }

    func testMixedTabsWithAndWithoutNewFields() throws {
        let tab1 = SessionData.TabState(
            filePath: "/tmp/with-extras.swift",
            cursorPosition: 10,
            scrollOffset: 0.0,
            isActive: true,
            collapsedLines: [1, 2],
            bookmarkedLines: [5],
            colorTag: 4,
            encodingName: "UTF-16",
            lineEndingRaw: "CRLF"
        )
        let tab2 = SessionData.TabState(
            filePath: "/tmp/without-extras.txt",
            cursorPosition: 0,
            scrollOffset: 0.0,
            isActive: false
        )
        let session = SessionData(tabs: [tab1, tab2], windowFrame: "frame")

        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(SessionData.self, from: encoded)

        XCTAssertEqual(decoded.tabs.count, 2)

        // First tab has all extras
        XCTAssertEqual(decoded.tabs[0].collapsedLines, [1, 2])
        XCTAssertEqual(decoded.tabs[0].bookmarkedLines, [5])
        XCTAssertEqual(decoded.tabs[0].colorTag, 4)
        XCTAssertEqual(decoded.tabs[0].encodingName, "UTF-16")
        XCTAssertEqual(decoded.tabs[0].lineEndingRaw, "CRLF")

        // Second tab has no extras
        XCTAssertNil(decoded.tabs[1].collapsedLines)
        XCTAssertNil(decoded.tabs[1].bookmarkedLines)
        XCTAssertNil(decoded.tabs[1].colorTag)
        XCTAssertNil(decoded.tabs[1].encodingName)
        XCTAssertNil(decoded.tabs[1].lineEndingRaw)
    }
}

// MARK: - AutoSaveManager Tests

final class AutoSaveManagerTests: XCTestCase {

    func testAutoSaveManagerDefaults() {
        let manager = AutoSaveManager()
        XCTAssertEqual(manager.interval, 30, "Default interval should be 30 seconds")
        XCTAssertTrue(manager.isEnabled, "Auto-save should be enabled by default")
        XCTAssertNil(manager.onAutoSave, "Callback should be nil by default")
    }

    func testAutoSaveManagerEnableDisable() {
        let manager = AutoSaveManager()
        XCTAssertTrue(manager.isEnabled)

        manager.isEnabled = false
        XCTAssertFalse(manager.isEnabled, "Should be disabled after setting to false")

        manager.isEnabled = true
        XCTAssertTrue(manager.isEnabled, "Should be re-enabled after setting to true")
    }

    func testAutoSaveManagerCallback() {
        let manager = AutoSaveManager()
        var callbackCount = 0

        manager.onAutoSave = {
            callbackCount += 1
        }

        // Manually trigger save (simulates timer fire)
        manager.triggerSave()
        XCTAssertEqual(callbackCount, 1, "Callback should be invoked once after triggerSave")

        manager.triggerSave()
        manager.triggerSave()
        XCTAssertEqual(callbackCount, 3, "Callback should be invoked on every triggerSave call")

        // Ensure nil callback does not crash
        manager.onAutoSave = nil
        manager.triggerSave() // should not crash
        XCTAssertEqual(callbackCount, 3, "Count should not change after removing callback")
    }
}
