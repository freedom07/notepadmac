import Foundation
import CommonKit

public class BookmarkManager {
    public private(set) var bookmarkedLines: Set<Int> = []
    public init() {}
    public func toggleBookmark(at line: Int) { if bookmarkedLines.contains(line) { bookmarkedLines.remove(line) } else { bookmarkedLines.insert(line) } }
    public func nextBookmark(after line: Int) -> Int? { let s = sortedBookmarks; return s.first(where: { $0 > line }) ?? s.first }
    public func previousBookmark(before line: Int) -> Int? { let s = sortedBookmarks; return s.last(where: { $0 < line }) ?? s.last }
    public func clearAllBookmarks() { bookmarkedLines.removeAll() }
    public var hasBookmarks: Bool { !bookmarkedLines.isEmpty }
    public var sortedBookmarks: [Int] { bookmarkedLines.sorted() }
}
