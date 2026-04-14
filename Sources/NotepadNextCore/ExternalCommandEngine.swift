import Foundation

// MARK: - ExternalCommand

/// A named shell command that can be saved and executed.
public struct ExternalCommand: Codable, Equatable {
    public let name: String
    public let command: String

    public init(name: String, command: String) {
        self.name = name
        self.command = command
    }
}

// MARK: - ExternalCommandEngine

/// Pure-logic engine for variable substitution and command execution.
/// UI-free so it can be tested from NotepadNextCore tests.
public final class ExternalCommandEngine {

    /// Context values used during variable substitution.
    public struct VariableContext {
        public var filePath: String?
        public var fileName: String?
        public var fileDir: String?
        public var currentWord: String?
        public var currentLine: String?

        public init(
            filePath: String? = nil,
            fileName: String? = nil,
            fileDir: String? = nil,
            currentWord: String? = nil,
            currentLine: String? = nil
        ) {
            self.filePath = filePath
            self.fileName = fileName
            self.fileDir = fileDir
            self.currentWord = currentWord
            self.currentLine = currentLine
        }
    }

    public init() {}

    /// Escapes a string for safe inclusion in a shell command.
    private func shellEscape(_ value: String) -> String {
        // Replace single quotes with '\'' (end quote, escaped quote, start quote)
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Substitutes supported variables in the given command string.
    /// Variable values are shell-escaped to prevent command injection.
    ///
    /// Supported variables:
    /// - `$(FILE_PATH)` - full path of the current file
    /// - `$(FILE_NAME)` - name of the current file
    /// - `$(FILE_DIR)` - directory containing the current file
    /// - `$(CURRENT_WORD)` - word under the cursor
    /// - `$(CURRENT_LINE)` - text of the current line
    public func substituteVariables(in command: String, context: VariableContext) -> String {
        var result = command
        result = result.replacingOccurrences(of: "$(FILE_PATH)", with: shellEscape(context.filePath ?? ""))
        result = result.replacingOccurrences(of: "$(FILE_NAME)", with: shellEscape(context.fileName ?? ""))
        result = result.replacingOccurrences(of: "$(FILE_DIR)", with: shellEscape(context.fileDir ?? ""))
        result = result.replacingOccurrences(of: "$(CURRENT_WORD)", with: shellEscape(context.currentWord ?? ""))
        result = result.replacingOccurrences(of: "$(CURRENT_LINE)", with: shellEscape(context.currentLine ?? ""))
        return result
    }

    /// Executes the given command string via `/bin/zsh -c` and returns the combined stdout/stderr output.
    public func executeCommand(_ command: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return "Error launching command: \(error.localizedDescription)"
        }

        // Read pipe data BEFORE waitUntilExit to prevent deadlock.
        // If the pipe buffer fills up, the child process blocks on write,
        // and waitUntilExit would never return.
        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        if errStr.isEmpty {
            return outStr
        }
        return outStr + (outStr.isEmpty ? "" : "\n") + errStr
    }
}
