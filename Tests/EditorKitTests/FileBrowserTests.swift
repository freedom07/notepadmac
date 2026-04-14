import XCTest
@testable import EditorKit

final class FileBrowserTests: XCTestCase {

    // MARK: - FileSystemItem Skip Patterns

    func testSkipPatternsContainsExpectedEntries() {
        let expected: Set<String> = [".git", "node_modules", ".build", "DerivedData", ".DS_Store"]
        XCTAssertEqual(FileSystemItem.skipPatterns, expected)
    }

    func testShouldSkipReturnsTrueForSkippedNames() {
        XCTAssertTrue(FileSystemItem.shouldSkip(".git"))
        XCTAssertTrue(FileSystemItem.shouldSkip("node_modules"))
        XCTAssertTrue(FileSystemItem.shouldSkip(".build"))
        XCTAssertTrue(FileSystemItem.shouldSkip("DerivedData"))
        XCTAssertTrue(FileSystemItem.shouldSkip(".DS_Store"))
    }

    func testShouldSkipReturnsFalseForNormalNames() {
        XCTAssertFalse(FileSystemItem.shouldSkip("Sources"))
        XCTAssertFalse(FileSystemItem.shouldSkip("main.swift"))
        XCTAssertFalse(FileSystemItem.shouldSkip("README.md"))
        XCTAssertFalse(FileSystemItem.shouldSkip("Package.swift"))
    }

    // MARK: - FileSystemItem Initialization

    func testInitWithDirectoryURL() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        XCTAssertTrue(item.isDirectory)
        XCTAssertEqual(item.name, tmpDir.lastPathComponent)
        XCTAssertEqual(item.url, tmpDir)
    }

    func testInitWithFileURL() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let fileURL = tmpDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: "hello".data(using: .utf8))
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: fileURL)
        XCTAssertFalse(item.isDirectory)
        XCTAssertEqual(item.name, "test.txt")
    }

    func testInitWithExplicitDirectoryFlag() {
        let url = URL(fileURLWithPath: "/tmp/fake-dir")
        let item = FileSystemItem(url: url, isDirectory: true)
        XCTAssertTrue(item.isDirectory)

        let fileItem = FileSystemItem(url: url, isDirectory: false)
        XCTAssertFalse(fileItem.isDirectory)
    }

    // MARK: - Children Loading

    func testChildrenLoadedLazilyForDirectory() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let fileA = tmpDir.appendingPathComponent("alpha.txt")
        let fileB = tmpDir.appendingPathComponent("beta.txt")
        FileManager.default.createFile(atPath: fileA.path, contents: Data())
        FileManager.default.createFile(atPath: fileB.path, contents: Data())

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        let children = item.children
        XCTAssertEqual(children.count, 2)
        // Children should be sorted alphabetically
        XCTAssertEqual(children[0].name, "alpha.txt")
        XCTAssertEqual(children[1].name, "beta.txt")
    }

    func testChildrenReturnsEmptyForFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let fileURL = tmpDir.appendingPathComponent("test.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: fileURL)
        XCTAssertEqual(item.children.count, 0)
        XCTAssertEqual(item.numberOfChildren, 0)
    }

    func testSkippedDirectoriesAreExcluded() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        // Create a normal file and a skipped directory
        let normalFile = tmpDir.appendingPathComponent("main.swift")
        FileManager.default.createFile(atPath: normalFile.path, contents: Data())

        let gitDir = tmpDir.appendingPathComponent(".git")
        try FileManager.default.createDirectory(at: gitDir, withIntermediateDirectories: true)

        let nodeModules = tmpDir.appendingPathComponent("node_modules")
        try FileManager.default.createDirectory(at: nodeModules, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        let childNames = item.children.map(\.name)
        XCTAssertTrue(childNames.contains("main.swift"))
        XCTAssertFalse(childNames.contains(".git"))
        XCTAssertFalse(childNames.contains("node_modules"))
    }

    func testDirectoriesSortedBeforeFiles() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let file = tmpDir.appendingPathComponent("aaa_file.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        let dir = tmpDir.appendingPathComponent("zzz_dir")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        let children = item.children
        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children[0].isDirectory, "Directories should come before files")
        XCTAssertFalse(children[1].isDirectory, "Files should come after directories")
    }

    func testReloadChildrenRefreshesContent() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let file = tmpDir.appendingPathComponent("initial.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        XCTAssertEqual(item.children.count, 1)

        // Add another file
        let newFile = tmpDir.appendingPathComponent("added.txt")
        FileManager.default.createFile(atPath: newFile.path, contents: Data())

        // Children should still be cached
        XCTAssertEqual(item.children.count, 1)

        // After reload, the new file should appear
        item.reloadChildren()
        XCTAssertEqual(item.children.count, 2)
    }

    func testNumberOfChildrenMatchesChildrenCount() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let fileA = tmpDir.appendingPathComponent("a.txt")
        let fileB = tmpDir.appendingPathComponent("b.txt")
        let fileC = tmpDir.appendingPathComponent("c.txt")
        for f in [fileA, fileB, fileC] {
            FileManager.default.createFile(atPath: f.path, contents: Data())
        }

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        XCTAssertEqual(item.numberOfChildren, item.children.count)
        XCTAssertEqual(item.numberOfChildren, 3)
    }

    func testEmptyDirectoryHasNoChildren() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        XCTAssertEqual(item.children.count, 0)
        XCTAssertEqual(item.numberOfChildren, 0)
    }

    func testDSStoreIsSkipped() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBrowserTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let dsStore = tmpDir.appendingPathComponent(".DS_Store")
        FileManager.default.createFile(atPath: dsStore.path, contents: Data())

        let normalFile = tmpDir.appendingPathComponent("hello.swift")
        FileManager.default.createFile(atPath: normalFile.path, contents: Data())

        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let item = FileSystemItem(url: tmpDir)
        let childNames = item.children.map(\.name)
        XCTAssertFalse(childNames.contains(".DS_Store"))
        XCTAssertTrue(childNames.contains("hello.swift"))
    }
}
