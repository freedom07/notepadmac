import AppKit
import NotepadNextCore
import ThemeKit
import CommonKit

// MARK: - PreferencesWindowController

@available(macOS 13.0, *)
final class PreferencesWindowController: NSWindowController {

    private let tabViewController = NSTabViewController()
    private static var shared: PreferencesWindowController?

    static func showPreferences() {
        if shared == nil {
            shared = PreferencesWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
    }

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        tabViewController.tabStyle = .toolbar
        window.contentViewController = tabViewController

        addTabs()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func addTabs() {
        let generalTab = NSTabViewItem(viewController: GeneralPrefsViewController())
        generalTab.label = "General"
        generalTab.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)

        let editorTab = NSTabViewItem(viewController: EditorPrefsViewController())
        editorTab.label = "Editor"
        editorTab.image = NSImage(systemSymbolName: "pencil.line", accessibilityDescription: nil)

        let appearanceTab = NSTabViewItem(viewController: AppearancePrefsViewController())
        appearanceTab.label = "Appearance"
        appearanceTab.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)

        let filesTab = NSTabViewItem(viewController: FilesPrefsViewController())
        filesTab.label = "Files"
        filesTab.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)

        tabViewController.addTabViewItem(generalTab)
        tabViewController.addTabViewItem(editorTab)
        tabViewController.addTabViewItem(appearanceTab)
        tabViewController.addTabViewItem(filesTab)
    }
}

// MARK: - Helpers

private func makeLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: 13)
    label.alignment = .right
    return label
}

private func makeCheckbox(_ title: String, checked: Bool, action: Selector) -> NSButton {
    let btn = NSButton(checkboxWithTitle: title, target: nil, action: action)
    btn.state = checked ? .on : .off
    return btn
}

private func addRow(to grid: NSGridView, label: String, control: NSView) {
    let lbl = makeLabel(label)
    grid.addRow(with: [lbl, control])
}

private func makeGridContainer() -> (NSView, NSGridView) {
    let container = NSView()
    // Initialize with 2 columns and 0 rows to allow column(at:) access
    let grid = NSGridView(numberOfColumns: 2, rows: 0)
    grid.rowSpacing = 12
    grid.columnSpacing = 12
    grid.column(at: 0).xPlacement = .trailing
    grid.column(at: 1).xPlacement = .leading
    grid.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(grid)
    NSLayoutConstraint.activate([
        grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
        grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 40),
        grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40),
    ])
    return (container, grid)
}

// MARK: - General Preferences

@available(macOS 13.0, *)
private final class GeneralPrefsViewController: NSViewController {
    private let prefs = Preferences.shared

    override func loadView() {
        let (container, grid) = makeGridContainer()
        self.view = container
        preferredContentSize = NSSize(width: 520, height: 300)

        let sessionCheck = makeCheckbox(
            "Restore previous session on startup",
            checked: prefs.rememberSession,
            action: #selector(toggleRememberSession(_:))
        )
        sessionCheck.target = self
        addRow(to: grid, label: "Startup:", control: sessionCheck)

        let emptyDocCheck = makeCheckbox(
            "Open empty document if no session",
            checked: prefs.openEmptyDocumentOnStartup,
            action: #selector(toggleEmptyDoc(_:))
        )
        emptyDocCheck.target = self
        addRow(to: grid, label: "", control: emptyDocCheck)

        let recentStepper = NSStackView()
        recentStepper.orientation = .horizontal
        recentStepper.spacing = 6
        let recentField = NSTextField(string: "\(prefs.recentFilesCount)")
        recentField.isEditable = false
        recentField.frame = NSRect(x: 0, y: 0, width: 40, height: 22)
        let stepper = NSStepper()
        stepper.minValue = 5
        stepper.maxValue = 50
        stepper.integerValue = prefs.recentFilesCount
        stepper.target = self
        stepper.action = #selector(recentCountChanged(_:))
        stepper.tag = 0
        recentStepper.addArrangedSubview(recentField)
        recentStepper.addArrangedSubview(stepper)
        recentStepper.addArrangedSubview(NSTextField(labelWithString: "recent files"))
        addRow(to: grid, label: "Remember:", control: recentStepper)
    }

    @objc private func toggleRememberSession(_ sender: NSButton) {
        prefs.rememberSession = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleEmptyDoc(_ sender: NSButton) {
        prefs.openEmptyDocumentOnStartup = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func recentCountChanged(_ sender: NSStepper) {
        prefs.recentFilesCount = sender.integerValue
        if let stack = sender.superview as? NSStackView,
           let field = stack.arrangedSubviews.first as? NSTextField {
            field.stringValue = "\(sender.integerValue)"
        }
        prefs.notifyChange()
    }
}

// MARK: - Editor Preferences

@available(macOS 13.0, *)
private final class EditorPrefsViewController: NSViewController {
    private let prefs = Preferences.shared

    override func loadView() {
        let (container, grid) = makeGridContainer()
        self.view = container
        preferredContentSize = NSSize(width: 520, height: 380)

        // Tab width
        let tabWidthPopup = NSPopUpButton()
        for w in [2, 4, 8] {
            tabWidthPopup.addItem(withTitle: "\(w)")
        }
        tabWidthPopup.selectItem(withTitle: "\(prefs.tabWidth)")
        tabWidthPopup.target = self
        tabWidthPopup.action = #selector(tabWidthChanged(_:))
        addRow(to: grid, label: "Tab Width:", control: tabWidthPopup)

        // Spaces vs tabs
        let spacesCheck = makeCheckbox(
            "Insert spaces instead of tabs",
            checked: prefs.usesSpaces,
            action: #selector(toggleSpaces(_:))
        )
        spacesCheck.target = self
        addRow(to: grid, label: "Indentation:", control: spacesCheck)

        // Show line numbers
        let lineNumCheck = makeCheckbox(
            "Show line numbers",
            checked: prefs.showLineNumbers,
            action: #selector(toggleLineNumbers(_:))
        )
        lineNumCheck.target = self
        addRow(to: grid, label: "Display:", control: lineNumCheck)

        // Word wrap
        let wrapCheck = makeCheckbox(
            "Wrap lines",
            checked: prefs.wordWrap,
            action: #selector(toggleWordWrap(_:))
        )
        wrapCheck.target = self
        addRow(to: grid, label: "", control: wrapCheck)

        // Indent guides
        let guidesCheck = makeCheckbox(
            "Show indent guides",
            checked: prefs.showIndentGuides,
            action: #selector(toggleIndentGuides(_:))
        )
        guidesCheck.target = self
        addRow(to: grid, label: "", control: guidesCheck)

        // Auto-close brackets
        let bracketCheck = makeCheckbox(
            "Auto-close brackets and quotes",
            checked: prefs.autoCloseBrackets,
            action: #selector(toggleBrackets(_:))
        )
        bracketCheck.target = self
        addRow(to: grid, label: "Editing:", control: bracketCheck)

        // Smart highlight
        let highlightCheck = makeCheckbox(
            "Highlight matching words",
            checked: prefs.smartHighlight,
            action: #selector(toggleSmartHighlight(_:))
        )
        highlightCheck.target = self
        addRow(to: grid, label: "", control: highlightCheck)

        // Edge column
        let edgeStack = NSStackView()
        edgeStack.orientation = .horizontal
        edgeStack.spacing = 6
        let edgeCheck = makeCheckbox(
            "Show edge at column",
            checked: prefs.showEdgeColumn,
            action: #selector(toggleEdgeColumn(_:))
        )
        edgeCheck.target = self
        let edgeField = NSTextField(string: "\(prefs.edgeColumn)")
        edgeField.frame = NSRect(x: 0, y: 0, width: 50, height: 22)
        edgeField.tag = 100
        edgeField.target = self
        edgeField.action = #selector(edgeColumnChanged(_:))
        edgeStack.addArrangedSubview(edgeCheck)
        edgeStack.addArrangedSubview(edgeField)
        addRow(to: grid, label: "Edge:", control: edgeStack)
    }

    @objc private func tabWidthChanged(_ sender: NSPopUpButton) {
        if let title = sender.titleOfSelectedItem, let val = Int(title) {
            prefs.tabWidth = val
            prefs.notifyChange()
        }
    }

    @objc private func toggleSpaces(_ sender: NSButton) {
        prefs.usesSpaces = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleLineNumbers(_ sender: NSButton) {
        prefs.showLineNumbers = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleWordWrap(_ sender: NSButton) {
        prefs.wordWrap = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleIndentGuides(_ sender: NSButton) {
        prefs.showIndentGuides = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleBrackets(_ sender: NSButton) {
        prefs.autoCloseBrackets = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleSmartHighlight(_ sender: NSButton) {
        prefs.smartHighlight = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleEdgeColumn(_ sender: NSButton) {
        prefs.showEdgeColumn = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func edgeColumnChanged(_ sender: NSTextField) {
        if let val = Int(sender.stringValue), val > 0 {
            prefs.edgeColumn = val
            prefs.notifyChange()
        }
    }
}

// MARK: - Appearance Preferences

@available(macOS 13.0, *)
private final class AppearancePrefsViewController: NSViewController {
    private let prefs = Preferences.shared

    override func loadView() {
        let (container, grid) = makeGridContainer()
        self.view = container
        preferredContentSize = NSSize(width: 520, height: 300)

        // Theme picker
        let themePopup = NSPopUpButton()
        for theme in ThemeManager.shared.availableThemes {
            themePopup.addItem(withTitle: theme.name)
        }
        themePopup.selectItem(withTitle: prefs.themeName)
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        addRow(to: grid, label: "Theme:", control: themePopup)

        // Font size
        let sizeStack = NSStackView()
        sizeStack.orientation = .horizontal
        sizeStack.spacing = 6
        let sizeField = NSTextField(string: "\(Int(prefs.fontSize))")
        sizeField.frame = NSRect(x: 0, y: 0, width: 40, height: 22)
        let sizeStepper = NSStepper()
        sizeStepper.minValue = 8
        sizeStepper.maxValue = 72
        sizeStepper.doubleValue = prefs.fontSize
        sizeStepper.target = self
        sizeStepper.action = #selector(fontSizeChanged(_:))
        sizeStack.addArrangedSubview(sizeField)
        sizeStack.addArrangedSubview(sizeStepper)
        sizeStack.addArrangedSubview(NSTextField(labelWithString: "pt"))
        addRow(to: grid, label: "Font Size:", control: sizeStack)

        // Line height
        let lineHeightPopup = NSPopUpButton()
        for h in ["1.0", "1.2", "1.4", "1.5", "1.6", "1.8", "2.0"] {
            lineHeightPopup.addItem(withTitle: h)
        }
        lineHeightPopup.selectItem(withTitle: String(format: "%.1f", prefs.lineHeight))
        lineHeightPopup.target = self
        lineHeightPopup.action = #selector(lineHeightChanged(_:))
        addRow(to: grid, label: "Line Height:", control: lineHeightPopup)

        // Follow system appearance
        let systemCheck = makeCheckbox(
            "Match system dark/light mode",
            checked: prefs.followSystemAppearance,
            action: #selector(toggleFollowSystem(_:))
        )
        systemCheck.target = self
        addRow(to: grid, label: "Appearance:", control: systemCheck)
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let name = sender.titleOfSelectedItem else { return }
        prefs.themeName = name
        if let theme = ThemeManager.shared.theme(named: name) {
            ThemeManager.shared.setTheme(theme)
        }
        prefs.notifyChange()
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        prefs.fontSize = sender.doubleValue
        if let stack = sender.superview as? NSStackView,
           let field = stack.arrangedSubviews.first as? NSTextField {
            field.stringValue = "\(Int(sender.doubleValue))"
        }
        prefs.notifyChange()
    }

    @objc private func lineHeightChanged(_ sender: NSPopUpButton) {
        guard let title = sender.titleOfSelectedItem, let val = Double(title) else { return }
        prefs.lineHeight = val
        prefs.notifyChange()
    }

    @objc private func toggleFollowSystem(_ sender: NSButton) {
        prefs.followSystemAppearance = sender.state == .on
        prefs.notifyChange()
    }
}

// MARK: - Files Preferences

@available(macOS 13.0, *)
private final class FilesPrefsViewController: NSViewController {
    private let prefs = Preferences.shared

    override func loadView() {
        let (container, grid) = makeGridContainer()
        self.view = container
        preferredContentSize = NSSize(width: 520, height: 350)

        // Default encoding
        let encodingPopup = NSPopUpButton()
        for name in ["UTF-8", "UTF-16 LE", "UTF-16 BE", "ASCII", "ISO 8859-1", "Windows-1252",
                      "EUC-KR", "Shift-JIS", "GB2312", "Big5"] {
            encodingPopup.addItem(withTitle: name)
        }
        encodingPopup.selectItem(withTitle: prefs.defaultEncoding)
        encodingPopup.target = self
        encodingPopup.action = #selector(encodingChanged(_:))
        addRow(to: grid, label: "Encoding:", control: encodingPopup)

        // Default line ending
        let eolPopup = NSPopUpButton()
        eolPopup.addItem(withTitle: "LF (Unix)")
        eolPopup.addItem(withTitle: "CRLF (Windows)")
        eolPopup.addItem(withTitle: "CR (Classic Mac)")
        switch prefs.defaultLineEnding {
        case "CRLF": eolPopup.selectItem(at: 1)
        case "CR": eolPopup.selectItem(at: 2)
        default: eolPopup.selectItem(at: 0)
        }
        eolPopup.target = self
        eolPopup.action = #selector(eolChanged(_:))
        addRow(to: grid, label: "Line Ending:", control: eolPopup)

        // Trim trailing whitespace
        let trimCheck = makeCheckbox(
            "Trim trailing whitespace on save",
            checked: prefs.trimTrailingWhitespaceOnSave,
            action: #selector(toggleTrim(_:))
        )
        trimCheck.target = self
        addRow(to: grid, label: "On Save:", control: trimCheck)

        // Auto-save
        let autoSaveCheck = makeCheckbox(
            "Auto-save documents",
            checked: prefs.autoSaveEnabled,
            action: #selector(toggleAutoSave(_:))
        )
        autoSaveCheck.target = self
        addRow(to: grid, label: "Auto-save:", control: autoSaveCheck)

        let intervalStack = NSStackView()
        intervalStack.orientation = .horizontal
        intervalStack.spacing = 6
        let intervalPopup = NSPopUpButton()
        for sec in ["10", "15", "30", "60", "120", "300"] {
            let label = Int(sec)! < 60 ? "\(sec) seconds" : "\(Int(sec)! / 60) minutes"
            intervalPopup.addItem(withTitle: label)
            intervalPopup.lastItem?.tag = Int(sec)!
        }
        intervalPopup.selectItem(withTag: Int(prefs.autoSaveInterval))
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged(_:))
        intervalStack.addArrangedSubview(NSTextField(labelWithString: "Every"))
        intervalStack.addArrangedSubview(intervalPopup)
        addRow(to: grid, label: "", control: intervalStack)

        // Show hidden files
        let hiddenCheck = makeCheckbox(
            "Show hidden files in file browser",
            checked: prefs.showHiddenFiles,
            action: #selector(toggleHiddenFiles(_:))
        )
        hiddenCheck.target = self
        addRow(to: grid, label: "File Browser:", control: hiddenCheck)
    }

    @objc private func encodingChanged(_ sender: NSPopUpButton) {
        if let title = sender.titleOfSelectedItem {
            prefs.defaultEncoding = title
            prefs.notifyChange()
        }
    }

    @objc private func eolChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1: prefs.defaultLineEnding = "CRLF"
        case 2: prefs.defaultLineEnding = "CR"
        default: prefs.defaultLineEnding = "LF"
        }
        prefs.notifyChange()
    }

    @objc private func toggleTrim(_ sender: NSButton) {
        prefs.trimTrailingWhitespaceOnSave = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func toggleAutoSave(_ sender: NSButton) {
        prefs.autoSaveEnabled = sender.state == .on
        prefs.notifyChange()
    }

    @objc private func intervalChanged(_ sender: NSPopUpButton) {
        if let item = sender.selectedItem {
            prefs.autoSaveInterval = Double(item.tag)
            prefs.notifyChange()
        }
    }

    @objc private func toggleHiddenFiles(_ sender: NSButton) {
        prefs.showHiddenFiles = sender.state == .on
        prefs.notifyChange()
    }
}
