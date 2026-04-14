import AppKit
import CommonKit

public class GoToLineController: NSWindowController {
    private let lineNumberField = NSTextField()
    public var onGoToLine: ((Int) -> Void)?
    public convenience init() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 80), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Go to Line"; panel.isFloatingPanel = true
        self.init(window: panel)
        lineNumberField.placeholderString = "Line number..."; lineNumberField.frame = NSRect(x: 16, y: 30, width: 200, height: 28)
        lineNumberField.target = self; lineNumberField.action = #selector(go)
        panel.contentView!.addSubview(lineNumberField)
        let btn = NSButton(title: "Go", target: self, action: #selector(go)); btn.frame = NSRect(x: 224, y: 30, width: 60, height: 28)
        panel.contentView!.addSubview(btn)
    }
    public func showDialog() { window?.center(); window?.makeKeyAndOrderFront(nil); lineNumberField.stringValue = ""; lineNumberField.becomeFirstResponder() }
    @objc private func go() { guard let n = Int(lineNumberField.stringValue), n > 0 else { return }; onGoToLine?(n); window?.close() }
}
