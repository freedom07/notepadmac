import Foundation

/// Parsed command-line arguments for NotepadNext.
public struct CLIArguments {
    /// File paths to open.
    public var files: [String] = []
    /// Go-to line number (from `-l` or `--line`).
    public var goToLine: Int? = nil
    /// Open files in read-only mode (`--read-only`).
    public var readOnly: Bool = false

    /// Parse command-line arguments (excluding the program name).
    public static func parse(_ args: [String]) -> CLIArguments {
        var result = CLIArguments()
        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-l", "--line":
                i += 1
                if i < args.count, let line = Int(args[i]) {
                    result.goToLine = line
                }
            case "--read-only":
                result.readOnly = true
            default:
                if !arg.hasPrefix("-") {
                    result.files.append(arg)
                }
            }
            i += 1
        }
        return result
    }
}
