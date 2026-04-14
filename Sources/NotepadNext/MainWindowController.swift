import AppKit
import TextCore
import EditorKit
import FileKit
import TabKit
import SearchKit
import SyntaxKit
import CommonKit
import NotepadNextCore
import PanelKit
import MarkdownKit

@available(macOS 13.0, *)
final class MainWindowController: NSWindowController, TabBarViewDelegate, SearchResultsPanelDelegate, DocumentListPanelDelegate, ClipboardHistoryPanelDelegate {

    let tabManager = TabManager()
    let statusBar = StatusBarView()
    let tabBarView = TabBarView()
    var currentEditor: EditorViewController?

    /// The panel host manages the split-view layout with collapsible panels.
    let panelHost = PanelHostController()

    /// Maps tab IDs to their associated editor view controller.
    private var editors: [UUID: EditorViewController] = [:]

    /// The container view that holds the tab bar, panel host, and status bar.
    private let containerView = NSView()

    /// The view hosting the current editor's view (inside panelHost.editorArea).
    private var editorContainerView: NSView { panelHost.editorArea }

    /// The file browser panel shown in the left sidebar.
    private lazy var fileBrowserPanel: FileBrowserPanel = {
        let panel = FileBrowserPanel()
        panel.delegate = self
        return panel
    }()

    /// The function list panel displayed on the left side.
    let functionListPanel = FunctionListPanel()

    /// The search results panel for displaying find-in-files results.
    lazy var searchResultsPanel: SearchResultsPanel = {
        let panel = SearchResultsPanel()
        panel.delegate = self
        return panel
    }()

    /// The document list panel showing all open tabs.
    private lazy var documentListPanel: DocumentListPanel = {
        let panel = DocumentListPanel()
        panel.delegate = self
        return panel
    }()

    /// The clipboard history panel.
    private lazy var clipboardHistoryPanel: ClipboardHistoryPanel = {
        let panel = ClipboardHistoryPanel()
        panel.delegate = self
        return panel
    }()

    /// The Markdown preview panel shown in the right sidebar.
    private lazy var markdownPreviewController = MarkdownPreviewController()

    // MARK: - Initialization

    /// Root view controller set as window.contentViewController for proper VC hierarchy.
    private let rootViewController = NSViewController()

    init() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = CommonKit.appName
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        window.titlebarAppearsTransparent = false

        // Set root VC as contentViewController for proper VC containment
        rootViewController.view = NSView()
        window.contentViewController = rootViewController

        super.init(window: window)

        // Add panelHost as child of rootViewController for lifecycle callbacks
        rootViewController.addChild(panelHost)

        setupLayout()
        setupTabManager()
        registerPanels()

        // Wire status bar delegate for EOL/encoding changes
        statusBar.delegate = self

        // Create an initial empty tab
        newDocument()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Layout

    private func setupLayout() {
        let rootView = rootViewController.view

        containerView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
        ])

        // Tab bar at top
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.delegate = self
        containerView.addSubview(tabBarView)
        NSLayoutConstraint.activate([
            tabBarView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tabBarView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tabBarView.heightAnchor.constraint(equalToConstant: 30),
        ])

        // Status bar at bottom
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusBar)
        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 22),
        ])

        // Panel host (split view with editor + collapsible panels) in between
        let panelHostView = panelHost.view
        panelHostView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(panelHostView)
        NSLayoutConstraint.activate([
            panelHostView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            panelHostView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            panelHostView.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            panelHostView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
        ])
    }

    // MARK: - Tab Manager

    private func setupTabManager() {
        tabManager.onTabsChanged = { [weak self] in
            self?.syncTabBarView()
            self?.updateWindowTitle()
            // Auto-refresh document list when tabs change
            if let self = self, self.panelHost.isPanelVisible(id: "document-list") {
                self.refreshDocumentList()
            }
        }
    }

    /// Synchronize TabBarView state with TabManager state.
    private func syncTabBarView() {
        tabBarView.tabs = tabManager.tabs
        tabBarView.selectedIndex = tabManager.selectedIndex
        tabBarView.needsDisplay = true
    }

    // MARK: - TabBarViewDelegate

    func tabBarView(_ tabBar: TabBarView, didSelectTabAt index: Int) {
        tabManager.selectTab(at: index)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        }
    }

    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int) {
        guard tabManager.tabs.indices.contains(index) else { return }
        let tab = tabManager.tabs[index]
        editors.removeValue(forKey: tab.id)
        tabManager.closeTab(at: index)

        if let selectedTab = tabManager.selectedTab {
            switchToEditor(for: selectedTab)
        } else {
            // No tabs remaining: clear editor area
            currentEditor?.view.removeFromSuperview()
            currentEditor?.removeFromParent()
            currentEditor = nil
            updateWindowTitle()
        }
    }

    func tabBarViewDidClickAddButton(_ tabBar: TabBarView) {
        newDocument()
    }

    func tabBarView(_ tabBar: TabBarView, didMoveTabFrom sourceIndex: Int, to destinationIndex: Int) {
        tabManager.moveTab(from: sourceIndex, to: destinationIndex)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        }
    }

    func tabBarView(_ tabBar: TabBarView, didTogglePinAt index: Int) {
        tabManager.togglePin(at: index)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        }
    }

    func tabBarView(_ tabBar: TabBarView, didRequestCloseToLeftOf index: Int) {
        tabManager.closeTabsToLeft(of: index)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        } else {
            currentEditor?.view.removeFromSuperview()
            currentEditor?.removeFromParent()
            currentEditor = nil
            updateWindowTitle()
        }
    }

    func tabBarView(_ tabBar: TabBarView, didRequestCloseToRightOf index: Int) {
        tabManager.closeTabsToRight(of: index)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        } else {
            currentEditor?.view.removeFromSuperview()
            currentEditor?.removeFromParent()
            currentEditor = nil
            updateWindowTitle()
        }
    }

    func tabBarViewDidRequestCloseUnchanged(_ tabBar: TabBarView) {
        // Remove editors for tabs that will be closed
        let unchangedIds = tabManager.tabs
            .filter { !$0.isModified && !$0.isPinned }
            .map { $0.id }
        for id in unchangedIds {
            editors.removeValue(forKey: id)
        }

        tabManager.closeUnchangedTabs()
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        } else {
            currentEditor?.view.removeFromSuperview()
            currentEditor?.removeFromParent()
            currentEditor = nil
            updateWindowTitle()
        }
    }

    // MARK: - Document Operations

    func newDocument() {
        let tab = tabManager.addTab(title: "Untitled")
        let editor = createEditor(for: TextDocument())
        editors[tab.id] = editor
        switchToEditor(for: tab)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.text, .sourceCode, .plainText, .data]

        guard let window = self.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            for url in panel.urls {
                self?.openFile(at: url)
            }
        }
    }

    func openFile(at url: URL) {
        // Check if already open
        if let existingTab = tabManager.tab(for: url),
           let index = tabManager.tabs.firstIndex(where: { $0.id == existingTab.id }) {
            tabManager.selectTab(at: index)
            switchToEditor(for: existingTab)
            return
        }

        do {
            let document = try FileKit.loadDocument(from: url)
            let tab = tabManager.addTab(title: url.lastPathComponent, filePath: url)
            let editor = createEditor(for: document)
            editor.text = document.content
            editors[tab.id] = editor
            switchToEditor(for: tab)

            statusBar.update(
                line: 1,
                column: 1,
                encoding: encodingName(for: document.encoding),
                lineEnding: document.lineEnding.displayName,
                language: detectLanguage(for: url)
            )

            // Auto-show Markdown preview for .md files
            if url.pathExtension.lowercased() == "md" && !panelHost.isPanelVisible(id: "markdown-preview") {
                panelHost.showPanel(id: "markdown-preview")
                updateMarkdownPreview()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    func saveDocument() {
        guard let tab = tabManager.selectedTab,
              let editor = currentEditor else { return }

        if let filePath = tab.filePath {
            do {
                try FileKit.writeFile(content: editor.text, to: filePath)
                tab.isModified = false
                syncTabBarView()
                updateWindowTitle()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        guard let tab = tabManager.selectedTab,
              let editor = currentEditor else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = tab.title

        guard let window = self.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try FileKit.writeFile(content: editor.text, to: url)
                tab.filePath = url
                tab.title = url.lastPathComponent
                tab.isModified = false
                self?.syncTabBarView()
                self?.updateWindowTitle()

                self?.statusBar.update(
                    line: self?.statusBar.line ?? 1,
                    column: self?.statusBar.column ?? 1,
                    encoding: self?.statusBar.encoding ?? "UTF-8",
                    lineEnding: self?.statusBar.lineEnding ?? "LF",
                    language: self?.detectLanguage(for: url) ?? "Plain Text"
                )
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    // MARK: - Editor Management

    private func createEditor(for document: TextDocument) -> EditorViewController {
        let editor = EditorViewController()
        editor.text = document.content

        editor.onCursorDidMove = { [weak self] line, column in
            self?.statusBar.update(
                line: line,
                column: column,
                encoding: self?.statusBar.encoding ?? "UTF-8",
                lineEnding: self?.statusBar.lineEnding ?? "LF",
                language: self?.statusBar.language ?? "Plain Text"
            )
        }

        editor.onTextDidChange = { [weak self] newText in
            guard let self = self else { return }
            if let tab = self.tabManager.selectedTab {
                tab.isModified = true
                self.syncTabBarView()
                self.updateWindowTitle()
            }
            // Update function list panel with new text
            if self.panelHost.isPanelVisible(id: "function-list") {
                self.functionListPanel.sourceText = newText
            }
            // Update Markdown preview with new text
            self.updateMarkdownPreview()
        }

        return editor
    }

    private func switchToEditor(for tab: TabItem) {
        // Remove current editor view
        currentEditor?.view.removeFromSuperview()
        currentEditor?.removeFromParent()

        // Show the editor for this tab
        guard let editor = editors[tab.id] else { return }
        currentEditor = editor

        // Ensure the editor view is loaded
        _ = editor.view

        // Add editor as child of the wrapper VC that owns editorArea,
        // so the VC hierarchy matches the view hierarchy.
        panelHost.editorWrapperController.addChild(editor)
        editor.view.translatesAutoresizingMaskIntoConstraints = false
        editorContainerView.addSubview(editor.view)
        NSLayoutConstraint.activate([
            editor.view.leadingAnchor.constraint(equalTo: editorContainerView.leadingAnchor),
            editor.view.trailingAnchor.constraint(equalTo: editorContainerView.trailingAnchor),
            editor.view.topAnchor.constraint(equalTo: editorContainerView.topAnchor),
            editor.view.bottomAnchor.constraint(equalTo: editorContainerView.bottomAnchor),
        ])

        syncTabBarView()
        updateWindowTitle()

        statusBar.update(
            line: 1,
            column: 1,
            encoding: "UTF-8",
            lineEnding: LineEnding.lf.displayName,
            language: tab.filePath.map { detectLanguage(for: $0) } ?? "Plain Text"
        )

        // Update function list panel for the new tab
        updateFunctionListContent()

        // Update Markdown preview for the new tab
        updateMarkdownPreview()
    }

    // MARK: - Window Title

    private func updateWindowTitle() {
        guard let tab = tabManager.selectedTab else {
            window?.title = CommonKit.appName
            return
        }
        let modified = tab.isModified ? " \u{2014} Edited" : ""
        if let filePath = tab.filePath {
            window?.title = "\(filePath.lastPathComponent)\(modified) \u{2014} \(CommonKit.appName)"
            window?.representedURL = filePath
        } else {
            window?.title = "\(tab.title)\(modified) \u{2014} \(CommonKit.appName)"
            window?.representedURL = nil
        }
    }

    // MARK: - Find Bar

    private lazy var findBarController = FindBarController()
    private lazy var goToLineController: GoToLineController = {
        let ctrl = GoToLineController()
        ctrl.onGoToLine = { [weak self] line in
            guard let editor = self?.currentEditor else { return }
            let text = editor.text as NSString
            var currentLine = 1
            var location = 0
            while currentLine < line && location < text.length {
                if text.character(at: location) == 0x0A /* \n */ {
                    currentLine += 1
                }
                location += 1
            }
            let range = NSRange(location: min(location, text.length), length: 0)
            editor.textView.setSelectedRange(range)
            editor.textView.scrollRangeToVisible(range)
        }
        return ctrl
    }()
    private lazy var commandPaletteController: CommandPaletteController = {
        let ctrl = CommandPaletteController()
        registerCommandPaletteCommands(ctrl)
        return ctrl
    }()
    private let macroRecorder = MacroRecorder()
    private var lastRecordedMacro: Macro?
    private lazy var runMacroDialog = RunMacroDialog()
    private lazy var externalCommandController = ExternalCommandController()
    private lazy var columnEditorController = ColumnEditorController()
    private var _splitCtrl: SplitEditorController?

    func showFindBar() {
        findBarController.editorTextView = currentEditor?.textView
        if findBarController.view.superview == nil {
            findBarController.onFindAllOpenDocuments = { [weak self] pattern, options in
                self?.findInAllOpenDocuments(pattern: pattern, options: options)
            }
            findBarController.view.translatesAutoresizingMaskIntoConstraints = false
            editorContainerView.addSubview(findBarController.view)
            NSLayoutConstraint.activate([
                findBarController.view.topAnchor.constraint(equalTo: editorContainerView.topAnchor),
                findBarController.view.leadingAnchor.constraint(equalTo: editorContainerView.leadingAnchor),
                findBarController.view.trailingAnchor.constraint(equalTo: editorContainerView.trailingAnchor),
                findBarController.view.heightAnchor.constraint(equalToConstant: 60),
            ])
        }
        findBarController.showFindBar()
    }

    func showFindAndReplace() {
        showFindBar()
        findBarController.isReplaceVisible = true
    }

    func findNext() {
        findBarController.findNext()
    }

    func findPrevious() {
        findBarController.findPrevious()
    }

    func goToLine() {
        goToLineController.showDialog()
    }

    func showCommandPalette() {
        commandPaletteController.showPalette()
    }

    func recordMacro() {
        macroRecorder.startRecording()
    }

    func stopRecordingMacro() {
        let macro = macroRecorder.stopRecording()
        lastRecordedMacro = macro
        MacroManager.shared.saveMacro(macro)
    }

    func playMacro() {
        guard let macro = lastRecordedMacro,
              let tv = currentEditor?.textView else { return }
        MacroManager.shared.playMacro(macro, in: tv)
    }

    func splitEditor() {
        // Toggle split on the current editor
        guard let editor = currentEditor else { return }
        let splitCtrl = SplitEditorController(primaryEditor: editor)
        splitCtrl.splitEditor(orientation: .vertical)
    }

    func clearAllMarks() {
        findBarController.clearAllMarks()
    }

    /// Triggers "Find All in Open Documents" using the current find bar search
    /// pattern and options. Called from the menu action in AppDelegate.
    func triggerFindAllInOpenDocuments() {
        findBarController.findAllOpenDocsAction()
    }

    // MARK: - Replace in Files

    /// Shows a multi-step dialog flow that lets the user replace text across
    /// files in a chosen directory.
    func replaceInFiles() {
        guard let window = self.window else { return }

        // Step 1: Collect pattern, replacement, and optional file filter.
        let inputAlert = NSAlert()
        inputAlert.messageText = "Replace in Files"
        inputAlert.informativeText = "Enter the search pattern, replacement text, and an optional file filter (e.g. *.swift)."
        inputAlert.addButton(withTitle: "Next")
        inputAlert.addButton(withTitle: "Cancel")

        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 90))

        let patternField = NSTextField(frame: NSRect(x: 0, y: 60, width: 320, height: 24))
        patternField.placeholderString = "Search pattern"
        if !findBarController.searchField.stringValue.isEmpty {
            patternField.stringValue = findBarController.searchField.stringValue
        }
        accessoryView.addSubview(patternField)

        let replacementField = NSTextField(frame: NSRect(x: 0, y: 32, width: 320, height: 24))
        replacementField.placeholderString = "Replacement text"
        if !findBarController.replaceField.stringValue.isEmpty {
            replacementField.stringValue = findBarController.replaceField.stringValue
        }
        accessoryView.addSubview(replacementField)

        let filterField = NSTextField(frame: NSRect(x: 0, y: 4, width: 320, height: 24))
        filterField.placeholderString = "File filter (e.g. *.swift) — leave empty for all files"
        accessoryView.addSubview(filterField)

        inputAlert.accessoryView = accessoryView
        inputAlert.window.initialFirstResponder = patternField

        let inputResponse = inputAlert.runModal()
        guard inputResponse == .alertFirstButtonReturn else { return }

        let pattern = patternField.stringValue
        let replacement = replacementField.stringValue
        let fileGlob: String? = filterField.stringValue.isEmpty ? nil : filterField.stringValue

        guard !pattern.isEmpty else { return }

        // Step 2: Pick a directory.
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Choose Directory"

        openPanel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let directoryURL = openPanel.url else { return }

            // Step 3: Confirmation dialog.
            let confirmAlert = NSAlert()
            confirmAlert.messageText = "Confirm Replace in Files"
            confirmAlert.alertStyle = .warning
            let filterDesc = fileGlob ?? "all files"
            confirmAlert.informativeText = """
            Directory: \(directoryURL.path)
            File filter: \(filterDesc)
            Find: \(pattern)
            Replace with: \(replacement)

            This operation cannot be undone. Proceed?
            """
            confirmAlert.addButton(withTitle: "Replace All")
            confirmAlert.addButton(withTitle: "Cancel")

            let confirmResponse = confirmAlert.runModal()
            guard confirmResponse == .alertFirstButtonReturn else { return }

            // Step 4: Execute replacement.
            let finder = FindInFiles()
            let options = SearchOptions()
            let results = finder.replaceInFiles(
                pattern: pattern,
                replacement: replacement,
                in: directoryURL,
                fileGlob: fileGlob,
                options: options
            )

            let totalFiles = results.count
            let totalReplacements = results.reduce(0) { $0 + $1.replacementCount }

            let resultAlert = NSAlert()
            resultAlert.messageText = "Replace in Files Complete"
            if totalFiles == 0 {
                resultAlert.informativeText = "No matches found."
            } else {
                resultAlert.informativeText = "Replaced \(totalReplacements) occurrence(s) across \(totalFiles) file(s)."
            }
            resultAlert.alertStyle = .informational
            resultAlert.addButton(withTitle: "OK")
            resultAlert.runModal()

            // Reload any open files that were modified.
            self?.reloadModifiedOpenFiles(results)
        }
    }

    /// Reloads the content of any open tabs whose file was modified by Replace
    /// in Files so the editor stays in sync with the disk.
    private func reloadModifiedOpenFiles(_ results: [ReplaceInFilesResult]) {
        let modifiedURLs = Set(results.map { $0.fileURL })
        for tab in tabManager.tabs {
            guard let filePath = tab.filePath, modifiedURLs.contains(filePath) else { continue }
            guard let doc = try? FileKit.loadDocument(from: filePath) else { continue }
            if let editor = editors[tab.id] {
                editor.text = doc.content
            }
        }
    }

    // MARK: - Quick-Win Features

    func reloadFromDisk() {
        guard let tab = tabManager.selectedTab, let url = tab.filePath else { return }
        if tab.isModified {
            let alert = NSAlert()
            alert.messageText = "Discard unsaved changes?"
            alert.informativeText = "This will reload \(url.lastPathComponent) from disk."
            alert.addButton(withTitle: "Reload")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        guard let doc = try? FileKit.loadDocument(from: url) else { return }
        currentEditor?.text = doc.content
        tab.isModified = false
        syncTabBarView()
        updateWindowTitle()
    }

    func openContainingFolder() {
        guard let url = tabManager.selectedTab?.filePath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openTerminalHere() {
        guard let url = tabManager.selectedTab?.filePath else { return }
        let dir = url.deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", dir.path]
        try? process.run()
    }

    func renameFile() {
        guard let tab = tabManager.selectedTab, let oldURL = tab.filePath else { return }
        let panel = NSSavePanel()
        panel.directoryURL = oldURL.deletingLastPathComponent()
        panel.nameFieldStringValue = oldURL.lastPathComponent
        guard panel.runModal() == .OK, let newURL = panel.url else { return }
        try? FileManager.default.moveItem(at: oldURL, to: newURL)
        tab.filePath = newURL
        tab.title = newURL.lastPathComponent
        syncTabBarView()
        updateWindowTitle()
    }

    func saveCopyAs() {
        guard let editor = currentEditor else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tabManager.selectedTab?.title ?? "Untitled"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? FileKit.writeFile(content: editor.text, to: url)
    }

    func searchOnInternet() {
        guard let tv = currentEditor?.textView else { return }
        let text = (tv.string as NSString).substring(with: tv.selectedRange())
        guard !text.isEmpty,
              let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?q=\(encoded)") else { return }
        NSWorkspace.shared.open(url)
    }

    func showSummary() {
        guard let text = currentEditor?.text else { return }
        let lines = text.components(separatedBy: .newlines).count
        let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        let chars = text.count
        let bytes = text.utf8.count
        let alert = NSAlert()
        alert.messageText = "Document Summary"
        alert.informativeText = "Lines: \(lines)\nWords: \(words)\nCharacters: \(chars)\nBytes: \(bytes)"
        alert.runModal()
    }

    // MARK: - Full Screen Mode

    func toggleFullScreen() {
        window?.toggleFullScreen(nil)
    }

    // MARK: - Distraction-Free Mode

    private var isDistractionFree = false

    func toggleDistractionFree() {
        isDistractionFree.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            tabBarView.animator().isHidden = isDistractionFree
            statusBar.animator().isHidden = isDistractionFree
            if isDistractionFree {
                panelHost.hideDockArea(.left)
                panelHost.hideDockArea(.bottom)
                panelHost.hideDockArea(.right)
            }
        }
    }

    // MARK: - Monitoring / Tail -f Mode

    private var fileMonitor: FileWatcher?
    private var isMonitoring = false

    func toggleMonitoring() {
        guard let url = tabManager.selectedTab?.filePath else { return }
        if isMonitoring {
            fileMonitor?.stop()
            fileMonitor = nil
            isMonitoring = false
            currentEditor?.textView.isEditable = true
        } else {
            fileMonitor = FileWatcher(url: url) { [weak self] changeType in
                DispatchQueue.main.async {
                    guard changeType == .modified else { return }
                    self?.reloadAndScrollToEnd()
                }
            }
            fileMonitor?.start()
            isMonitoring = true
            currentEditor?.textView.isEditable = false
        }
        statusBar.updateIndentation(isMonitoring ? "Monitoring" : "Spaces: 4")
    }

    private func reloadAndScrollToEnd() {
        guard let url = tabManager.selectedTab?.filePath,
              let doc = try? FileKit.loadDocument(from: url) else { return }
        currentEditor?.text = doc.content
        currentEditor?.textView.scrollToEndOfDocument(nil)
    }

    // MARK: - Fold Controls

    /// The folding gutter for the current editor, if any.
    var foldingGutter: FoldingGutter? {
        // Walk through the editor's scroll view rulers to find a FoldingGutter
        return currentEditor?.scrollView.subviews.compactMap { $0 as? FoldingGutter }.first
    }

    func foldAll() {
        foldingGutter?.foldAll()
    }

    func unfoldAll() {
        foldingGutter?.unfoldAll()
    }

    func foldLevel(_ level: Int) {
        foldingGutter?.foldLevel(level)
    }

    // MARK: - Macros (Run Multiple + External Command)

    func runMacroMultipleTimes() {
        runMacroDialog.onRun = { [weak self] macro, times in
            guard let tv = self?.currentEditor?.textView else { return }
            if let times = times {
                MacroManager.shared.playMacroMultipleTimes(macro, times: times, in: tv)
            } else {
                // Run until end of file: repeat until cursor no longer advances
                let maxIterations = 100_000
                var iterations = 0
                while iterations < maxIterations {
                    let beforePos = tv.selectedRange().location
                    MacroManager.shared.playMacro(macro, in: tv)
                    let afterPos = tv.selectedRange().location
                    let length = tv.textStorage?.length ?? 0
                    if afterPos >= length || afterPos == beforePos {
                        break
                    }
                    iterations += 1
                }
            }
        }
        runMacroDialog.showDialog(relativeTo: window)
    }

    func runExternalCommand() {
        externalCommandController.currentFilePath = { [weak self] in
            self?.tabManager.selectedTab?.filePath
        }
        externalCommandController.currentWord = { [weak self] in
            guard let tv = self?.currentEditor?.textView,
                  let textStorage = tv.textStorage else { return nil }
            let selectedRange = tv.selectedRange()
            // If there is a selection, use it as the "current word"
            if selectedRange.length > 0 {
                return (textStorage.string as NSString).substring(with: selectedRange)
            }
            // Otherwise, find the word around the cursor using NSString word boundaries
            let str = textStorage.string as NSString
            let loc = selectedRange.location
            guard loc <= str.length else { return nil }
            // Scan backwards for word start
            var start = loc
            while start > 0 {
                let c = str.character(at: start - 1)
                if let scalar = Unicode.Scalar(c), CharacterSet.alphanumerics.contains(scalar) || c == UInt16(UInt8(ascii: "_")) {
                    start -= 1
                } else {
                    break
                }
            }
            // Scan forwards for word end
            var end = loc
            while end < str.length {
                let c = str.character(at: end)
                if let scalar = Unicode.Scalar(c), CharacterSet.alphanumerics.contains(scalar) || c == UInt16(UInt8(ascii: "_")) {
                    end += 1
                } else {
                    break
                }
            }
            guard end > start else { return nil }
            return str.substring(with: NSRange(location: start, length: end - start))
        }
        externalCommandController.currentLine = { [weak self] in
            guard let tv = self?.currentEditor?.textView,
                  let textStorage = tv.textStorage else { return nil }
            let range = tv.selectedRange()
            let lineRange = (textStorage.string as NSString).lineRange(for: NSRange(location: range.location, length: 0))
            return (textStorage.string as NSString).substring(with: lineRange)
        }
        externalCommandController.onCommandOutput = { [weak self] output in
            self?.newDocument()
            self?.currentEditor?.textView.string = output
        }
        externalCommandController.showDialog(relativeTo: window)
    }

    func showColumnEditor() {
        columnEditorController.onInsertText = { [weak self] text in
            guard let tv = self?.currentEditor?.textView else { return }
            LineOperations.insertColumnText(in: tv, text: text)
        }
        columnEditorController.onInsertNumbers = { [weak self] start, step, radix, zeros, upper in
            guard let tv = self?.currentEditor?.textView else { return }
            LineOperations.insertColumnNumbers(in: tv, start: start, step: step, radix: radix, leadingZeros: zeros, uppercase: upper)
        }
        columnEditorController.showDialog(relativeTo: window)
    }

    private func registerCommandPaletteCommands(_ palette: CommandPaletteController) {
        palette.registerCommand(CommandItem(id: "newFile", title: "New File", category: "File", shortcut: "Cmd+N") { [weak self] in
            self?.newDocument()
        })
        palette.registerCommand(CommandItem(id: "openFile", title: "Open File", category: "File", shortcut: "Cmd+O") { [weak self] in
            self?.openDocument()
        })
        palette.registerCommand(CommandItem(id: "save", title: "Save", category: "File", shortcut: "Cmd+S") { [weak self] in
            self?.saveDocument()
        })
        palette.registerCommand(CommandItem(id: "closeTab", title: "Close Tab", category: "File", shortcut: "Cmd+W") { [weak self] in
            self?.window?.performClose(nil)
        })
        palette.registerCommand(CommandItem(id: "find", title: "Find", category: "Edit", shortcut: "Cmd+F") { [weak self] in
            self?.showFindBar()
        })
        palette.registerCommand(CommandItem(id: "replace", title: "Find and Replace", category: "Edit", shortcut: "Cmd+Opt+F") { [weak self] in
            self?.showFindAndReplace()
        })
        palette.registerCommand(CommandItem(id: "goToLine", title: "Go to Line", category: "Navigate", shortcut: "Cmd+L") { [weak self] in
            self?.goToLine()
        })
        palette.registerCommand(CommandItem(id: "toggleLineNumbers", title: "Toggle Line Numbers", category: "View") { [weak self] in
            guard let editor = self?.currentEditor else { return }
            editor.textView.showsLineNumbers.toggle()
        })
        palette.registerCommand(CommandItem(id: "toggleWordWrap", title: "Toggle Word Wrap", category: "View") { [weak self] in
            guard let editor = self?.currentEditor else { return }
            let tv = editor.textView
            let isWrapping = tv.textContainer?.widthTracksTextView ?? true
            if isWrapping {
                tv.textContainer?.widthTracksTextView = false
                tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = true
                editor.scrollView.hasHorizontalScroller = true
            } else {
                tv.textContainer?.widthTracksTextView = true
                tv.textContainer?.containerSize = NSSize(width: editor.scrollView.contentView.bounds.width, height: CGFloat.greatestFiniteMagnitude)
                tv.isHorizontallyResizable = false
                editor.scrollView.hasHorizontalScroller = false
            }
            tv.needsDisplay = true
            tv.needsLayout = true
        })
    }

    // MARK: - Panel Registration

    /// Registers all panels with PanelKit so layout is managed by PanelHostController.
    private func registerPanels() {
        functionListPanel.delegate = self

        // File browser — left sidebar
        let fileBrowserDescriptor = PanelDescriptor(
            id: "file-browser", title: "Files",
            position: .left, iconSystemName: "folder"
        )
        panelHost.addPanel(fileBrowserPanel, descriptor: fileBrowserDescriptor)

        // Function list — left sidebar (tabbed with file browser)
        let funcListDescriptor = PanelDescriptor(
            id: "function-list", title: "Functions",
            position: .left, iconSystemName: "function"
        )
        panelHost.addPanel(functionListPanel, descriptor: funcListDescriptor)

        // Search results — bottom panel
        let searchResultsDescriptor = PanelDescriptor(
            id: "search-results", title: "Search Results",
            position: .bottom, iconSystemName: "magnifyingglass"
        )
        panelHost.addPanel(searchResultsPanel, descriptor: searchResultsDescriptor)

        // Document list — left sidebar
        let docListDescriptor = PanelDescriptor(
            id: "document-list", title: "Documents",
            position: .left, iconSystemName: "doc.on.doc"
        )
        panelHost.addPanel(documentListPanel, descriptor: docListDescriptor)

        // Clipboard history — left sidebar
        let clipDescriptor = PanelDescriptor(
            id: "clipboard-history", title: "Clipboard",
            position: .left, iconSystemName: "doc.on.clipboard"
        )
        panelHost.addPanel(clipboardHistoryPanel, descriptor: clipDescriptor)

        // Markdown preview — right sidebar
        let markdownDescriptor = PanelDescriptor(
            id: "markdown-preview", title: "Markdown",
            position: .right, iconSystemName: "doc.richtext"
        )
        panelHost.addPanel(markdownPreviewController, descriptor: markdownDescriptor)
    }

    // MARK: - File Browser

    /// Toggles visibility of the file browser panel.
    func toggleFileBrowser() {
        panelHost.togglePanel(id: "file-browser")
    }

    /// Adds a root folder to the file browser and shows the panel if hidden.
    func addFolderToFileBrowser(_ url: URL) {
        fileBrowserPanel.addRootFolder(url)
        if !panelHost.isPanelVisible(id: "file-browser") {
            panelHost.showPanel(id: "file-browser")
        }
    }

    // MARK: - Function List Panel

    /// Toggles visibility of the function list side panel.
    func toggleFunctionList() {
        panelHost.togglePanel(id: "function-list")
        // Update content when becoming visible
        if panelHost.isPanelVisible(id: "function-list") {
            updateFunctionListContent()
        }
    }

    /// Updates the function list panel with the current editor's text and language.
    private func updateFunctionListContent() {
        guard panelHost.isPanelVisible(id: "function-list") else { return }

        let languageId: String
        if let tab = tabManager.selectedTab, let url = tab.filePath {
            languageId = detectLanguageId(for: url)
        } else {
            languageId = ""
        }

        functionListPanel.languageId = languageId
        functionListPanel.sourceText = currentEditor?.text ?? ""
    }

    /// Returns the language ID string for SyntaxKit from a file URL.
    private func detectLanguageId(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty {
            let name = url.lastPathComponent.lowercased()
            if name == "makefile" || name == "gnumakefile" {
                return LanguageRegistry.shared.language(forID: "makefile")?.id ?? "makefile"
            }
        }
        if let lang = LanguageRegistry.shared.language(forExtension: ext) {
            return lang.id
        }
        return "text"
    }

    // MARK: - Search Results Panel

    /// Searches all open documents for the given pattern and displays results
    /// in the search results panel.
    ///
    /// - Parameters:
    ///   - pattern: The search pattern (plain text or regex depending on options).
    ///   - options: The search options controlling match behavior.
    func findInAllOpenDocuments(pattern: String, options: SearchOptions) {
        let engine = SearchEngine()
        var allResults: [(String, URL?, [SearchResult])] = []

        for tab in tabManager.tabs {
            guard let editor = editors[tab.id] else { continue }
            let text = editor.text
            let matches = engine.find(pattern: pattern, in: text, options: options)
            if !matches.isEmpty {
                allResults.append((tab.title, tab.filePath, matches))
            }
        }

        searchResultsPanel.displayResultGroups(allResults)
        panelHost.showPanel(id: "search-results")
    }

    /// Displays the search results panel with the given multi-file results.
    ///
    /// Shows the panel if hidden and populates it with results.
    func showSearchResults(_ results: [FileSearchResult]) {
        searchResultsPanel.displayResults(results)
        panelHost.showPanel(id: "search-results")
    }

    /// Toggles visibility of the search results panel.
    func toggleSearchResultsPanel() {
        panelHost.togglePanel(id: "search-results")
    }

    // MARK: - Document List Panel

    /// Toggles visibility of the document list panel.
    func toggleDocumentList() {
        panelHost.togglePanel(id: "document-list")
        if panelHost.isPanelVisible(id: "document-list") {
            refreshDocumentList()
        }
    }

    /// Refreshes the document list with the current set of open tabs.
    private func refreshDocumentList() {
        let entries: [DocumentEntry] = tabManager.tabs.map { tab in
            let filename = tab.title
            let path = tab.filePath?.path ?? "Untitled"
            let isModified = tab.isModified
            let language: String
            if let url = tab.filePath {
                language = detectLanguage(for: url)
            } else {
                language = "Plain Text"
            }
            return DocumentEntry(filename: filename, path: path, isModified: isModified, language: language)
        }
        documentListPanel.entries = entries
    }

    // MARK: - Clipboard History Panel

    /// Toggles visibility of the clipboard history panel.
    func toggleClipboardHistory() {
        panelHost.togglePanel(id: "clipboard-history")
    }

    // MARK: - Markdown Preview Panel

    /// Toggles visibility of the Markdown preview panel.
    func toggleMarkdownPreview() {
        panelHost.togglePanel(id: "markdown-preview")
        if panelHost.isPanelVisible(id: "markdown-preview") {
            updateMarkdownPreview()
        }
    }

    /// Updates the Markdown preview with the current editor's text.
    /// Shows preview whenever the panel is visible, regardless of file extension.
    func updateMarkdownPreview() {
        guard panelHost.isPanelVisible(id: "markdown-preview") else { return }

        // Detect dark mode from the app's effective appearance
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        markdownPreviewController.isDarkMode = isDark
        markdownPreviewController.updatePreview(markdown: currentEditor?.text ?? "")
    }

    // MARK: - SearchResultsPanelDelegate

    func searchResultsPanel(
        _ panel: SearchResultsPanel,
        didSelectResult result: SearchResult,
        inFile url: URL?
    ) {
        if let url = url {
            openFile(at: url)
        }

        // Scroll to the line in the current editor.
        guard let editor = currentEditor else { return }
        let text = editor.text as NSString
        var currentLine = 1
        var lineStart = 0

        // Walk through the text to find the target line.
        while currentLine < result.lineNumber, lineStart < text.length {
            let lineRange = text.lineRange(
                for: NSRange(location: lineStart, length: 0)
            )
            lineStart = NSMaxRange(lineRange)
            currentLine += 1
        }

        if lineStart < text.length || currentLine == result.lineNumber {
            let targetRange = NSRange(location: lineStart, length: 0)
            editor.textView.setSelectedRange(targetRange)
            editor.textView.scrollRangeToVisible(targetRange)
            editor.textView.showFindIndicator(for: NSRange(
                location: lineStart,
                length: min(result.matchedText.count, text.length - lineStart)
            ))
        }
    }

    // MARK: - Comment Toggle

    /// Returns the LanguageDefinition for the current file based on its extension.
    func currentLanguage() -> LanguageDefinition? {
        guard let url = tabManager.selectedTab?.filePath else { return nil }
        let ext = url.pathExtension.lowercased()
        return LanguageRegistry.shared.language(forExtension: ext)
    }

    func toggleLineComment() {
        guard let editor = currentEditor,
              let lang = currentLanguage() else { return }
        guard let prefix = lang.lineComment else { return }
        CommentToggle.toggleLineComment(in: editor.textView, commentPrefix: prefix)
    }

    func toggleBlockComment() {
        guard let editor = currentEditor,
              let lang = currentLanguage() else { return }
        guard let start = lang.blockCommentStart, let end = lang.blockCommentEnd else { return }
        CommentToggle.toggleBlockComment(in: editor.textView, start: start, end: end)
    }

    // MARK: - Bookmark Navigation

    func toggleBookmark() {
        guard let editor = currentEditor else { return }
        let line = editor.textView.currentLineNumber()
        editor.bookmarkManager.toggleBookmark(at: line)
    }

    func nextBookmark() {
        guard let editor = currentEditor else { return }
        let line = editor.textView.currentLineNumber()
        guard let target = editor.bookmarkManager.nextBookmark(after: line) else { return }
        editor.textView.scrollToLine(target)
    }

    func previousBookmark() {
        guard let editor = currentEditor else { return }
        let line = editor.textView.currentLineNumber()
        guard let target = editor.bookmarkManager.previousBookmark(before: line) else { return }
        editor.textView.scrollToLine(target)
    }

    func clearAllBookmarks() {
        guard let editor = currentEditor else { return }
        editor.bookmarkManager.clearAllBookmarks()
    }

    // MARK: - Zoom Restore

    func zoomRestore() {
        guard let editor = currentEditor else { return }
        editor.textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    // MARK: - Sync Scroll Toggle

    func toggleSyncScroll() {
        guard let editor = currentEditor else { return }
        if _splitCtrl == nil {
            _splitCtrl = SplitEditorController(primaryEditor: editor)
        }
        _splitCtrl?.isSyncScrollEnabled.toggle()
    }

    // MARK: - Session Save / Restore

    /// Builds a ``SessionData`` snapshot from the current window state.
    ///
    /// Captures fold states, bookmarks, and color tags for each tab so the
    /// session can be fully restored later.
    func buildSessionData() -> SessionData {
        let tabStates = tabManager.tabs.enumerated().map { (index, tab) -> SessionData.TabState in
            let editor = editors[tab.id]
            let gutterViews: [FoldingGutter] = (editor?.scrollView.subviews ?? []).compactMap { $0 as? FoldingGutter }
            let gutter: FoldingGutter? = gutterViews.first
            let folds: [Int]? = {
                guard let g = gutter, !g.collapsedLines.isEmpty else { return nil }
                return g.collapsedLines.sorted()
            }()
            let bookmarks: [Int]? = {
                guard let bm = editor?.bookmarkManager, bm.hasBookmarks else { return nil }
                return bm.sortedBookmarks
            }()
            return SessionData.TabState(
                filePath: tab.filePath?.path ?? "",
                cursorPosition: editor?.textView.selectedRange().location ?? 0,
                scrollOffset: Double(editor?.scrollView.contentView.bounds.origin.y ?? CGFloat(0)),
                isActive: index == tabManager.selectedIndex,
                collapsedLines: folds,
                bookmarkedLines: bookmarks,
                colorTag: tab.colorTag > 0 ? tab.colorTag : nil,
                encodingName: nil,
                lineEndingRaw: nil
            )
        }
        return SessionData(tabs: tabStates, windowFrame: window?.frame.debugDescription ?? "")
    }

    /// Restores a previously saved session, opening files and re-applying
    /// fold states, bookmarks, and color tags.
    func restoreSession(_ session: SessionData) {
        var activeIndex: Int?

        for (index, tabState) in session.tabs.enumerated() {
            guard !tabState.filePath.isEmpty else { continue }
            let url = URL(fileURLWithPath: tabState.filePath)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            openFile(at: url)

            guard let tab = tabManager.tabs.last else { continue }
            let editor = editors[tab.id]

            // Restore color tag
            if let colorTag = tabState.colorTag {
                tab.colorTag = colorTag
            }

            // Restore bookmarks
            if let bookmarks = tabState.bookmarkedLines {
                for line in bookmarks {
                    editor?.bookmarkManager.toggleBookmark(at: line)
                }
            }

            // Restore cursor position
            if let tv = editor?.textView {
                let pos = min(tabState.cursorPosition, tv.string.count)
                tv.setSelectedRange(NSRange(location: pos, length: 0))
            }

            // Restore scroll offset
            if let sv = editor?.scrollView {
                let maxY = sv.documentView?.bounds.height ?? 0
                let clampedY = min(tabState.scrollOffset, max(maxY - sv.contentView.bounds.height, 0))
                sv.contentView.scroll(to: NSPoint(x: 0, y: clampedY))
                sv.reflectScrolledClipView(sv.contentView)
            }

            // Restore fold states (delayed to allow gutter setup)
            if let folds = tabState.collapsedLines {
                let editorRef = editor
                DispatchQueue.main.async {
                    if let gutter = editorRef?.scrollView.subviews.compactMap({ $0 as? FoldingGutter }).first {
                        for line in folds {
                            gutter.collapsedLines.insert(line)
                        }
                    }
                }
            }

            if tabState.isActive {
                activeIndex = index
            }
        }

        // Switch to the previously active tab
        if let activeIndex = activeIndex, tabManager.tabs.indices.contains(activeIndex) {
            tabManager.selectTab(at: activeIndex)
            if let tab = tabManager.selectedTab {
                switchToEditor(for: tab)
            }
        }

        syncTabBarView()
    }

    // MARK: - Helpers

    private func encodingName(for encoding: String.Encoding) -> String {
        return EncodingManager.encodingName(encoding)
    }

    private func detectLanguage(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty {
            let name = url.lastPathComponent.lowercased()
            if name == "makefile" || name == "gnumakefile" {
                return LanguageRegistry.shared.language(forID: "makefile")?.displayName ?? "Makefile"
            }
        }
        if let lang = LanguageRegistry.shared.language(forExtension: ext) {
            return lang.displayName
        }
        return "Plain Text"
    }
}

// MARK: - FileBrowserPanelDelegate

@available(macOS 13.0, *)
extension MainWindowController: FileBrowserPanelDelegate {
    func fileBrowser(_ panel: FileBrowserPanel, didSelectFile url: URL) {
        openFile(at: url)
    }
}

// MARK: - FunctionListPanelDelegate

@available(macOS 13.0, *)
extension MainWindowController: FunctionListPanelDelegate {
    func functionList(_ panel: FunctionListPanel, didSelectSymbol symbol: SymbolInfo) {
        // Navigate to the symbol's line (lineNumber is 0-based, scrollToLine is 1-based)
        currentEditor?.textView.scrollToLine(symbol.lineNumber + 1)

        // Place cursor at the beginning of the symbol's line
        let text = currentEditor?.textView.string ?? ""
        let lines = text.components(separatedBy: "\n")
        guard symbol.lineNumber < lines.count else { return }

        var charIndex = 0
        for i in 0..<symbol.lineNumber {
            charIndex += lines[i].count + 1  // +1 for newline
        }
        let nsString = text as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: min(charIndex, nsString.length), length: 0))
        currentEditor?.textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
        currentEditor?.textView.scrollRangeToVisible(NSRange(location: lineRange.location, length: 0))
    }
}

// MARK: - DocumentListPanelDelegate

@available(macOS 13.0, *)
extension MainWindowController {
    func documentList(_ panel: DocumentListPanel, didSelectTabAt index: Int) {
        guard tabManager.tabs.indices.contains(index) else { return }
        tabManager.selectTab(at: index)
        if let tab = tabManager.selectedTab {
            switchToEditor(for: tab)
        }
    }
}

// MARK: - ClipboardHistoryPanelDelegate

@available(macOS 13.0, *)
extension MainWindowController {
    func clipboardHistory(_ panel: ClipboardHistoryPanel, didSelectEntry text: String) {
        guard let editor = currentEditor else { return }
        let textView = editor.textView
        let selectedRange = textView.selectedRange()
        textView.insertText(text, replacementRange: selectedRange)
    }
}

// MARK: - EOL Conversion

@available(macOS 13.0, *)
extension MainWindowController {
    /// Converts all line endings in the current document to the specified type.
    func convertLineEnding(to ending: String) {
        guard let editor = currentEditor else { return }
        var text = editor.text
        // Normalize all endings to LF first (CRLF before CR to avoid double replacement)
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        // Convert to target
        switch ending {
        case "CRLF": text = text.replacingOccurrences(of: "\n", with: "\r\n")
        case "CR": text = text.replacingOccurrences(of: "\n", with: "\r")
        default: break // LF already done
        }
        editor.text = text
        statusBar.update(
            line: statusBar.line,
            column: statusBar.column,
            encoding: statusBar.encoding,
            lineEnding: ending,
            language: statusBar.language
        )
    }
}

// MARK: - StatusBarViewDelegate

@available(macOS 13.0, *)
extension MainWindowController: StatusBarViewDelegate {
    func statusBar(_ bar: StatusBarView, didChangeEncoding encoding: String) {
        setEncoding(encoding)
    }

    func statusBar(_ bar: StatusBarView, didChangeLineEnding ending: String) {
        convertLineEnding(to: ending)
    }

    func statusBar(_ bar: StatusBarView, didChangeLanguage language: String) {
        // Language change is handled elsewhere; no-op for now.
    }

    func statusBar(_ bar: StatusBarView, didChangeIndentation indentation: String) {
        // Indentation change is handled elsewhere; no-op for now.
    }
}

// MARK: - Encoding Operations

@available(macOS 13.0, *)
extension MainWindowController {

    /// Cache of raw file data per tab, used for re-interpreting with a different encoding.
    private static var rawDataCache = [UUID: Data]()

    /// Store raw data for a tab (called during file open).
    func cacheRawData(_ data: Data, for tabID: UUID) {
        MainWindowController.rawDataCache[tabID] = data
    }

    /// Retrieve cached raw data for a tab.
    func cachedRawData(for tabID: UUID) -> Data? {
        MainWindowController.rawDataCache[tabID]
    }

    /// Remove cached raw data (called when tab is closed).
    func removeCachedRawData(for tabID: UUID) {
        MainWindowController.rawDataCache.removeValue(forKey: tabID)
    }

    /// Re-read the current file's bytes using the specified encoding.
    ///
    /// This does NOT convert the content — it re-interprets the raw bytes
    /// as if the file were saved in the selected encoding.
    func setEncoding(_ encodingName: String) {
        guard let tab = tabManager.selectedTab,
              let editor = currentEditor,
              let encoding = EncodingManager.encoding(forName: encodingName) else { return }

        // If we have a file on disk, re-read it with the new encoding
        if let url = tab.filePath {
            do {
                let data = try Data(contentsOf: url)
                if let content = EncodingManager.reinterpret(data: data, as: encoding) {
                    editor.text = content
                    cacheRawData(data, for: tab.id)
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Encoding Error"
                    alert.informativeText = "Cannot decode the file using \(encodingName)."
                    alert.alertStyle = .warning
                    alert.runModal()
                    return
                }
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
                return
            }
        } else if let rawData = cachedRawData(for: tab.id) {
            // For unsaved files with cached data, re-interpret
            if let content = EncodingManager.reinterpret(data: rawData, as: encoding) {
                editor.text = content
            }
        }

        // Update status bar
        statusBar.update(
            line: statusBar.line,
            column: statusBar.column,
            encoding: encodingName,
            lineEnding: statusBar.lineEnding,
            language: statusBar.language
        )
    }

    /// Convert the current document's content to a new encoding (for saving).
    ///
    /// This takes the current text (in memory as a Swift String) and validates
    /// that it can be encoded in the target encoding. The encoding is then used
    /// for subsequent saves.
    func convertEncoding(to encodingName: String) {
        guard let tab = tabManager.selectedTab,
              let editor = currentEditor,
              let encoding = EncodingManager.encoding(forName: encodingName) else { return }

        let text = editor.text

        // Verify the text can be represented in the target encoding
        guard let convertedData = EncodingManager.convert(text: text, to: encoding) else {
            let alert = NSAlert()
            alert.messageText = "Conversion Error"
            alert.informativeText = "The document contains characters that cannot be represented in \(encodingName). Some characters may be lost."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Convert with Loss")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }

            // Lossy conversion
            if let lossyData = text.data(using: encoding, allowLossyConversion: true) {
                cacheRawData(lossyData, for: tab.id)
                // Re-decode to show what the user will get
                if let roundTrip = String(data: lossyData, encoding: encoding) {
                    editor.text = roundTrip
                }
            }

            // Update status bar even for lossy conversion
            statusBar.update(
                line: statusBar.line,
                column: statusBar.column,
                encoding: encodingName,
                lineEnding: statusBar.lineEnding,
                language: statusBar.language
            )
            tab.isModified = true
            syncTabBarView()
            return
        }

        // Cache the converted data
        cacheRawData(convertedData, for: tab.id)

        // Update status bar
        statusBar.update(
            line: statusBar.line,
            column: statusBar.column,
            encoding: encodingName,
            lineEnding: statusBar.lineEnding,
            language: statusBar.language
        )

        // Mark as modified so the user knows the encoding changed
        tab.isModified = true
        syncTabBarView()
    }
}
