import Foundation
import CommonKit

// MARK: - UserDefault Property Wrapper

/// A property wrapper that reads and writes values to `UserDefaults`.
@propertyWrapper
public struct UserDefault<Value> {
    public let key: String
    public let defaultValue: Value
    public let store: UserDefaults

    public init(_ key: String, defaultValue: Value, store: UserDefaults = .standard) {
        self.key = "NotepadMac.\(key)"
        self.defaultValue = defaultValue
        self.store = store
    }

    public var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

// MARK: - Preferences

/// Centralized, persistent application preferences.
/// Access via `Preferences.shared`. All keys are prefixed with `NotepadNext.`.
public final class Preferences {

    public static let shared = Preferences()

    /// Posted whenever any preference changes.
    public static let didChangeNotification = Notification.Name("NotepadMac.PreferencesDidChange")

    private init() {}

    // MARK: - Editor

    @UserDefault("editor.tabWidth", defaultValue: 4)
    public var tabWidth: Int

    @UserDefault("editor.usesSpaces", defaultValue: true)
    public var usesSpaces: Bool

    @UserDefault("editor.showLineNumbers", defaultValue: true)
    public var showLineNumbers: Bool

    @UserDefault("editor.wordWrap", defaultValue: false)
    public var wordWrap: Bool

    @UserDefault("editor.showIndentGuides", defaultValue: true)
    public var showIndentGuides: Bool

    @UserDefault("editor.autoCloseBrackets", defaultValue: true)
    public var autoCloseBrackets: Bool

    @UserDefault("editor.smartHighlight", defaultValue: true)
    public var smartHighlight: Bool

    @UserDefault("editor.showMinimap", defaultValue: false)
    public var showMinimap: Bool

    @UserDefault("editor.edgeColumn", defaultValue: 80)
    public var edgeColumn: Int

    @UserDefault("editor.showEdgeColumn", defaultValue: false)
    public var showEdgeColumn: Bool

    // MARK: - Appearance

    @UserDefault("appearance.themeName", defaultValue: "One Dark")
    public var themeName: String

    @UserDefault("appearance.fontSize", defaultValue: 13.0)
    public var fontSize: Double

    @UserDefault("appearance.lineHeight", defaultValue: 1.5)
    public var lineHeight: Double

    @UserDefault("appearance.followSystemAppearance", defaultValue: true)
    public var followSystemAppearance: Bool

    // MARK: - Files

    @UserDefault("files.defaultEncoding", defaultValue: "UTF-8")
    public var defaultEncoding: String

    @UserDefault("files.defaultLineEnding", defaultValue: "LF")
    public var defaultLineEnding: String

    @UserDefault("files.trimTrailingWhitespaceOnSave", defaultValue: false)
    public var trimTrailingWhitespaceOnSave: Bool

    @UserDefault("files.autoSaveEnabled", defaultValue: true)
    public var autoSaveEnabled: Bool

    @UserDefault("files.autoSaveInterval", defaultValue: 30.0)
    public var autoSaveInterval: Double

    @UserDefault("files.rememberSession", defaultValue: true)
    public var rememberSession: Bool

    @UserDefault("files.showHiddenFiles", defaultValue: false)
    public var showHiddenFiles: Bool

    // MARK: - Search

    @UserDefault("search.caseSensitive", defaultValue: false)
    public var searchCaseSensitive: Bool

    @UserDefault("search.wholeWord", defaultValue: false)
    public var searchWholeWord: Bool

    @UserDefault("search.wrapAround", defaultValue: true)
    public var searchWrapAround: Bool

    @UserDefault("search.historySize", defaultValue: 20)
    public var searchHistorySize: Int

    // MARK: - Panels

    @UserDefault("panels.showFileBrowser", defaultValue: false)
    public var showFileBrowser: Bool

    @UserDefault("panels.showFunctionList", defaultValue: false)
    public var showFunctionList: Bool

    @UserDefault("panels.leftPanelWidth", defaultValue: 250.0)
    public var leftPanelWidth: Double

    @UserDefault("panels.bottomPanelHeight", defaultValue: 200.0)
    public var bottomPanelHeight: Double

    // MARK: - General

    @UserDefault("general.openEmptyDocumentOnStartup", defaultValue: true)
    public var openEmptyDocumentOnStartup: Bool

    @UserDefault("general.recentFilesCount", defaultValue: 20)
    public var recentFilesCount: Int

    // MARK: - Notify

    /// Call after changing preferences to notify observers.
    public func notifyChange() {
        NotificationCenter.default.post(name: Preferences.didChangeNotification, object: self)
    }

    // MARK: - Reset

    /// Removes all NotepadNext preferences, restoring defaults.
    public func resetAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("NotepadMac.") {
            defaults.removeObject(forKey: key)
        }
        notifyChange()
    }
}
