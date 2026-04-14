import AppKit
import NotepadNextCore

// MARK: - ExternalCommandController

/// Controller that provides a panel for composing and running external shell commands
/// with variable substitution support.
@available(macOS 13.0, *)
final class ExternalCommandController {

    /// Callback to retrieve the current file path from the editor.
    var currentFilePath: (() -> URL?)?
    /// Callback to retrieve the current word under the cursor.
    var currentWord: (() -> String?)?
    /// Callback to retrieve the current line text.
    var currentLine: (() -> String?)?
    /// Callback invoked with the command output to display in a new document.
    var onCommandOutput: ((String) -> Void)?

    private let engine = ExternalCommandEngine()
    private var panel: NSPanel?

    func showDialog(relativeTo window: NSWindow?) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Run External Command"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.minSize = NSSize(width: 400, height: 250)
        self.panel = panel

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Command label
        let commandLabel = NSTextField(labelWithString: "Command:")
        commandLabel.frame = NSRect(x: 20, y: 240, width: 80, height: 20)
        contentView.addSubview(commandLabel)

        // Command text field (multi-line via scroll view)
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 120, width: 460, height: 110))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let commandTextView = NSTextView(frame: scrollView.contentView.bounds)
        commandTextView.autoresizingMask = [.width, .height]
        commandTextView.isEditable = true
        commandTextView.isSelectable = true
        commandTextView.isRichText = false
        commandTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        commandTextView.isVerticallyResizable = true
        commandTextView.isHorizontallyResizable = false
        commandTextView.textContainer?.widthTracksTextView = true
        scrollView.documentView = commandTextView
        contentView.addSubview(scrollView)

        // Variable buttons row
        let variableLabel = NSTextField(labelWithString: "Variables:")
        variableLabel.frame = NSRect(x: 20, y: 90, width: 70, height: 20)
        contentView.addSubview(variableLabel)

        let variables = ["$(FILE_PATH)", "$(FILE_NAME)", "$(FILE_DIR)", "$(CURRENT_WORD)", "$(CURRENT_LINE)"]
        var xOffset: CGFloat = 95
        for variable in variables {
            let button = NSButton(title: variable, target: self, action: #selector(insertVariable(_:)))
            button.bezelStyle = .inline
            let width = max(90, CGFloat(variable.count) * 8 + 16)
            button.frame = NSRect(x: xOffset, y: 87, width: width, height: 24)
            button.font = NSFont.systemFont(ofSize: 10)
            button.tag = variables.firstIndex(of: variable) ?? 0
            contentView.addSubview(button)
            xOffset += width + 4
        }

        // Run button
        let runButton = NSButton(title: "Run", target: self, action: #selector(runButtonClicked(_:)))
        runButton.frame = NSRect(x: 390, y: 20, width: 90, height: 32)
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"
        contentView.addSubview(runButton)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelButtonClicked(_:)))
        cancelButton.frame = NSRect(x: 290, y: 20, width: 90, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        // Store text view reference
        objc_setAssociatedObject(self, &CommandAssociatedKeys.commandTextView, commandTextView, .OBJC_ASSOCIATION_RETAIN)

        panel.contentView = contentView

        if let window = window {
            window.beginSheet(panel)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Actions

    @objc private func insertVariable(_ sender: NSButton) {
        guard let textView = objc_getAssociatedObject(self, &CommandAssociatedKeys.commandTextView) as? NSTextView else { return }
        let variables = ["$(FILE_PATH)", "$(FILE_NAME)", "$(FILE_DIR)", "$(CURRENT_WORD)", "$(CURRENT_LINE)"]
        let index = sender.tag
        guard variables.indices.contains(index) else { return }
        textView.insertText(variables[index], replacementRange: textView.selectedRange())
    }

    @objc private func runButtonClicked(_ sender: Any) {
        guard let textView = objc_getAssociatedObject(self, &CommandAssociatedKeys.commandTextView) as? NSTextView else { return }
        let rawCommand = textView.string
        guard !rawCommand.isEmpty else { return }

        let filePath = currentFilePath?()
        let context = ExternalCommandEngine.VariableContext(
            filePath: filePath?.path,
            fileName: filePath?.lastPathComponent,
            fileDir: filePath?.deletingLastPathComponent().path,
            currentWord: currentWord?(),
            currentLine: currentLine?()
        )
        let substituted = engine.substituteVariables(in: rawCommand, context: context)
        dismissPanel()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.engine.executeCommand(substituted)
            DispatchQueue.main.async {
                self.onCommandOutput?(output)
            }
        }
    }

    @objc private func cancelButtonClicked(_ sender: Any) {
        dismissPanel()
    }

    private func dismissPanel() {
        if let panel = panel, let sheetParent = panel.sheetParent {
            sheetParent.endSheet(panel)
        } else {
            panel?.close()
        }
        panel = nil
    }
}

private struct CommandAssociatedKeys {
    static var commandTextView: UInt8 = 0
}
