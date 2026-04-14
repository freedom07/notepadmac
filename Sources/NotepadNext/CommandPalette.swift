import AppKit
import CommonKit

// MARK: - CommandItem

/// A single command that can be executed from the Command Palette.
public struct CommandItem: Identifiable {
    public let id: String
    public let title: String
    public let category: String?
    public let shortcut: String?
    public let action: () -> Void

    public init(id: String, title: String, category: String? = nil, shortcut: String? = nil, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.category = category
        self.shortcut = shortcut
        self.action = action
    }
}

// MARK: - CommandPaletteController

/// A floating panel that lets the user search and execute commands by name.
@available(macOS 13.0, *)
public final class CommandPaletteController: NSWindowController {

    // MARK: - Properties

    public var commands: [CommandItem] = []

    private var filteredCommands: [CommandItem] = []
    private let searchField = NSTextField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private static let rowHeight: CGFloat = 28
    private static let panelWidth: CGFloat = 520
    private static let panelHeight: CGFloat = 360

    // MARK: - Initialization

    public init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow

        super.init(window: panel)

        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    /// Registers a command so it appears in the palette.
    public func registerCommand(_ command: CommandItem) {
        commands.append(command)
    }

    /// Removes all registered commands.
    public func clearCommands() {
        commands.removeAll()
    }

    /// Shows the palette centered on the current screen.
    public func showPalette() {
        filteredCommands = commands
        reloadTable()
        searchField.stringValue = ""

        guard let panel = window, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Self.panelWidth / 2
        let y = screenFrame.midY + Self.panelHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Type a command..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        contentView.addSubview(searchField)

        // Table view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CommandColumn"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = Self.rowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(executeSelectedCommand)
        tableView.target = self

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Filtering

    private func filterCommands(query: String) {
        guard !query.isEmpty else {
            filteredCommands = commands
            reloadTable()
            return
        }

        let lowered = query.lowercased()
        filteredCommands = commands.filter { fuzzyMatch(query: lowered, in: $0.title.lowercased()) }
        reloadTable()
    }

    /// Returns `true` when every character in `query` appears in `text` in order.
    private func fuzzyMatch(query: String, in text: String) -> Bool {
        var textIndex = text.startIndex
        for char in query {
            guard let found = text[textIndex...].firstIndex(of: char) else { return false }
            textIndex = text.index(after: found)
        }
        return true
    }

    private func reloadTable() {
        tableView.reloadData()
        if !filteredCommands.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Actions

    @objc private func searchFieldChanged(_ sender: NSTextField) {
        filterCommands(query: sender.stringValue)
    }

    @objc private func executeSelectedCommand() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredCommands.count else { return }
        window?.close()
        filteredCommands[row].action()
    }

    private func dismiss() {
        window?.close()
    }
}

// MARK: - NSTableViewDataSource

@available(macOS 13.0, *)
extension CommandPaletteController: NSTableViewDataSource {

    public func numberOfRows(in tableView: NSTableView) -> Int {
        filteredCommands.count
    }
}

// MARK: - NSTableViewDelegate

@available(macOS 13.0, *)
extension CommandPaletteController: NSTableViewDelegate {

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredCommands.count else { return nil }
        let command = filteredCommands[row]

        let identifier = NSUserInterfaceItemIdentifier("CommandCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = NSTableCellView()
            cell.identifier = identifier

            let titleLabel = NSTextField(labelWithString: "")
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.font = NSFont.systemFont(ofSize: 13)
            titleLabel.lineBreakMode = .byTruncatingTail
            cell.addSubview(titleLabel)
            cell.textField = titleLabel

            let shortcutLabel = NSTextField(labelWithString: "")
            shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
            shortcutLabel.font = NSFont.systemFont(ofSize: 11)
            shortcutLabel.textColor = .secondaryLabelColor
            shortcutLabel.alignment = .right
            shortcutLabel.tag = 100
            cell.addSubview(shortcutLabel)

            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                titleLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),

                shortcutLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),
                shortcutLabel.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                shortcutLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            ])
        }

        // Configure
        var displayTitle = command.title
        if let category = command.category {
            displayTitle = "\(category): \(command.title)"
        }
        cell.textField?.stringValue = displayTitle

        if let shortcutLabel = cell.viewWithTag(100) as? NSTextField {
            shortcutLabel.stringValue = command.shortcut ?? ""
        }

        return cell
    }
}

// MARK: - NSTextFieldDelegate (keyboard handling)

@available(macOS 13.0, *)
extension CommandPaletteController: NSTextFieldDelegate {

    public func controlTextDidChange(_ obj: Notification) {
        filterCommands(query: searchField.stringValue)
    }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            executeSelectedCommand()
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            dismiss()
            return true

        case #selector(NSResponder.moveUp(_:)):
            let row = max(tableView.selectedRow - 1, 0)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
            return true

        case #selector(NSResponder.moveDown(_:)):
            let row = min(tableView.selectedRow + 1, filteredCommands.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
            return true

        default:
            return false
        }
    }
}
