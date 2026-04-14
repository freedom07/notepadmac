import AppKit
import CommonKit

// MARK: - MacroAction

/// Describes a single atomic editing operation that can be recorded and replayed.
public enum MacroAction: Codable, Equatable {
    case insertText(String)
    case deleteCharacters(Int)
    case moveCursorBy(Int)
    case findReplace(pattern: String, replacement: String)
    case executeCommand(commandId: String)

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case count
        case offset
        case pattern
        case replacement
        case commandId
    }

    private enum ActionType: String, Codable {
        case insertText
        case deleteCharacters
        case moveCursorBy
        case findReplace
        case executeCommand
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .insertText(let text):
            try container.encode(ActionType.insertText, forKey: .type)
            try container.encode(text, forKey: .text)
        case .deleteCharacters(let count):
            try container.encode(ActionType.deleteCharacters, forKey: .type)
            try container.encode(count, forKey: .count)
        case .moveCursorBy(let offset):
            try container.encode(ActionType.moveCursorBy, forKey: .type)
            try container.encode(offset, forKey: .offset)
        case .findReplace(let pattern, let replacement):
            try container.encode(ActionType.findReplace, forKey: .type)
            try container.encode(pattern, forKey: .pattern)
            try container.encode(replacement, forKey: .replacement)
        case .executeCommand(let commandId):
            try container.encode(ActionType.executeCommand, forKey: .type)
            try container.encode(commandId, forKey: .commandId)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let actionType = try container.decode(ActionType.self, forKey: .type)
        switch actionType {
        case .insertText:
            let text = try container.decode(String.self, forKey: .text)
            self = .insertText(text)
        case .deleteCharacters:
            let count = try container.decode(Int.self, forKey: .count)
            self = .deleteCharacters(count)
        case .moveCursorBy:
            let offset = try container.decode(Int.self, forKey: .offset)
            self = .moveCursorBy(offset)
        case .findReplace:
            let pattern = try container.decode(String.self, forKey: .pattern)
            let replacement = try container.decode(String.self, forKey: .replacement)
            self = .findReplace(pattern: pattern, replacement: replacement)
        case .executeCommand:
            let commandId = try container.decode(String.self, forKey: .commandId)
            self = .executeCommand(commandId: commandId)
        }
    }
}

// MARK: - Macro

/// A named sequence of macro actions with a creation timestamp.
public struct Macro: Codable, Equatable {
    public let name: String
    public let actions: [MacroAction]
    public let createdAt: Date

    public init(name: String, actions: [MacroAction], createdAt: Date = Date()) {
        self.name = name
        self.actions = actions
        self.createdAt = createdAt
    }
}

// MARK: - MacroRecorder

/// Records user editing actions into a sequence that can later be replayed.
public final class MacroRecorder {

    /// `true` while a recording session is active.
    public private(set) var isRecording: Bool = false

    /// Actions captured during the current recording session.
    public private(set) var currentActions: [MacroAction] = []

    public init() {}

    /// Begins a new recording session, discarding any previously captured actions.
    public func startRecording() {
        currentActions = []
        isRecording = true
    }

    /// Ends the current recording session and returns the captured macro.
    @discardableResult
    public func stopRecording() -> Macro {
        isRecording = false
        let macro = Macro(
            name: "Recording \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))",
            actions: currentActions,
            createdAt: Date()
        )
        currentActions = []
        return macro
    }

    /// Appends an action to the current recording. Has no effect when not recording.
    public func recordAction(_ action: MacroAction) {
        guard isRecording else { return }
        currentActions.append(action)
    }
}

// MARK: - MacroManager

/// Manages a library of saved macros and handles playback into an `NSTextView`.
public final class MacroManager {

    /// Shared singleton instance.
    public static let shared = MacroManager()

    /// All macros the user has saved.
    public private(set) var savedMacros: [Macro] = []

    /// URL to the macros persistence file.
    private let macrosFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("NotepadMac")
        macrosFileURL = appDir.appendingPathComponent("macros.json")
    }

    // MARK: - Persistence

    /// Saves the current `savedMacros` array to `~/Library/Application Support/NotepadNext/macros.json`.
    public func saveMacros() {
        let dir = macrosFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(savedMacros) {
            try? data.write(to: macrosFileURL, options: .atomic)
        }
    }

    /// Loads macros from `~/Library/Application Support/NotepadNext/macros.json`.
    public func loadMacros() {
        guard let data = try? Data(contentsOf: macrosFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode([Macro].self, from: data) {
            savedMacros = loaded
        }
    }

    // MARK: - Library Management

    /// Adds a macro to the saved library.
    public func saveMacro(_ macro: Macro) {
        savedMacros.append(macro)
    }

    /// Removes a macro at the given index.
    public func deleteMacro(at index: Int) {
        guard savedMacros.indices.contains(index) else { return }
        savedMacros.remove(at: index)
    }

    // MARK: - Playback

    /// Plays every action in the macro once against the provided text view.
    public func playMacro(_ macro: Macro, in textView: NSTextView) {
        textView.undoManager?.beginUndoGrouping()
        for action in macro.actions {
            execute(action, in: textView)
        }
        textView.undoManager?.endUndoGrouping()
    }

    /// Replays a macro the specified number of times.
    public func playMacroMultipleTimes(_ macro: Macro, times: Int, in textView: NSTextView) {
        guard times > 0 else { return }
        textView.undoManager?.beginUndoGrouping()
        for _ in 0..<times {
            for action in macro.actions {
                execute(action, in: textView)
            }
        }
        textView.undoManager?.endUndoGrouping()
    }

    // MARK: - Action Execution

    private func execute(_ action: MacroAction, in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()

        switch action {
        case .insertText(let text):
            textStorage.replaceCharacters(in: selectedRange, with: text)
            let newLocation = selectedRange.location + (text as NSString).length
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        case .deleteCharacters(let count):
            let deleteStart = max(0, selectedRange.location - count)
            let deleteLength = selectedRange.location - deleteStart
            if deleteLength > 0 {
                let deleteRange = NSRange(location: deleteStart, length: deleteLength)
                textStorage.replaceCharacters(in: deleteRange, with: "")
                textView.setSelectedRange(NSRange(location: deleteStart, length: 0))
            }

        case .moveCursorBy(let offset):
            let newLocation = max(0, min(textStorage.length, selectedRange.location + offset))
            textView.setSelectedRange(NSRange(location: newLocation, length: 0))

        case .findReplace(let pattern, let replacement):
            let fullText = textStorage.string
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            let fullRange = NSRange(location: 0, length: (fullText as NSString).length)
            let matches = regex.matches(in: fullText, options: [], range: fullRange)
            // Replace in reverse order to preserve ranges
            for match in matches.reversed() {
                textStorage.replaceCharacters(in: match.range, with: replacement)
            }

        case .executeCommand(let commandId):
            // Post a notification so the app layer can handle the command
            NotificationCenter.default.post(
                name: .macroExecuteCommand,
                object: nil,
                userInfo: ["commandId": commandId]
            )
        }
    }

    // MARK: - Testing Support

    /// Replaces the persisted macros file URL for testing. Exposed for unit tests only.
    internal func _setSavedMacros(_ macros: [Macro]) {
        savedMacros = macros
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let macroExecuteCommand = Notification.Name("com.notepadnext.macroExecuteCommand")
}
