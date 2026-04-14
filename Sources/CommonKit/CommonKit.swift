import Foundation

/// Shared constants and utilities used across all NotepadNext modules.
public enum CommonKit {
    public static let appName = "NotepadMac"
    public static let defaultEncoding: String.Encoding = .utf8
    public static let defaultTabWidth = 4
}

/// Notification names used across the application.
public extension Notification.Name {
    static let documentDidChange = Notification.Name("com.notepadmac.documentDidChange")
    static let cursorDidMove = Notification.Name("com.notepadmac.cursorDidMove")
    static let tabDidChange = Notification.Name("com.notepadmac.tabDidChange")
}
