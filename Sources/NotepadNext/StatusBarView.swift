import AppKit
import CommonKit
import FileKit
import NotepadNextCore

// MARK: - StatusBarViewDelegate

/// Delegate protocol for responding to status bar item clicks.
protocol StatusBarViewDelegate: AnyObject {
    func statusBar(_ bar: StatusBarView, didChangeEncoding encoding: String)
    func statusBar(_ bar: StatusBarView, didChangeLineEnding ending: String)
    func statusBar(_ bar: StatusBarView, didChangeLanguage language: String)
    func statusBar(_ bar: StatusBarView, didChangeIndentation indentation: String)
}

// MARK: - StatusBarView

/// A status bar view displayed at the bottom of the editor window.
/// Shows cursor position, encoding, line ending, language, and indentation info.
/// Each field (except position) is clickable and presents a popup for changing the value.
final class StatusBarView: NSView {

    var line: Int = 1
    var column: Int = 1
    var encoding: String = "UTF-8"
    var lineEnding: String = "LF"
    var language: String = "Plain Text"
    var indentation: String = "Spaces: 4"

    weak var delegate: StatusBarViewDelegate?

    /// Encoding options presented in the popup.
    var availableEncodings: [String] = EncodingManager.allEncodingNames

    /// Line ending options presented in the popup.
    var availableLineEndings: [String] = ["LF", "CRLF", "CR"]

    /// Language options presented in the popup.
    var availableLanguages: [String] = ["Plain Text"]

    /// Indentation options presented in the popup.
    var availableIndentations: [String] = [
        "Spaces: 2", "Spaces: 4", "Spaces: 8", "Tabs",
    ]

    private let positionLabel = NSTextField(labelWithString: "")
    private let encodingButton: NSButton = StatusBarView.makeStatusButton()
    private let lineEndingButton: NSButton = StatusBarView.makeStatusButton()
    private let languageButton: NSButton = StatusBarView.makeStatusButton()
    private let indentationButton: NSButton = StatusBarView.makeStatusButton()

    // Popups (hidden, used for showing choices)
    private let encodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let lineEndingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let indentationPopup = NSPopUpButton(frame: .zero, pullsDown: false)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        refreshLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Factory

    private static func makeStatusButton() -> NSButton {
        let button = NSButton(title: "", target: nil, action: nil)
        button.bezelStyle = .inline
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 11)
        button.contentTintColor = .secondaryLabelColor
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return button
    }

    // MARK: - Setup

    private func setupUI() {
        // Position label (non-clickable)
        positionLabel.font = NSFont.systemFont(ofSize: 11)
        positionLabel.textColor = .secondaryLabelColor
        positionLabel.alignment = .center
        positionLabel.isEditable = false
        positionLabel.isBordered = false
        positionLabel.drawsBackground = false
        positionLabel.lineBreakMode = .byTruncatingTail

        // Configure buttons with tags for dispatch
        let buttons: [(NSButton, Int)] = [
            (encodingButton, 0), (lineEndingButton, 1),
            (languageButton, 2), (indentationButton, 3),
        ]
        for (button, tag) in buttons {
            button.target = self
            button.action = #selector(statusFieldClicked(_:))
            button.tag = tag
        }

        // Hide popups (zero-size, not added to layout, used only for menu)
        for popup in [encodingPopup, lineEndingPopup, languagePopup, indentationPopup] {
            popup.isHidden = true
            popup.frame = .zero
            addSubview(popup)
        }

        // Populate popups
        rebuildPopupMenus()

        // Create separator views between labels
        func makeSeparator() -> NSView {
            let sep = NSTextField(labelWithString: "|")
            sep.font = NSFont.systemFont(ofSize: 11)
            sep.textColor = .tertiaryLabelColor
            sep.isEditable = false
            sep.isBordered = false
            sep.drawsBackground = false
            return sep
        }

        let stackView = NSStackView(views: [
            positionLabel,
            makeSeparator(),
            encodingButton,
            makeSeparator(),
            lineEndingButton,
            makeSeparator(),
            languageButton,
            makeSeparator(),
            indentationButton,
        ])
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    // MARK: - Popup Menus

    /// Rebuilds all popup button menus from the available* arrays.
    func rebuildPopupMenus() {
        encodingPopup.removeAllItems()
        encodingPopup.addItems(withTitles: availableEncodings)

        lineEndingPopup.removeAllItems()
        lineEndingPopup.addItems(withTitles: availableLineEndings)

        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: availableLanguages)

        indentationPopup.removeAllItems()
        indentationPopup.addItems(withTitles: availableIndentations)
    }

    // MARK: - Button Actions

    private var popupForTag: [Int: NSPopUpButton] {
        [0: encodingPopup, 1: lineEndingPopup, 2: languagePopup, 3: indentationPopup]
    }

    @objc private func statusFieldClicked(_ sender: NSButton) {
        guard let popup = popupForTag[sender.tag] else { return }
        showPopupMenu(popup, relativeTo: sender) { [weak self] selected in
            guard let self else { return }
            switch sender.tag {
            case 0: self.encoding = selected; self.delegate?.statusBar(self, didChangeEncoding: selected)
            case 1: self.lineEnding = selected; self.delegate?.statusBar(self, didChangeLineEnding: selected)
            case 2: self.language = selected; self.delegate?.statusBar(self, didChangeLanguage: selected)
            case 3: self.indentation = selected; self.delegate?.statusBar(self, didChangeIndentation: selected)
            default: break
            }
            self.refreshLabels()
        }
    }

    /// Shows a popup menu below the given button view.
    /// When the user picks an item, `onSelect` is called with the item title.
    private func showPopupMenu(_ popup: NSPopUpButton, relativeTo button: NSButton,
                                onSelect: @escaping (String) -> Void) {
        guard let menu = popup.menu?.copy() as? NSMenu else { return }
        for item in menu.items {
            let title = item.title
            item.representedObject = { onSelect(title) } as () -> Void
            item.target = self
            item.action = #selector(popupMenuItemSelected(_:))
        }
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.maxY + 2),
                   in: button)
    }

    @objc private func popupMenuItemSelected(_ sender: NSMenuItem) {
        if let callback = sender.representedObject as? () -> Void {
            callback()
        }
    }

    // MARK: - Public API

    /// Update all status bar fields and refresh the display.
    func update(line: Int, column: Int, encoding: String, lineEnding: String, language: String) {
        self.line = line
        self.column = column
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.language = language
        refreshLabels()
    }

    /// Update only the indentation display.
    func updateIndentation(_ indentation: String) {
        self.indentation = indentation
        indentationButton.title = indentation
    }

    private func refreshLabels() {
        positionLabel.stringValue = "Ln \(line), Col \(column)"
        encodingButton.title = encoding
        lineEndingButton.title = lineEnding
        languageButton.title = language
        indentationButton.title = indentation
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw a 1pt separator line at the top of the status bar
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.minX, y: bounds.maxY))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.maxY))
        path.lineWidth = 1.0
        path.stroke()
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }
}
