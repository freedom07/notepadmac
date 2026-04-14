import Foundation

// MARK: - StatusBarDelegate

/// Delegate protocol for responding to status bar item clicks.
/// Defined in NotepadNextCore so it can be tested independently.
public protocol StatusBarDelegate: AnyObject {
    func statusBarDidChangeEncoding(_ encoding: String)
    func statusBarDidChangeLineEnding(_ ending: String)
    func statusBarDidChangeLanguage(_ language: String)
    func statusBarDidChangeIndentation(_ indentation: String)
}
