import XCTest
@testable import EditorKit

final class ClipboardHistoryPanelTests: XCTestCase {

    // MARK: - ClipboardEntry Tests

    func testClipboardEntryPreviewShortText() {
        let entry = ClipboardEntry(text: "Hello, world!")
        XCTAssertEqual(entry.preview, "Hello, world!")
    }

    func testClipboardEntryPreviewTruncation() {
        let longText = String(repeating: "x", count: 150)
        let entry = ClipboardEntry(text: longText)
        XCTAssertTrue(entry.preview.hasSuffix("\u{2026}"), "Long text preview should end with ellipsis")
        // 100 chars + 1 ellipsis = 101
        XCTAssertEqual(entry.preview.count, 101, "Preview should be 100 chars + ellipsis")
    }

    func testClipboardEntryPreviewNewlines() {
        let entry = ClipboardEntry(text: "line1\nline2\nline3")
        XCTAssertFalse(entry.preview.contains("\n"), "Preview should replace newlines with spaces")
        XCTAssertEqual(entry.preview, "line1 line2 line3")
    }

    func testClipboardEntryPreviewExactly100() {
        let text = String(repeating: "a", count: 100)
        let entry = ClipboardEntry(text: text)
        XCTAssertEqual(entry.preview, text, "Exactly 100 chars should not be truncated")
        XCTAssertFalse(entry.preview.hasSuffix("\u{2026}"))
    }

    func testClipboardEntryEquality() {
        let a = ClipboardEntry(text: "hello")
        let b = ClipboardEntry(text: "hello")
        // Entries with same text should be equal (timestamps may differ, but text matters)
        XCTAssertEqual(a.text, b.text)
    }

    // MARK: - ClipboardHistoryStorage Tests

    func testStorageAddEntry() {
        let storage = ClipboardHistoryStorage()
        let added = storage.addEntry("Hello")
        XCTAssertTrue(added)
        XCTAssertEqual(storage.entries.count, 1)
        XCTAssertEqual(storage.entries[0].text, "Hello")
    }

    func testStorageNewestFirst() {
        let storage = ClipboardHistoryStorage()
        storage.addEntry("First")
        storage.addEntry("Second")
        storage.addEntry("Third")
        XCTAssertEqual(storage.entries[0].text, "Third", "Newest entry should be first")
        XCTAssertEqual(storage.entries[1].text, "Second")
        XCTAssertEqual(storage.entries[2].text, "First")
    }

    func testStorageMaxEntries() {
        let storage = ClipboardHistoryStorage(maxEntries: 5)
        for i in 0..<10 {
            storage.addEntry("Entry \(i)")
        }
        XCTAssertEqual(storage.entries.count, 5, "Storage should cap at maxEntries")
        XCTAssertEqual(storage.entries[0].text, "Entry 9", "Most recent entry should be first")
        XCTAssertEqual(storage.entries[4].text, "Entry 5", "Oldest kept entry should be last")
    }

    func testStorageDefaultMaxEntries() {
        let storage = ClipboardHistoryStorage()
        XCTAssertEqual(storage.maxEntries, 50, "Default max should be 50")
    }

    func testStorageRejectsDuplicateOfMostRecent() {
        let storage = ClipboardHistoryStorage()
        storage.addEntry("Same")
        let added = storage.addEntry("Same")
        XCTAssertFalse(added, "Should not add duplicate of the most recent entry")
        XCTAssertEqual(storage.entries.count, 1)
    }

    func testStorageAllowsDuplicateOfOlderEntry() {
        let storage = ClipboardHistoryStorage()
        storage.addEntry("First")
        storage.addEntry("Second")
        let added = storage.addEntry("First")
        XCTAssertTrue(added, "Should allow re-adding text that is not the most recent")
        XCTAssertEqual(storage.entries.count, 3)
        XCTAssertEqual(storage.entries[0].text, "First")
    }

    func testStorageRejectsEmptyString() {
        let storage = ClipboardHistoryStorage()
        let added = storage.addEntry("")
        XCTAssertFalse(added, "Should not add empty strings")
        XCTAssertEqual(storage.entries.count, 0)
    }

    func testStorageClear() {
        let storage = ClipboardHistoryStorage()
        storage.addEntry("A")
        storage.addEntry("B")
        storage.addEntry("C")
        XCTAssertEqual(storage.entries.count, 3)

        storage.clear()
        XCTAssertEqual(storage.entries.count, 0, "Clear should remove all entries")
    }

    func testStorageClearThenAdd() {
        let storage = ClipboardHistoryStorage()
        storage.addEntry("A")
        storage.clear()
        let added = storage.addEntry("A")
        XCTAssertTrue(added, "After clear, previously-duplicate entry should be accepted")
        XCTAssertEqual(storage.entries.count, 1)
    }

    func testStorageMaxEntriesOfOne() {
        let storage = ClipboardHistoryStorage(maxEntries: 1)
        storage.addEntry("First")
        storage.addEntry("Second")
        XCTAssertEqual(storage.entries.count, 1)
        XCTAssertEqual(storage.entries[0].text, "Second")
    }

    // MARK: - ClipboardHistoryPanel Tests

    @available(macOS 13.0, *)
    func testPanelStorageIntegration() {
        let storage = ClipboardHistoryStorage()
        let panel = ClipboardHistoryPanel(storage: storage)
        _ = panel.view

        storage.addEntry("Test content")
        XCTAssertEqual(panel.storage.entries.count, 1)
        XCTAssertEqual(panel.storage.entries[0].text, "Test content")
    }

    @available(macOS 13.0, *)
    func testPanelUsesProvidedStorage() {
        let storage = ClipboardHistoryStorage(maxEntries: 10)
        storage.addEntry("Pre-existing")

        let panel = ClipboardHistoryPanel(storage: storage)
        _ = panel.view

        XCTAssertEqual(panel.storage.entries.count, 1)
        XCTAssertEqual(panel.storage.maxEntries, 10)
    }
}
