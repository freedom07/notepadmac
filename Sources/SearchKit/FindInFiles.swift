import Foundation
import CommonKit

public struct FileSearchResult: Sendable {
    public let fileURL: URL
    public let matches: [SearchResult]
    public init(fileURL: URL, matches: [SearchResult]) { self.fileURL = fileURL; self.matches = matches }
}

/// Result of replacing text in a single file.
public struct ReplaceInFilesResult: Sendable {
    /// The file that was modified.
    public let fileURL: URL
    /// The number of replacements made in this file.
    public let replacementCount: Int

    public init(fileURL: URL, replacementCount: Int) {
        self.fileURL = fileURL
        self.replacementCount = replacementCount
    }
}

public class FindInFiles {
    private let engine = SearchEngine()
    private let skipDirs: Set<String> = [".git", "node_modules", ".build", "DerivedData"]
    public init() {}

    // MARK: - File Enumeration

    /// Enumerates text files in `directory`, applying `fileGlob` filtering and
    /// skipping common non-source directories. Returns file URLs paired with
    /// their UTF-8 content.
    private func enumerateFiles(
        in directory: URL,
        fileGlob: String?
    ) -> [(url: URL, content: String)] {
        var files: [(url: URL, content: String)] = []
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            if skipDirs.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            if let glob = fileGlob {
                let ext = glob.replacingOccurrences(of: "*.", with: "")
                if url.pathExtension != ext { continue }
            }
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
                  let content = String(data: data, encoding: .utf8) else { continue }
            files.append((url: url, content: content))
        }
        return files
    }

    // MARK: - Search

    public func search(pattern: String, in directory: URL, fileGlob: String?, options: SearchOptions) -> [FileSearchResult] {
        var results: [FileSearchResult] = []
        for file in enumerateFiles(in: directory, fileGlob: fileGlob) {
            let m = engine.find(pattern: pattern, in: file.content, options: options)
            if !m.isEmpty { results.append(FileSearchResult(fileURL: file.url, matches: m)) }
        }
        return results
    }

    // MARK: - Replace in Files

    /// Replaces all occurrences of `pattern` with `replacement` across files in
    /// `directory`.
    ///
    /// Files are read as UTF-8. Only files that actually contain matches are
    /// written back. Writes are always atomic to prevent data loss.
    ///
    /// - Parameters:
    ///   - pattern: The search pattern (plain text or regex depending on `options`).
    ///   - replacement: The replacement string.
    ///   - directory: The root directory to search within.
    ///   - fileGlob: Optional glob pattern to filter files (e.g. `"*.swift"`).
    ///   - options: Search options controlling match behavior.
    /// - Returns: An array of ``ReplaceInFilesResult`` for every file that was
    ///   modified, including the number of replacements in each.
    public func replaceInFiles(
        pattern: String,
        replacement: String,
        in directory: URL,
        fileGlob: String?,
        options: SearchOptions
    ) -> [ReplaceInFilesResult] {
        var results: [ReplaceInFilesResult] = []

        for file in enumerateFiles(in: directory, fileGlob: fileGlob) {
            let replaced = engine.replaceAll(
                in: file.content,
                pattern: pattern,
                replacement: replacement,
                options: options
            )

            guard replaced.count > 0 else { continue }

            // Write back atomically to prevent data loss.
            guard let data = replaced.newText.data(using: .utf8) else { continue }
            do {
                try data.write(to: file.url, options: [.atomic])
                results.append(ReplaceInFilesResult(
                    fileURL: file.url,
                    replacementCount: replaced.count
                ))
            } catch {
                // Skip files that cannot be written (e.g. read-only).
                continue
            }
        }

        return results
    }
}
