import Foundation
import CommonKit

public struct SessionData: Codable {
    public struct TabState: Codable {
        public let filePath: String
        public let cursorPosition: Int
        public let scrollOffset: Double
        public let isActive: Bool
        // New optional fields (backward compatible with existing JSON)
        public let collapsedLines: [Int]?
        public let bookmarkedLines: [Int]?
        public let colorTag: Int?
        public let encodingName: String?
        public let lineEndingRaw: String?

        public init(filePath: String, cursorPosition: Int, scrollOffset: Double, isActive: Bool,
                    collapsedLines: [Int]? = nil, bookmarkedLines: [Int]? = nil,
                    colorTag: Int? = nil, encodingName: String? = nil, lineEndingRaw: String? = nil) {
            self.filePath = filePath
            self.cursorPosition = cursorPosition
            self.scrollOffset = scrollOffset
            self.isActive = isActive
            self.collapsedLines = collapsedLines
            self.bookmarkedLines = bookmarkedLines
            self.colorTag = colorTag
            self.encodingName = encodingName
            self.lineEndingRaw = lineEndingRaw
        }
    }
    public let tabs: [TabState]; public let windowFrame: String
    public init(tabs: [TabState], windowFrame: String) { self.tabs = tabs; self.windowFrame = windowFrame }
}

public class SessionManager {
    public static let shared = SessionManager()
    private let sessionURL: URL
    private init() { let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("NotepadMac"); try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true); sessionURL = d.appendingPathComponent("session.json") }
    public func saveSession(_ data: SessionData) { if let d = try? JSONEncoder().encode(data) { try? d.write(to: sessionURL, options: .atomic) } }
    public func loadSession() -> SessionData? { guard let d = try? Data(contentsOf: sessionURL) else { return nil }; return try? JSONDecoder().decode(SessionData.self, from: d) }
    public func clearSession() { try? FileManager.default.removeItem(at: sessionURL) }
}
