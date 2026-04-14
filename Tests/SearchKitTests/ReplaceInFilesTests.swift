import XCTest
@testable import SearchKit
import CommonKit

final class ReplaceInFilesTests: XCTestCase {

    private var tempDir: URL!
    private let finder = FindInFiles()

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReplaceInFilesTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Helpers

    /// Resolves symlinks in a URL so comparisons work on macOS
    /// (/var -> /private/var).
    private func resolved(_ url: URL) -> URL {
        return url.resolvingSymlinksInPath()
    }

    /// Creates a text file in the temp directory and returns its resolved URL.
    @discardableResult
    private func createFile(name: String, content: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        // Create intermediate directories if the name contains path components.
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try! content.data(using: .utf8)!.write(to: url)
        return resolved(url)
    }

    /// Reads the content of a file as UTF-8.
    private func readFile(_ url: URL) -> String {
        return try! String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Basic Replacement

    func testBasicReplacement() {
        let file = createFile(name: "hello.txt", content: "hello world hello")
        let results = finder.replaceInFiles(
            pattern: "hello",
            replacement: "hi",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(resolved(results[0].fileURL), file)
        XCTAssertEqual(results[0].replacementCount, 2)
        XCTAssertEqual(readFile(file), "hi world hi")
    }

    // MARK: - Multiple Files

    func testMultipleFilesReplacement() {
        let fileA = createFile(name: "a.txt", content: "foo bar foo")
        let fileB = createFile(name: "b.txt", content: "foo baz")
        createFile(name: "c.txt", content: "no match here")

        let results = finder.replaceInFiles(
            pattern: "foo",
            replacement: "qux",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        // Only files with matches should appear in results.
        let modifiedURLs = Set(results.map { resolved($0.fileURL) })
        XCTAssertTrue(modifiedURLs.contains(fileA))
        XCTAssertTrue(modifiedURLs.contains(fileB))
        XCTAssertEqual(results.count, 2)

        XCTAssertEqual(readFile(fileA), "qux bar qux")
        XCTAssertEqual(readFile(fileB), "qux baz")
    }

    // MARK: - File Glob Filtering

    func testFileGlobFilter() {
        createFile(name: "code.swift", content: "let x = foo")
        let txtFile = createFile(name: "notes.txt", content: "foo notes")

        let results = finder.replaceInFiles(
            pattern: "foo",
            replacement: "bar",
            in: tempDir,
            fileGlob: "*.txt",
            options: SearchOptions()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(resolved(results[0].fileURL), txtFile)
        XCTAssertEqual(readFile(txtFile), "bar notes")
    }

    // MARK: - No Matches

    func testNoMatches() {
        createFile(name: "a.txt", content: "hello world")

        let results = finder.replaceInFiles(
            pattern: "xyz",
            replacement: "abc",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        XCTAssertTrue(results.isEmpty, "No matches should return empty results")
    }

    // MARK: - Case Sensitive

    func testCaseSensitiveReplacement() {
        let file = createFile(name: "case.txt", content: "Hello hello HELLO")
        let options = SearchOptions(caseSensitive: true)
        let results = finder.replaceInFiles(
            pattern: "Hello",
            replacement: "Hi",
            in: tempDir,
            fileGlob: nil,
            options: options
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].replacementCount, 1)
        XCTAssertEqual(readFile(file), "Hi hello HELLO")
    }

    // MARK: - Regex Replacement

    func testRegexReplacement() {
        let file = createFile(name: "regex.txt", content: "abc 123 def 456")
        let options = SearchOptions(useRegex: true)
        let results = finder.replaceInFiles(
            pattern: "\\d+",
            replacement: "NUM",
            in: tempDir,
            fileGlob: nil,
            options: options
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].replacementCount, 2)
        XCTAssertEqual(readFile(file), "abc NUM def NUM")
    }

    // MARK: - Replacement Counts

    func testReplacementCountsAreAccurate() {
        createFile(name: "many.txt", content: "aaa aaa aaa aaa aaa")
        let results = finder.replaceInFiles(
            pattern: "aaa",
            replacement: "b",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].replacementCount, 5)
    }

    // MARK: - Skips Hidden Directories

    func testSkipsGitDirectory() {
        // Create a .git directory with a file inside — it should be skipped
        // because the enumerator uses .skipsHiddenFiles.
        let gitDir = tempDir.appendingPathComponent(".git")
        try? FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)
        let gitFile = gitDir.appendingPathComponent("config.txt")
        try? "foo".data(using: .utf8)!.write(to: gitFile)

        createFile(name: "visible.txt", content: "foo bar")

        let results = finder.replaceInFiles(
            pattern: "foo",
            replacement: "baz",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        // Only visible.txt should be modified.
        XCTAssertEqual(results.count, 1)
        // .git/config.txt should be untouched.
        XCTAssertEqual(try! String(contentsOf: gitFile, encoding: .utf8), "foo")
    }

    // MARK: - Empty Replacement

    func testEmptyReplacementDeletesPattern() {
        let file = createFile(name: "delete.txt", content: "remove THIS text")
        let results = finder.replaceInFiles(
            pattern: "THIS ",
            replacement: "",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(readFile(file), "remove text")
    }

    // MARK: - Atomic Write Preserves Content on No Match

    func testUnchangedFilesAreNotWritten() {
        let file = createFile(name: "safe.txt", content: "keep this safe")
        let modBefore = try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date

        // Small sleep so modification date would differ if file were written.
        Thread.sleep(forTimeInterval: 0.05)

        let results = finder.replaceInFiles(
            pattern: "notfound",
            replacement: "x",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        XCTAssertTrue(results.isEmpty)

        let modAfter = try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        XCTAssertEqual(modBefore, modAfter, "File should not be written when there are no matches")
    }

    // MARK: - Subdirectories

    func testSearchesSubdirectories() {
        createFile(name: "sub/deep.txt", content: "foo deep")
        let results = finder.replaceInFiles(
            pattern: "foo",
            replacement: "bar",
            in: tempDir,
            fileGlob: nil,
            options: SearchOptions()
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].replacementCount, 1)
    }
}
