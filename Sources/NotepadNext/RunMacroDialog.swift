import AppKit
import NotepadNextCore

/// A dialog panel that lets the user select a saved macro and run it
/// a specified number of times, or until the end of the file.
@available(macOS 13.0, *)
final class RunMacroDialog {

    private var panel: NSPanel?

    /// The callback invoked when the user presses Run.
    /// Parameters: selected macro, repeat count (nil means "until end of file").
    var onRun: ((Macro, Int?) -> Void)?

    func showDialog(relativeTo window: NSWindow?) {
        let macros = MacroManager.shared.savedMacros
        guard !macros.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No Macros Available"
            alert.informativeText = "Record a macro first before running."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Run Macro Multiple Times"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        self.panel = panel

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Macro selector label
        let selectorLabel = NSTextField(labelWithString: "Macro:")
        selectorLabel.frame = NSRect(x: 20, y: 140, width: 60, height: 20)
        contentView.addSubview(selectorLabel)

        // Macro popup button
        let macroPopup = NSPopUpButton(frame: NSRect(x: 90, y: 137, width: 250, height: 26), pullsDown: false)
        for macro in macros {
            macroPopup.addItem(withTitle: macro.name)
        }
        contentView.addSubview(macroPopup)

        // Times label
        let timesLabel = NSTextField(labelWithString: "Times:")
        timesLabel.frame = NSRect(x: 20, y: 105, width: 60, height: 20)
        contentView.addSubview(timesLabel)

        // Times text field
        let timesField = NSTextField(frame: NSRect(x: 90, y: 102, width: 100, height: 24))
        timesField.stringValue = "1"
        timesField.placeholderString = "1"
        contentView.addSubview(timesField)

        // Run until end of file checkbox
        let endOfFileCheckbox = NSButton(checkboxWithTitle: "Run until end of file", target: nil, action: nil)
        endOfFileCheckbox.frame = NSRect(x: 90, y: 70, width: 200, height: 20)
        contentView.addSubview(endOfFileCheckbox)

        // Run button
        let runButton = NSButton(title: "Run", target: nil, action: nil)
        runButton.frame = NSRect(x: 250, y: 20, width: 90, height: 32)
        runButton.bezelStyle = .rounded
        runButton.keyEquivalent = "\r"
        contentView.addSubview(runButton)

        // Cancel button
        let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
        cancelButton.frame = NSRect(x: 150, y: 20, width: 90, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        // Action handlers
        runButton.target = self
        runButton.action = #selector(runButtonClicked(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked(_:))

        // Store references for action handler
        objc_setAssociatedObject(self, &AssociatedKeys.macroPopup, macroPopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.timesField, timesField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &AssociatedKeys.endOfFileCheckbox, endOfFileCheckbox, .OBJC_ASSOCIATION_RETAIN)

        panel.contentView = contentView

        if let window = window {
            window.beginSheet(panel)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func runButtonClicked(_ sender: Any) {
        guard let macroPopup = objc_getAssociatedObject(self, &AssociatedKeys.macroPopup) as? NSPopUpButton,
              let timesField = objc_getAssociatedObject(self, &AssociatedKeys.timesField) as? NSTextField,
              let endOfFileCheckbox = objc_getAssociatedObject(self, &AssociatedKeys.endOfFileCheckbox) as? NSButton
        else { return }

        let macros = MacroManager.shared.savedMacros
        let selectedIndex = macroPopup.indexOfSelectedItem
        guard macros.indices.contains(selectedIndex) else { return }
        let macro = macros[selectedIndex]

        let times: Int?
        if endOfFileCheckbox.state == .on {
            times = nil
        } else {
            times = Int(timesField.stringValue) ?? 1
        }

        dismissPanel()
        onRun?(macro, times)
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

private struct AssociatedKeys {
    static var macroPopup: UInt8 = 0
    static var timesField: UInt8 = 0
    static var endOfFileCheckbox: UInt8 = 0
}
