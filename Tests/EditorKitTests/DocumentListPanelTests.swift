import XCTest
@testable import EditorKit

final class DocumentListPanelTests: XCTestCase {

    // MARK: - DocumentEntry Tests

    func testDocumentEntryInitialization() {
        let entry = DocumentEntry(
            filename: "main.swift",
            path: "/Users/test/project/main.swift",
            isModified: true,
            language: "Swift"
        )
        XCTAssertEqual(entry.filename, "main.swift")
        XCTAssertEqual(entry.path, "/Users/test/project/main.swift")
        XCTAssertTrue(entry.isModified)
        XCTAssertEqual(entry.language, "Swift")
    }

    func testDocumentEntryEquality() {
        let a = DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text")
        let b = DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text")
        let c = DocumentEntry(filename: "b.txt", path: "/b.txt", isModified: true, language: "Python")
        XCTAssertEqual(a, b, "Identical entries should be equal")
        XCTAssertNotEqual(a, c, "Different entries should not be equal")
    }

    func testDocumentEntryModifiedDifference() {
        let unmodified = DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text")
        let modified = DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: true, language: "Text")
        XCTAssertNotEqual(unmodified, modified, "Different modified states should make entries unequal")
    }

    // MARK: - DocumentListPanel Data Model Tests

    @available(macOS 13.0, *)
    func testPanelEntriesStorage() {
        let panel = DocumentListPanel()
        // Force view load
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "main.swift", path: "/project/main.swift", isModified: false, language: "Swift"),
            DocumentEntry(filename: "README.md", path: "/project/README.md", isModified: true, language: "Markdown"),
            DocumentEntry(filename: "test.py", path: "/project/test.py", isModified: false, language: "Python"),
        ]

        panel.entries = entries
        XCTAssertEqual(panel.entries.count, 3)
        XCTAssertEqual(panel.displayedEntries.count, 3, "Displayed entries should match input when unsorted")
    }

    @available(macOS 13.0, *)
    func testPanelSortByFilename() {
        let panel = DocumentListPanel()
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "zebra.txt", path: "/zebra.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "alpha.txt", path: "/alpha.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "middle.txt", path: "/middle.txt", isModified: false, language: "Text"),
        ]

        panel.entries = entries
        panel.sortColumn = "FilenameColumn"
        panel.sortAscending = true
        panel.applySort()

        XCTAssertEqual(panel.displayedEntries[0].filename, "alpha.txt")
        XCTAssertEqual(panel.displayedEntries[1].filename, "middle.txt")
        XCTAssertEqual(panel.displayedEntries[2].filename, "zebra.txt")
    }

    @available(macOS 13.0, *)
    func testPanelSortByFilenameDescending() {
        let panel = DocumentListPanel()
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "alpha.txt", path: "/alpha.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "zebra.txt", path: "/zebra.txt", isModified: false, language: "Text"),
        ]

        panel.entries = entries
        panel.sortColumn = "FilenameColumn"
        panel.sortAscending = false
        panel.applySort()

        XCTAssertEqual(panel.displayedEntries[0].filename, "zebra.txt")
        XCTAssertEqual(panel.displayedEntries[1].filename, "alpha.txt")
    }

    @available(macOS 13.0, *)
    func testPanelSortByLanguage() {
        let panel = DocumentListPanel()
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "a.py", path: "/a.py", isModified: false, language: "Python"),
            DocumentEntry(filename: "b.swift", path: "/b.swift", isModified: false, language: "Swift"),
            DocumentEntry(filename: "c.md", path: "/c.md", isModified: false, language: "Markdown"),
        ]

        panel.entries = entries
        panel.sortColumn = "LanguageColumn"
        panel.sortAscending = true
        panel.applySort()

        XCTAssertEqual(panel.displayedEntries[0].language, "Markdown")
        XCTAssertEqual(panel.displayedEntries[1].language, "Python")
        XCTAssertEqual(panel.displayedEntries[2].language, "Swift")
    }

    @available(macOS 13.0, *)
    func testPanelSortByPath() {
        let panel = DocumentListPanel()
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "b.txt", path: "/z/b.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "a.txt", path: "/a/a.txt", isModified: false, language: "Text"),
        ]

        panel.entries = entries
        panel.sortColumn = "PathColumn"
        panel.sortAscending = true
        panel.applySort()

        XCTAssertEqual(panel.displayedEntries[0].path, "/a/a.txt")
        XCTAssertEqual(panel.displayedEntries[1].path, "/z/b.txt")
    }

    @available(macOS 13.0, *)
    func testPanelEmptyEntries() {
        let panel = DocumentListPanel()
        _ = panel.view

        panel.entries = []
        XCTAssertEqual(panel.displayedEntries.count, 0)
    }

    @available(macOS 13.0, *)
    func testPanelRefreshReloads() {
        let panel = DocumentListPanel()
        _ = panel.view

        panel.entries = [
            DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text"),
        ]
        XCTAssertEqual(panel.displayedEntries.count, 1)

        panel.entries = [
            DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "b.txt", path: "/b.txt", isModified: true, language: "Text"),
        ]
        XCTAssertEqual(panel.displayedEntries.count, 2)
    }

    @available(macOS 13.0, *)
    func testPanelNoSortPreservesOrder() {
        let panel = DocumentListPanel()
        _ = panel.view

        let entries = [
            DocumentEntry(filename: "c.txt", path: "/c.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "a.txt", path: "/a.txt", isModified: false, language: "Text"),
            DocumentEntry(filename: "b.txt", path: "/b.txt", isModified: false, language: "Text"),
        ]

        panel.sortColumn = nil
        panel.entries = entries

        XCTAssertEqual(panel.displayedEntries[0].filename, "c.txt", "Without sorting, original order should be preserved")
        XCTAssertEqual(panel.displayedEntries[1].filename, "a.txt")
        XCTAssertEqual(panel.displayedEntries[2].filename, "b.txt")
    }
}
