import AppKit
import NotepadNextCore

if #available(macOS 13.0, *) {
    let app = NSApplication.shared
    let delegate = AppDelegate()

    // Parse CLI arguments (skip argv[0] which is the program path)
    let cliArgs = CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))
    delegate.cliArguments = cliArgs

    app.delegate = delegate
    // Use withExtendedLifetime to prevent ARC from releasing the delegate
    // (NSApplication.delegate is weak)
    withExtendedLifetime(delegate) {
        app.run()
    }
} else {
    fatalError("NotepadMac requires macOS 13.0 or later.")
}
