import AppKit
import EditorKit

/// A dialog panel for inserting columnar text or sequential numbers
/// at the cursor column across multiple lines.
@available(macOS 13.0, *)
final class ColumnEditorController {

    private var panel: NSPanel?

    /// Callback invoked when the user inserts text in text mode.
    var onInsertText: ((String) -> Void)?

    /// Callback invoked when the user inserts numbers in number mode.
    /// Parameters: start, step, radix, leadingZeros, uppercase.
    var onInsertNumbers: ((Int, Int, Int, Bool, Bool) -> Void)?

    func showDialog(relativeTo window: NSWindow?) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Column Editor"
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        self.panel = panel

        let contentView = NSView(frame: panel.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // --- Mode selector ---
        let modeLabel = NSTextField(labelWithString: "Mode:")
        modeLabel.frame = NSRect(x: 20, y: 280, width: 50, height: 20)
        contentView.addSubview(modeLabel)

        let modeSegment = NSSegmentedControl(labels: ["Text", "Number"], trackingMode: .selectOne, target: nil, action: nil)
        modeSegment.frame = NSRect(x: 80, y: 277, width: 200, height: 26)
        modeSegment.selectedSegment = 0
        contentView.addSubview(modeSegment)

        // --- Text mode controls ---
        let textLabel = NSTextField(labelWithString: "Text to insert:")
        textLabel.frame = NSRect(x: 20, y: 240, width: 120, height: 20)
        contentView.addSubview(textLabel)

        let textField = NSTextField(frame: NSRect(x: 20, y: 210, width: 360, height: 24))
        textField.placeholderString = "Enter text to insert at cursor column"
        contentView.addSubview(textField)

        // --- Number mode controls ---
        let startLabel = NSTextField(labelWithString: "Start:")
        startLabel.frame = NSRect(x: 20, y: 170, width: 60, height: 20)
        contentView.addSubview(startLabel)

        let startField = NSTextField(frame: NSRect(x: 90, y: 167, width: 80, height: 24))
        startField.stringValue = "1"
        contentView.addSubview(startField)

        let stepLabel = NSTextField(labelWithString: "Step:")
        stepLabel.frame = NSRect(x: 190, y: 170, width: 50, height: 20)
        contentView.addSubview(stepLabel)

        let stepField = NSTextField(frame: NSRect(x: 250, y: 167, width: 80, height: 24))
        stepField.stringValue = "1"
        contentView.addSubview(stepField)

        let baseLabel = NSTextField(labelWithString: "Base:")
        baseLabel.frame = NSRect(x: 20, y: 130, width: 60, height: 20)
        contentView.addSubview(baseLabel)

        let basePopup = NSPopUpButton(frame: NSRect(x: 90, y: 127, width: 120, height: 26), pullsDown: false)
        basePopup.addItems(withTitles: ["Decimal", "Hexadecimal", "Octal", "Binary"])
        contentView.addSubview(basePopup)

        let leadingZerosCheckbox = NSButton(checkboxWithTitle: "Leading zeros", target: nil, action: nil)
        leadingZerosCheckbox.frame = NSRect(x: 20, y: 95, width: 160, height: 20)
        contentView.addSubview(leadingZerosCheckbox)

        let uppercaseCheckbox = NSButton(checkboxWithTitle: "Uppercase (hex)", target: nil, action: nil)
        uppercaseCheckbox.frame = NSRect(x: 200, y: 95, width: 180, height: 20)
        contentView.addSubview(uppercaseCheckbox)

        // Initially hide number controls
        let numberControls: [NSView] = [startLabel, startField, stepLabel, stepField, baseLabel, basePopup, leadingZerosCheckbox, uppercaseCheckbox]
        for ctrl in numberControls {
            ctrl.isHidden = true
        }

        // --- Buttons ---
        let insertButton = NSButton(title: "Insert", target: nil, action: nil)
        insertButton.frame = NSRect(x: 290, y: 20, width: 90, height: 32)
        insertButton.bezelStyle = .rounded
        insertButton.keyEquivalent = "\r"
        contentView.addSubview(insertButton)

        let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
        cancelButton.frame = NSRect(x: 190, y: 20, width: 90, height: 32)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        // --- Mode switching ---
        modeSegment.target = self
        modeSegment.action = #selector(modeChanged(_:))

        // Action handlers
        insertButton.target = self
        insertButton.action = #selector(insertButtonClicked(_:))
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked(_:))

        // Store references via associated objects
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.modeSegment, modeSegment, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.textField, textField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.textLabel, textLabel, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.startField, startField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.stepField, stepField, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.basePopup, basePopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.leadingZerosCheckbox, leadingZerosCheckbox, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.uppercaseCheckbox, uppercaseCheckbox, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(self, &ColumnAssociatedKeys.numberControls, numberControls, .OBJC_ASSOCIATION_RETAIN)

        panel.contentView = contentView

        if let window = window {
            window.beginSheet(panel)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func modeChanged(_ sender: NSSegmentedControl) {
        let isNumberMode = sender.selectedSegment == 1

        if let textField = objc_getAssociatedObject(self, &ColumnAssociatedKeys.textField) as? NSTextField,
           let textLabel = objc_getAssociatedObject(self, &ColumnAssociatedKeys.textLabel) as? NSTextField {
            textField.isHidden = isNumberMode
            textLabel.isHidden = isNumberMode
        }

        if let numberControls = objc_getAssociatedObject(self, &ColumnAssociatedKeys.numberControls) as? [NSView] {
            for ctrl in numberControls {
                ctrl.isHidden = !isNumberMode
            }
        }
    }

    @objc private func insertButtonClicked(_ sender: Any) {
        guard let modeSegment = objc_getAssociatedObject(self, &ColumnAssociatedKeys.modeSegment) as? NSSegmentedControl else { return }

        if modeSegment.selectedSegment == 0 {
            // Text mode
            guard let textField = objc_getAssociatedObject(self, &ColumnAssociatedKeys.textField) as? NSTextField else { return }
            let text = textField.stringValue
            guard !text.isEmpty else {
                dismissPanel()
                return
            }
            dismissPanel()
            onInsertText?(text)
        } else {
            // Number mode
            guard let startField = objc_getAssociatedObject(self, &ColumnAssociatedKeys.startField) as? NSTextField,
                  let stepField = objc_getAssociatedObject(self, &ColumnAssociatedKeys.stepField) as? NSTextField,
                  let basePopup = objc_getAssociatedObject(self, &ColumnAssociatedKeys.basePopup) as? NSPopUpButton,
                  let leadingZerosCheckbox = objc_getAssociatedObject(self, &ColumnAssociatedKeys.leadingZerosCheckbox) as? NSButton,
                  let uppercaseCheckbox = objc_getAssociatedObject(self, &ColumnAssociatedKeys.uppercaseCheckbox) as? NSButton
            else { return }

            let start = Int(startField.stringValue) ?? 1
            let step = Int(stepField.stringValue) ?? 1
            let radix: Int
            switch basePopup.indexOfSelectedItem {
            case 1: radix = 16
            case 2: radix = 8
            case 3: radix = 2
            default: radix = 10
            }
            let leadingZeros = leadingZerosCheckbox.state == .on
            let uppercase = uppercaseCheckbox.state == .on

            dismissPanel()
            onInsertNumbers?(start, step, radix, leadingZeros, uppercase)
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

private struct ColumnAssociatedKeys {
    static var modeSegment: UInt8 = 0
    static var textField: UInt8 = 0
    static var textLabel: UInt8 = 0
    static var startField: UInt8 = 0
    static var stepField: UInt8 = 0
    static var basePopup: UInt8 = 0
    static var leadingZerosCheckbox: UInt8 = 0
    static var uppercaseCheckbox: UInt8 = 0
    static var numberControls: UInt8 = 0
}
