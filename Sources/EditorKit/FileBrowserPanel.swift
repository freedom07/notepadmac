import AppKit
import CommonKit

// MARK: - FileBrowserPanelDelegate

/// Delegate protocol for responding to file browser events.
@available(macOS 13.0, *)
public protocol FileBrowserPanelDelegate: AnyObject {
    /// Called when the user double-clicks a file in the browser.
    func fileBrowser(_ panel: FileBrowserPanel, didSelectFile url: URL)
}

// MARK: - FileSystemItem

/// A lazily-loaded node in a directory tree. Each item represents a file or
/// folder on disk. Children are loaded on first access and cached.
@available(macOS 13.0, *)
public final class FileSystemItem {

    /// The file URL this item represents.
    public let url: URL

    /// Whether this item is a directory.
    public let isDirectory: Bool

    /// Display name derived from the URL.
    public var name: String { url.lastPathComponent }

    /// Directory and file name patterns to skip when scanning.
    public static let skipPatterns: Set<String> = [
        ".git", "node_modules", ".build", "DerivedData", ".DS_Store",
    ]

    /// Returns `true` if the given file name should be hidden from the browser.
    public static func shouldSkip(_ name: String) -> Bool {
        skipPatterns.contains(name)
    }

    /// Lazily-loaded child items. `nil` for files.
    private var _children: [FileSystemItem]?
    private var childrenLoaded = false

    public init(url: URL) {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        self.url = url
        self.isDirectory = isDir.boolValue
    }

    /// Creates an item with an explicit directory flag (useful for testing).
    public init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    /// The children of this directory item, loaded lazily on first access.
    /// Returns an empty array for non-directory items.
    public var children: [FileSystemItem] {
        if !childrenLoaded {
            loadChildren()
        }
        return _children ?? []
    }

    /// Number of children. Returns 0 for files or empty directories.
    public var numberOfChildren: Int { children.count }

    /// Force-reloads children from disk.
    public func reloadChildren() {
        childrenLoaded = false
        _children = nil
    }

    // MARK: - Private

    private func loadChildren() {
        childrenLoaded = true
        guard isDirectory else {
            _children = []
            return
        }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            _children = []
            return
        }

        _children = contents
            .filter { !FileSystemItem.shouldSkip($0.lastPathComponent) }
            .map { FileSystemItem(url: $0) }
            .sorted { lhs, rhs in
                // Directories first, then alphabetical
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

// MARK: - FileBrowserPanel

/// A panel view controller that shows a directory tree in an `NSOutlineView`.
///
/// Add root folders via ``addRootFolder(_:)`` and respond to file selections
/// through the ``FileBrowserPanelDelegate`` protocol.
@available(macOS 13.0, *)
public final class FileBrowserPanel: NSViewController {

    /// Delegate notified when the user opens a file.
    public weak var delegate: FileBrowserPanelDelegate?

    /// The currently loaded root folders.
    public var rootFolders: [URL] { rootItems.map(\.url) }

    /// The outline view displaying the file tree.
    public private(set) var outlineView: NSOutlineView!

    /// Internal data model – one item per root folder.
    private var rootItems: [FileSystemItem] = []

    // MARK: - Public API

    /// Adds a root folder to the browser and reloads the outline view.
    public func addRootFolder(_ url: URL) {
        let item = FileSystemItem(url: url)
        rootItems.append(item)
        outlineView?.reloadData()
    }

    /// Removes the root folder at the given index and reloads the outline view.
    public func removeRootFolder(at index: Int) {
        guard rootItems.indices.contains(index) else { return }
        rootItems.remove(at: index)
        outlineView?.reloadData()
    }

    // MARK: - Lifecycle

    public override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let outline = NSOutlineView()
        outline.headerView = nil
        outline.indentationPerLevel = 16
        outline.autoresizesOutlineColumn = true
        outline.rowSizeStyle = .small
        outline.selectionHighlightStyle = .regular
        outline.floatsGroupRows = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        column.isEditable = false
        outline.addTableColumn(column)
        outline.outlineTableColumn = column

        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(outlineViewDoubleClicked(_:))

        scrollView.documentView = outline
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        self.outlineView = outline
        self.view = container

        setupContextMenu()
    }

    // MARK: - Context Menu

    private func setupContextMenu() {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let revealItem = NSMenuItem(title: "Reveal in Finder", action: #selector(contextMenuRevealInFinder(_:)), keyEquivalent: "")
        revealItem.target = self
        menu.addItem(revealItem)

        let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(contextMenuCopyPath(_:)), keyEquivalent: "")
        copyPathItem.target = self
        menu.addItem(copyPathItem)

        let terminalItem = NSMenuItem(title: "Open Terminal Here", action: #selector(contextMenuOpenTerminal(_:)), keyEquivalent: "")
        terminalItem.target = self
        menu.addItem(terminalItem)

        outlineView.menu = menu
    }

    // MARK: - Actions

    @objc private func outlineViewDoubleClicked(_ sender: Any?) {
        guard let item = outlineView.item(atRow: outlineView.clickedRow) as? FileSystemItem else { return }
        if item.isDirectory {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        } else {
            delegate?.fileBrowser(self, didSelectFile: item.url)
        }
    }

    // MARK: - Context Menu Actions

    private func clickedItem() -> FileSystemItem? {
        let row = outlineView.clickedRow
        guard row >= 0 else { return nil }
        return outlineView.item(atRow: row) as? FileSystemItem
    }

    @objc private func contextMenuOpen(_ sender: Any?) {
        guard let item = clickedItem() else { return }
        if item.isDirectory {
            if outlineView.isItemExpanded(item) {
                outlineView.collapseItem(item)
            } else {
                outlineView.expandItem(item)
            }
        } else {
            delegate?.fileBrowser(self, didSelectFile: item.url)
        }
    }

    @objc private func contextMenuRevealInFinder(_ sender: Any?) {
        guard let item = clickedItem() else { return }
        NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
    }

    @objc private func contextMenuCopyPath(_ sender: Any?) {
        guard let item = clickedItem() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }

    @objc private func contextMenuOpenTerminal(_ sender: Any?) {
        guard let item = clickedItem() else { return }
        let directoryURL = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
        let script = "tell application \"Terminal\"\nactivate\ndo script \"cd \(directoryURL.path.replacingOccurrences(of: "\"", with: "\\\""))\"\nend tell"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - NSOutlineViewDataSource

@available(macOS 13.0, *)
extension FileBrowserPanel: NSOutlineViewDataSource {

    public func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return rootItems.count
        }
        guard let fsItem = item as? FileSystemItem else { return 0 }
        return fsItem.numberOfChildren
    }

    public func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            return rootItems[index]
        }
        guard let fsItem = item as? FileSystemItem else { fatalError("Unexpected item type") }
        return fsItem.children[index]
    }

    public func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fsItem = item as? FileSystemItem else { return false }
        return fsItem.isDirectory
    }
}

// MARK: - NSOutlineViewDelegate

@available(macOS 13.0, *)
extension FileBrowserPanel: NSOutlineViewDelegate {

    public func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fsItem = item as? FileSystemItem else { return nil }

        let cellIdentifier = NSUserInterfaceItemIdentifier("FileBrowserCell")
        let cell: NSTableCellView

        if let existingCell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
            cell = existingCell
        } else {
            cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(imageView)
            cell.imageView = imageView

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),

                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.stringValue = fsItem.name
        cell.imageView?.image = NSWorkspace.shared.icon(forFile: fsItem.url.path)
        cell.imageView?.image?.size = NSSize(width: 16, height: 16)

        return cell
    }
}
