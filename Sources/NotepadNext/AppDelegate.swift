import AppKit
import TextCore
import EditorKit
import FileKit
import TabKit
import SearchKit
import SyntaxKit
import CommonKit
import NotepadNextCore

@available(macOS 13.0, *)
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {

    var mainWindowController: MainWindowController?
    var cliArguments: CLIArguments?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)

        // Handle CLI arguments
        if let args = cliArguments {
            handleCLIArguments(args)
        } else {
            // Restore previous session when launched without CLI arguments
            if let session = SessionManager.shared.loadSession(), !session.tabs.isEmpty {
                mainWindowController?.restoreSession(session)
            }
        }

        NSApp.activate(ignoringOtherApps: true)

        // Check for updates (silent, once per day)
        UpdateChecker.shared.checkOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Save session state before quitting
        if let sessionData = mainWindowController?.buildSessionData() {
            SessionManager.shared.saveSession(sessionData)
        }
    }

    private func handleCLIArguments(_ args: CLIArguments) {
        for filePath in args.files {
            let url = URL(fileURLWithPath: filePath)
            mainWindowController?.openFile(at: url)
        }

        // Go to specific line if requested
        if let line = args.goToLine, line > 0,
           let editor = mainWindowController?.currentEditor {
            let text = editor.text as NSString
            var currentLine = 1
            var location = 0
            while currentLine < line && location < text.length {
                if text.character(at: location) == 0x0A { currentLine += 1 }
                location += 1
            }
            let range = NSRange(location: min(location, text.length), length: 0)
            editor.textView.setSelectedRange(range)
            editor.textView.scrollRangeToVisible(range)
        }

        // Set read-only mode if requested
        if args.readOnly, let editor = mainWindowController?.currentEditor {
            editor.textView.isEditable = false
        }
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls {
            mainWindowController?.openFile(at: url)
        }
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindowController?.showWindow(nil)
        }
        return true
    }

    // MARK: - Main Menu

    func setupMainMenu() {
        let mainMenu = NSMenu()

        mainMenu.addItem(buildAppMenu())
        mainMenu.addItem(buildFileMenu())
        mainMenu.addItem(buildEditMenu())
        mainMenu.addItem(buildViewMenu())
        mainMenu.addItem(buildFormatMenu())

        let searchMenuItem = buildSearchMenu()
        mainMenu.addItem(searchMenuItem)

        let toolsMenuItem = buildToolsMenu()
        mainMenu.addItem(toolsMenuItem)

        let windowMenuItem = buildWindowMenu()
        mainMenu.addItem(windowMenuItem)

        mainMenu.addItem(buildHelpMenu())

        NSApp.mainMenu = mainMenu

        // Enable macOS standard window management
        if let windowMenu = windowMenuItem.submenu {
            NSApp.windowsMenu = windowMenu
        }
    }

    // MARK: - App Menu

    private func buildAppMenu() -> NSMenuItem {
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        let aboutItem = NSMenuItem(
            title: "About \(CommonKit.appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(aboutItem)

        let checkUpdateItem = NSMenuItem(
            title: "Check for Updates\u{2026}",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkUpdateItem.target = self
        appMenu.addItem(checkUpdateItem)
        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(showPreferences(_:)),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide \(CommonKit.appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(showAllItem)
        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(CommonKit.appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        return appMenuItem
    }

    // MARK: - File Menu

    private func buildFileMenu() -> NSMenuItem {
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")

        let newItem = NSMenuItem(
            title: "New",
            action: #selector(newDocument(_:)),
            keyEquivalent: "n"
        )
        newItem.target = self
        fileMenu.addItem(newItem)

        let newTabItem = NSMenuItem(
            title: "New Tab",
            action: #selector(newDocument(_:)),
            keyEquivalent: "t"
        )
        newTabItem.target = self
        fileMenu.addItem(newTabItem)

        let openItem = NSMenuItem(
            title: "Open\u{2026}",
            action: #selector(openDocument(_:)),
            keyEquivalent: "o"
        )
        openItem.target = self
        fileMenu.addItem(openItem)
        fileMenu.addItem(.separator())

        let saveItem = NSMenuItem(
            title: "Save",
            action: #selector(saveDocument(_:)),
            keyEquivalent: "s"
        )
        saveItem.target = self
        fileMenu.addItem(saveItem)

        let saveAsItem = NSMenuItem(
            title: "Save As\u{2026}",
            action: #selector(saveDocumentAs(_:)),
            keyEquivalent: "S"
        )
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        saveAsItem.target = self
        fileMenu.addItem(saveAsItem)

        let saveCopyAsItem = NSMenuItem(
            title: "Save a Copy As\u{2026}",
            action: #selector(saveCopyAs(_:)),
            keyEquivalent: ""
        )
        saveCopyAsItem.target = self
        fileMenu.addItem(saveCopyAsItem)
        fileMenu.addItem(.separator())

        let reloadItem = NSMenuItem(
            title: "Reload from Disk",
            action: #selector(reloadFromDisk(_:)),
            keyEquivalent: "R"
        )
        reloadItem.keyEquivalentModifierMask = [.command, .shift]
        reloadItem.target = self
        fileMenu.addItem(reloadItem)

        let renameItem = NSMenuItem(
            title: "Rename\u{2026}",
            action: #selector(renameFile(_:)),
            keyEquivalent: ""
        )
        renameItem.target = self
        fileMenu.addItem(renameItem)
        fileMenu.addItem(.separator())

        let openFolderItem = NSMenuItem(
            title: "Open Containing Folder",
            action: #selector(openContainingFolder(_:)),
            keyEquivalent: ""
        )
        openFolderItem.target = self
        fileMenu.addItem(openFolderItem)

        let openTerminalItem = NSMenuItem(
            title: "Open Terminal Here",
            action: #selector(openTerminalHere(_:)),
            keyEquivalent: ""
        )
        openTerminalItem.target = self
        fileMenu.addItem(openTerminalItem)
        fileMenu.addItem(.separator())

        let printItem = NSMenuItem(
            title: "Print\u{2026}",
            action: #selector(printDocument(_:)),
            keyEquivalent: "p"
        )
        printItem.target = self
        fileMenu.addItem(printItem)
        fileMenu.addItem(.separator())

        let closeItem = NSMenuItem(
            title: "Close Tab",
            action: #selector(closeCurrentTab(_:)),
            keyEquivalent: "w"
        )
        closeItem.target = self
        fileMenu.addItem(closeItem)

        fileMenuItem.submenu = fileMenu
        return fileMenuItem
    }

    // MARK: - Edit Menu

    private func buildEditMenu() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())

        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(pasteItem)
        editMenu.addItem(.separator())

        let selectAllItem = NSMenuItem(
            title: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editMenu.addItem(selectAllItem)
        editMenu.addItem(.separator())

        // Multi-cursor occurrence selection
        let selectAllOccurrencesItem = NSMenuItem(
            title: "Select All Occurrences",
            action: #selector(selectAllOccurrences(_:)),
            keyEquivalent: "l"
        )
        selectAllOccurrencesItem.keyEquivalentModifierMask = [.command, .shift]
        selectAllOccurrencesItem.target = self
        editMenu.addItem(selectAllOccurrencesItem)

        let selectNextOccurrenceItem = NSMenuItem(
            title: "Select Next Occurrence",
            action: #selector(selectNextOccurrence(_:)),
            keyEquivalent: "d"
        )
        selectNextOccurrenceItem.keyEquivalentModifierMask = .command
        selectNextOccurrenceItem.target = self
        editMenu.addItem(selectNextOccurrenceItem)

        let skipAndSelectNextItem = NSMenuItem(
            title: "Skip and Select Next",
            action: #selector(skipAndSelectNext(_:)),
            keyEquivalent: "k"
        )
        skipAndSelectNextItem.keyEquivalentModifierMask = [.command, .shift]
        skipAndSelectNextItem.target = self
        editMenu.addItem(skipAndSelectNextItem)

        let undoLastMultiSelectItem = NSMenuItem(
            title: "Undo Last Selection",
            action: #selector(undoLastMultiSelect(_:)),
            keyEquivalent: "u"
        )
        undoLastMultiSelectItem.keyEquivalentModifierMask = [.command, .control]
        undoLastMultiSelectItem.target = self
        editMenu.addItem(undoLastMultiSelectItem)
        editMenu.addItem(.separator())

        let searchInternetItem = NSMenuItem(
            title: "Search on Internet",
            action: #selector(searchOnInternet(_:)),
            keyEquivalent: ""
        )
        searchInternetItem.target = self
        editMenu.addItem(searchInternetItem)
        editMenu.addItem(.separator())

        // Insert Date/Time submenu
        let dateTimeMenuItem = NSMenuItem(title: "Insert Date/Time", action: nil, keyEquivalent: "")
        let dateTimeMenu = NSMenu(title: "Insert Date/Time")

        let shortDateItem = NSMenuItem(title: "Short (MM/dd/yyyy)", action: #selector(insertDateTimeShort(_:)), keyEquivalent: "")
        shortDateItem.target = self
        dateTimeMenu.addItem(shortDateItem)

        let longDateItem = NSMenuItem(title: "Long (Month d, yyyy h:mm a)", action: #selector(insertDateTimeLong(_:)), keyEquivalent: "")
        longDateItem.target = self
        dateTimeMenu.addItem(longDateItem)

        let isoDateItem = NSMenuItem(title: "ISO 8601", action: #selector(insertDateTimeISO(_:)), keyEquivalent: "")
        isoDateItem.target = self
        dateTimeMenu.addItem(isoDateItem)

        dateTimeMenuItem.submenu = dateTimeMenu
        editMenu.addItem(dateTimeMenuItem)
        editMenu.addItem(.separator())

        // Comment submenu
        let commentMenuItem = NSMenuItem(title: "Comment", action: nil, keyEquivalent: "")
        let commentMenu = NSMenu(title: "Comment")

        let toggleLineCommentItem = NSMenuItem(title: "Toggle Line Comment", action: #selector(toggleLineComment(_:)), keyEquivalent: "/")
        toggleLineCommentItem.keyEquivalentModifierMask = .command
        toggleLineCommentItem.target = self
        commentMenu.addItem(toggleLineCommentItem)

        let toggleBlockCommentItem = NSMenuItem(title: "Toggle Block Comment", action: #selector(toggleBlockComment(_:)), keyEquivalent: "/")
        toggleBlockCommentItem.keyEquivalentModifierMask = [.command, .shift]
        toggleBlockCommentItem.target = self
        commentMenu.addItem(toggleBlockCommentItem)

        commentMenuItem.submenu = commentMenu
        editMenu.addItem(commentMenuItem)
        editMenu.addItem(.separator())

        // Case Conversion submenu
        let caseMenuItem = NSMenuItem(title: "Case Conversion", action: nil, keyEquivalent: "")
        let caseMenu = NSMenu(title: "Case Conversion")

        let upperCaseItem = NSMenuItem(title: "UPPERCASE", action: #selector(toUpperCase(_:)), keyEquivalent: "U")
        upperCaseItem.keyEquivalentModifierMask = [.command, .shift]
        upperCaseItem.target = self
        caseMenu.addItem(upperCaseItem)

        let lowerCaseItem = NSMenuItem(title: "lowercase", action: #selector(toLowerCase(_:)), keyEquivalent: "u")
        lowerCaseItem.keyEquivalentModifierMask = .command
        lowerCaseItem.target = self
        caseMenu.addItem(lowerCaseItem)

        let titleCaseItem = NSMenuItem(title: "Title Case", action: #selector(toTitleCase(_:)), keyEquivalent: "")
        titleCaseItem.target = self
        caseMenu.addItem(titleCaseItem)

        let invertCaseItem = NSMenuItem(title: "Invert Case", action: #selector(toggleCase(_:)), keyEquivalent: "")
        invertCaseItem.target = self
        caseMenu.addItem(invertCaseItem)

        let camelCaseItem = NSMenuItem(title: "camelCase", action: #selector(toCamelCase(_:)), keyEquivalent: "")
        camelCaseItem.target = self
        caseMenu.addItem(camelCaseItem)

        let snakeCaseItem = NSMenuItem(title: "snake_case", action: #selector(toSnakeCase(_:)), keyEquivalent: "")
        snakeCaseItem.target = self
        caseMenu.addItem(snakeCaseItem)

        let sentenceCaseItem = NSMenuItem(title: "Sentence case", action: #selector(sentenceCase(_:)), keyEquivalent: "")
        sentenceCaseItem.target = self
        caseMenu.addItem(sentenceCaseItem)

        let randomCaseItem = NSMenuItem(title: "RaNdOm CaSe", action: #selector(randomCase(_:)), keyEquivalent: "")
        randomCaseItem.target = self
        caseMenu.addItem(randomCaseItem)

        caseMenuItem.submenu = caseMenu
        editMenu.addItem(caseMenuItem)
        editMenu.addItem(.separator())

        // Column Editor
        let columnEditorItem = NSMenuItem(
            title: "Column Editor\u{2026}",
            action: #selector(showColumnEditor(_:)),
            keyEquivalent: "c"
        )
        columnEditorItem.keyEquivalentModifierMask = [.command, .option]
        columnEditorItem.target = self
        editMenu.addItem(columnEditorItem)
        editMenu.addItem(.separator())

        // Line Operations submenu
        let lineOpsItem = NSMenuItem(title: "Line Operations", action: nil, keyEquivalent: "")
        lineOpsItem.submenu = buildLineOperationsMenu()
        editMenu.addItem(lineOpsItem)

        // Copy to Clipboard submenu
        let copyClipItem = NSMenuItem(title: "Copy to Clipboard", action: nil, keyEquivalent: "")
        copyClipItem.submenu = buildCopyToClipboardMenu()
        editMenu.addItem(copyClipItem)

        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    // MARK: - View Menu

    private func buildViewMenu() -> NSMenuItem {
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let toggleLineNumbersItem = NSMenuItem(
            title: "Toggle Line Numbers",
            action: #selector(toggleLineNumbers(_:)),
            keyEquivalent: ""
        )
        toggleLineNumbersItem.target = self
        viewMenu.addItem(toggleLineNumbersItem)

        let wordWrapItem = NSMenuItem(
            title: "Word Wrap",
            action: #selector(toggleWordWrap(_:)),
            keyEquivalent: ""
        )
        wordWrapItem.target = self
        viewMenu.addItem(wordWrapItem)
        viewMenu.addItem(.separator())

        let zoomInItem = NSMenuItem(
            title: "Zoom In",
            action: #selector(zoomIn(_:)),
            keyEquivalent: "+"
        )
        zoomInItem.keyEquivalentModifierMask = .command
        zoomInItem.target = self
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(
            title: "Zoom Out",
            action: #selector(zoomOut(_:)),
            keyEquivalent: "-"
        )
        zoomOutItem.keyEquivalentModifierMask = .command
        zoomOutItem.target = self
        viewMenu.addItem(zoomOutItem)

        let zoomRestoreItem = NSMenuItem(
            title: "Zoom Restore",
            action: #selector(zoomRestore(_:)),
            keyEquivalent: "0"
        )
        zoomRestoreItem.keyEquivalentModifierMask = .command
        zoomRestoreItem.target = self
        viewMenu.addItem(zoomRestoreItem)
        viewMenu.addItem(.separator())

        let syncScrollItem = NSMenuItem(
            title: "Synchronize Scrolling",
            action: #selector(toggleSyncScroll(_:)),
            keyEquivalent: ""
        )
        syncScrollItem.target = self
        viewMenu.addItem(syncScrollItem)
        viewMenu.addItem(.separator())

        // Show Whitespace submenu
        let whitespaceMenuItem = NSMenuItem(title: "Show Whitespace", action: nil, keyEquivalent: "")
        let whitespaceMenu = NSMenu(title: "Show Whitespace")

        for mode in WhitespaceLayoutManager.WhitespaceMode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(setWhitespaceMode(_:)),
                keyEquivalent: ""
            )
            item.tag = mode.rawValue
            item.target = self
            whitespaceMenu.addItem(item)
        }

        whitespaceMenuItem.submenu = whitespaceMenu
        viewMenu.addItem(whitespaceMenuItem)
        viewMenu.addItem(.separator())

        let toggleFileBrowserItem = NSMenuItem(
            title: "Toggle File Browser",
            action: #selector(toggleFileBrowser(_:)),
            keyEquivalent: "E"
        )
        toggleFileBrowserItem.keyEquivalentModifierMask = [.command, .shift]
        toggleFileBrowserItem.target = self
        viewMenu.addItem(toggleFileBrowserItem)

        let functionListItem = NSMenuItem(
            title: "Toggle Function List",
            action: #selector(toggleFunctionList(_:)),
            keyEquivalent: "F"
        )
        functionListItem.keyEquivalentModifierMask = [.command, .shift]
        functionListItem.target = self
        viewMenu.addItem(functionListItem)

        let searchResultsItem = NSMenuItem(
            title: "Search Results",
            action: #selector(toggleSearchResultsPanel(_:)),
            keyEquivalent: ""
        )
        searchResultsItem.target = self
        viewMenu.addItem(searchResultsItem)

        let documentListItem = NSMenuItem(
            title: "Toggle Document List",
            action: #selector(toggleDocumentList(_:)),
            keyEquivalent: "D"
        )
        documentListItem.keyEquivalentModifierMask = [.command, .shift]
        documentListItem.target = self
        viewMenu.addItem(documentListItem)

        let clipboardHistoryItem = NSMenuItem(
            title: "Toggle Clipboard History",
            action: #selector(toggleClipboardHistory(_:)),
            keyEquivalent: ""
        )
        clipboardHistoryItem.target = self
        viewMenu.addItem(clipboardHistoryItem)

        let markdownPreviewItem = NSMenuItem(
            title: "Markdown Preview",
            action: #selector(toggleMarkdownPreview(_:)),
            keyEquivalent: "M"
        )
        markdownPreviewItem.keyEquivalentModifierMask = [.command, .shift]
        markdownPreviewItem.target = self
        viewMenu.addItem(markdownPreviewItem)
        viewMenu.addItem(.separator())

        // Fold controls
        let foldAllItem = NSMenuItem(
            title: "Fold All",
            action: #selector(foldAll(_:)),
            keyEquivalent: ""
        )
        foldAllItem.target = self
        viewMenu.addItem(foldAllItem)

        let unfoldAllItem = NSMenuItem(
            title: "Unfold All",
            action: #selector(unfoldAll(_:)),
            keyEquivalent: ""
        )
        unfoldAllItem.target = self
        viewMenu.addItem(unfoldAllItem)

        // Fold Level submenu (levels 1 through 8)
        let foldLevelMenuItem = NSMenuItem(title: "Fold Level", action: nil, keyEquivalent: "")
        let foldLevelMenu = NSMenu(title: "Fold Level")
        for level in 1...8 {
            let item = NSMenuItem(
                title: "Level \(level)",
                action: #selector(foldLevel(_:)),
                keyEquivalent: ""
            )
            item.tag = level
            item.target = self
            foldLevelMenu.addItem(item)
        }
        foldLevelMenuItem.submenu = foldLevelMenu
        viewMenu.addItem(foldLevelMenuItem)
        viewMenu.addItem(.separator())

        let fullScreenItem = NSMenuItem(
            title: "Enter Full Screen",
            action: #selector(toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        fullScreenItem.target = self
        viewMenu.addItem(fullScreenItem)

        let distractionFreeItem = NSMenuItem(
            title: "Distraction Free Mode",
            action: #selector(toggleDistractionFree(_:)),
            keyEquivalent: ""
        )
        distractionFreeItem.target = self
        viewMenu.addItem(distractionFreeItem)

        let monitoringItem = NSMenuItem(
            title: "Toggle Monitoring",
            action: #selector(toggleMonitoring(_:)),
            keyEquivalent: ""
        )
        monitoringItem.target = self
        viewMenu.addItem(monitoringItem)

        viewMenuItem.submenu = viewMenu
        return viewMenuItem
    }

    // MARK: - Search Menu

    private func buildSearchMenu() -> NSMenuItem {
        let searchMenuItem = NSMenuItem()
        let searchMenu = NSMenu(title: "Search")

        let findItem = NSMenuItem(
            title: "Find\u{2026}",
            action: #selector(showFind(_:)),
            keyEquivalent: "f"
        )
        findItem.target = self
        searchMenu.addItem(findItem)

        let findReplaceItem = NSMenuItem(
            title: "Find and Replace\u{2026}",
            action: #selector(showFindAndReplace(_:)),
            keyEquivalent: "f"
        )
        findReplaceItem.keyEquivalentModifierMask = [.command, .option]
        findReplaceItem.target = self
        searchMenu.addItem(findReplaceItem)

        let findAllOpenDocsItem = NSMenuItem(
            title: "Find All in Open Documents",
            action: #selector(findAllInOpenDocuments(_:)),
            keyEquivalent: ""
        )
        findAllOpenDocsItem.target = self
        searchMenu.addItem(findAllOpenDocsItem)

        searchMenu.addItem(.separator())

        let findNextItem = NSMenuItem(
            title: "Find Next",
            action: #selector(findNext(_:)),
            keyEquivalent: "g"
        )
        findNextItem.target = self
        searchMenu.addItem(findNextItem)

        let findPreviousItem = NSMenuItem(
            title: "Find Previous",
            action: #selector(findPrevious(_:)),
            keyEquivalent: "G"
        )
        findPreviousItem.keyEquivalentModifierMask = [.command, .shift]
        findPreviousItem.target = self
        searchMenu.addItem(findPreviousItem)

        searchMenu.addItem(.separator())

        let goToLineItem = NSMenuItem(
            title: "Go to Line\u{2026}",
            action: #selector(goToLine(_:)),
            keyEquivalent: "l"
        )
        goToLineItem.target = self
        searchMenu.addItem(goToLineItem)

        searchMenu.addItem(.separator())

        let replaceInFilesItem = NSMenuItem(
            title: "Replace in Files\u{2026}",
            action: #selector(replaceInFiles(_:)),
            keyEquivalent: ""
        )
        replaceInFilesItem.target = self
        searchMenu.addItem(replaceInFilesItem)

        searchMenu.addItem(.separator())

        // Bookmark submenu
        let bookmarkMenuItem = NSMenuItem(title: "Bookmarks", action: nil, keyEquivalent: "")
        let bookmarkMenu = NSMenu(title: "Bookmarks")

        let toggleBookmarkItem = NSMenuItem(
            title: "Toggle Bookmark",
            action: #selector(toggleBookmark(_:)),
            keyEquivalent: "\u{F719}"
        )
        toggleBookmarkItem.keyEquivalentModifierMask = .command
        toggleBookmarkItem.target = self
        bookmarkMenu.addItem(toggleBookmarkItem)

        let nextBookmarkItem = NSMenuItem(
            title: "Next Bookmark",
            action: #selector(nextBookmark(_:)),
            keyEquivalent: "\u{F719}"
        )
        nextBookmarkItem.keyEquivalentModifierMask = []
        nextBookmarkItem.target = self
        bookmarkMenu.addItem(nextBookmarkItem)

        let prevBookmarkItem = NSMenuItem(
            title: "Previous Bookmark",
            action: #selector(previousBookmark(_:)),
            keyEquivalent: "\u{F719}"
        )
        prevBookmarkItem.keyEquivalentModifierMask = .shift
        prevBookmarkItem.target = self
        bookmarkMenu.addItem(prevBookmarkItem)

        bookmarkMenu.addItem(.separator())

        let clearBookmarksItem = NSMenuItem(
            title: "Clear All Bookmarks",
            action: #selector(clearAllBookmarks(_:)),
            keyEquivalent: ""
        )
        clearBookmarksItem.target = self
        bookmarkMenu.addItem(clearBookmarksItem)

        bookmarkMenuItem.submenu = bookmarkMenu
        searchMenu.addItem(bookmarkMenuItem)

        // Mark submenu
        let markMenuItem = NSMenuItem(title: "Marks", action: nil, keyEquivalent: "")
        let markMenu = NSMenu(title: "Marks")

        let clearAllMarksItem = NSMenuItem(
            title: "Clear All Marks",
            action: #selector(clearAllMarks(_:)),
            keyEquivalent: ""
        )
        clearAllMarksItem.target = self
        markMenu.addItem(clearAllMarksItem)

        markMenuItem.submenu = markMenu
        searchMenu.addItem(markMenuItem)

        searchMenuItem.submenu = searchMenu
        return searchMenuItem
    }

    // MARK: - Tools Menu

    private func buildToolsMenu() -> NSMenuItem {
        let toolsMenuItem = NSMenuItem()
        let toolsMenu = NSMenu(title: "Tools")

        let commandPaletteItem = NSMenuItem(
            title: "Command Palette\u{2026}",
            action: #selector(showCommandPalette(_:)),
            keyEquivalent: "P"
        )
        commandPaletteItem.keyEquivalentModifierMask = [.command, .shift]
        commandPaletteItem.target = self
        toolsMenu.addItem(commandPaletteItem)

        toolsMenu.addItem(.separator())

        let recordMacroItem = NSMenuItem(
            title: "Record Macro",
            action: #selector(recordMacro(_:)),
            keyEquivalent: ""
        )
        recordMacroItem.target = self
        toolsMenu.addItem(recordMacroItem)

        let stopRecordingItem = NSMenuItem(
            title: "Stop Recording",
            action: #selector(stopRecordingMacro(_:)),
            keyEquivalent: ""
        )
        stopRecordingItem.target = self
        toolsMenu.addItem(stopRecordingItem)

        let playMacroItem = NSMenuItem(
            title: "Play Macro",
            action: #selector(playMacro(_:)),
            keyEquivalent: ""
        )
        playMacroItem.target = self
        toolsMenu.addItem(playMacroItem)

        let runMacroMultipleItem = NSMenuItem(
            title: "Run Macro Multiple Times\u{2026}",
            action: #selector(runMacroMultipleTimes(_:)),
            keyEquivalent: ""
        )
        runMacroMultipleItem.target = self
        toolsMenu.addItem(runMacroMultipleItem)

        toolsMenu.addItem(.separator())

        let runExternalCommandItem = NSMenuItem(
            title: "Run External Command\u{2026}",
            action: #selector(runExternalCommand(_:)),
            keyEquivalent: "!"
        )
        runExternalCommandItem.keyEquivalentModifierMask = [.command, .shift]
        runExternalCommandItem.target = self
        toolsMenu.addItem(runExternalCommandItem)

        toolsMenu.addItem(.separator())

        let summaryItem = NSMenuItem(
            title: "Document Summary",
            action: #selector(showSummary(_:)),
            keyEquivalent: ""
        )
        summaryItem.target = self
        toolsMenu.addItem(summaryItem)

        toolsMenu.addItem(.separator())

        // Generate Hash submenu
        let hashMenuItem = NSMenuItem(title: "Generate Hash", action: nil, keyEquivalent: "")
        let hashMenu = NSMenu(title: "Generate Hash")

        let md5Item = NSMenuItem(title: "MD5", action: #selector(generateMD5(_:)), keyEquivalent: "")
        md5Item.target = self
        hashMenu.addItem(md5Item)

        let sha256Item = NSMenuItem(title: "SHA-256", action: #selector(generateSHA256(_:)), keyEquivalent: "")
        sha256Item.target = self
        hashMenu.addItem(sha256Item)

        let sha512Item = NSMenuItem(title: "SHA-512", action: #selector(generateSHA512(_:)), keyEquivalent: "")
        sha512Item.target = self
        hashMenu.addItem(sha512Item)

        hashMenuItem.submenu = hashMenu
        toolsMenu.addItem(hashMenuItem)

        toolsMenuItem.submenu = toolsMenu
        return toolsMenuItem
    }

    // MARK: - Window Menu

    private func buildWindowMenu() -> NSMenuItem {
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")

        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(minimizeItem)

        let zoomItem = NSMenuItem(
            title: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoomItem)

        windowMenu.addItem(.separator())

        let bringAllToFrontItem = NSMenuItem(
            title: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(bringAllToFrontItem)

        windowMenu.addItem(.separator())

        let splitEditorItem = NSMenuItem(
            title: "Split Editor",
            action: #selector(splitEditor(_:)),
            keyEquivalent: ""
        )
        splitEditorItem.target = self
        windowMenu.addItem(splitEditorItem)

        windowMenuItem.submenu = windowMenu
        return windowMenuItem
    }

    // MARK: - Help Menu

    private func buildHelpMenu() -> NSMenuItem {
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")

        let helpItem = NSMenuItem(
            title: "\(CommonKit.appName) Help",
            action: #selector(showHelp(_:)),
            keyEquivalent: "?"
        )
        helpItem.target = self
        helpMenu.addItem(helpItem)

        helpMenuItem.submenu = helpMenu
        return helpMenuItem
    }

    // MARK: - Menu Actions

    @objc func newDocument(_ sender: Any?) {
        mainWindowController?.newDocument()
    }

    @objc func openDocument(_ sender: Any?) {
        mainWindowController?.openDocument()
    }

    @objc func saveDocument(_ sender: Any?) {
        mainWindowController?.saveDocument()
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        mainWindowController?.saveDocumentAs()
    }

    @objc func performClose(_ sender: Any?) {
        mainWindowController?.window?.performClose(sender)
    }

    @objc func toggleLineNumbers(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        editor.textView.showsLineNumbers.toggle()
    }

    @objc func toggleWordWrap(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        let textView = editor.textView
        let isWrapping = textView.textContainer?.widthTracksTextView ?? true
        if isWrapping {
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.isHorizontallyResizable = true
            editor.scrollView.hasHorizontalScroller = true
        } else {
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: editor.scrollView.contentView.bounds.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textView.isHorizontallyResizable = false
            editor.scrollView.hasHorizontalScroller = false
        }
        textView.needsDisplay = true
        textView.needsLayout = true
    }

    @objc func zoomIn(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        let currentSize = editor.textView.font?.pointSize ?? 13
        editor.textView.font = NSFont.monospacedSystemFont(ofSize: currentSize + 1, weight: .regular)
    }

    @objc func zoomOut(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        let currentSize = editor.textView.font?.pointSize ?? 13
        if currentSize > 8 {
            editor.textView.font = NSFont.monospacedSystemFont(ofSize: currentSize - 1, weight: .regular)
        }
    }

    // Zoom Restore
    @objc func zoomRestore(_ sender: Any?) {
        mainWindowController?.zoomRestore()
    }

    // Sync Scroll
    @objc func toggleSyncScroll(_ sender: Any?) {
        mainWindowController?.toggleSyncScroll()
    }

    // Multi-cursor actions
    @objc func selectAllOccurrences(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        editor.multiCursorController.selectAllOccurrences(in: editor.textView)
    }

    @objc func selectNextOccurrence(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        editor.multiCursorController.selectNextOccurrence(in: editor.textView)
    }

    @objc func skipAndSelectNext(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        editor.multiCursorController.skipAndSelectNext(in: editor.textView)
    }

    @objc func undoLastMultiSelect(_ sender: Any?) {
        guard let editor = mainWindowController?.currentEditor else { return }
        editor.multiCursorController.undoLastSelection()
    }

    // View panel actions
    @objc func toggleFileBrowser(_ sender: Any?) {
        mainWindowController?.toggleFileBrowser()
    }

    @objc func toggleFunctionList(_ sender: Any?) {
        mainWindowController?.toggleFunctionList()
    }

    @objc func toggleSearchResultsPanel(_ sender: Any?) {
        mainWindowController?.toggleSearchResultsPanel()
    }

    @objc func toggleDocumentList(_ sender: Any?) {
        mainWindowController?.toggleDocumentList()
    }

    @objc func toggleClipboardHistory(_ sender: Any?) {
        mainWindowController?.toggleClipboardHistory()
    }

    @objc func toggleMarkdownPreview(_ sender: Any?) {
        mainWindowController?.toggleMarkdownPreview()
    }

    @objc func closeCurrentTab(_ sender: Any?) {
        guard let wc = mainWindowController else { return }
        let selectedIndex = wc.tabManager.selectedIndex
        guard selectedIndex >= 0, wc.tabManager.tabs.indices.contains(selectedIndex) else { return }
        wc.tabBarView(wc.tabBarView, didCloseTabAt: selectedIndex)
    }

    // Whitespace actions
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(setWhitespaceMode(_:)) {
            let currentMode = mainWindowController?.currentEditor?.whitespaceMode ?? .hidden
            menuItem.state = (menuItem.tag == currentMode.rawValue) ? .on : .off
            return mainWindowController?.currentEditor != nil
        }
        return true
    }

    @objc func setWhitespaceMode(_ sender: NSMenuItem) {
        guard let editor = mainWindowController?.currentEditor,
              let mode = WhitespaceLayoutManager.WhitespaceMode(rawValue: sender.tag)
        else { return }
        editor.whitespaceMode = mode
    }

    // Search actions
    @objc func showFind(_ sender: Any?) {
        mainWindowController?.showFindBar()
    }

    @objc func showFindAndReplace(_ sender: Any?) {
        mainWindowController?.showFindAndReplace()
    }

    @objc func findNext(_ sender: Any?) {
        mainWindowController?.findNext()
    }

    @objc func findPrevious(_ sender: Any?) {
        mainWindowController?.findPrevious()
    }

    @objc func goToLine(_ sender: Any?) {
        mainWindowController?.goToLine()
    }

    @objc func findAllInOpenDocuments(_ sender: Any?) {
        mainWindowController?.showFindBar()
        mainWindowController?.triggerFindAllInOpenDocuments()
    }

    @objc func replaceInFiles(_ sender: Any?) {
        mainWindowController?.replaceInFiles()
    }

    // Tools actions
    @objc func showCommandPalette(_ sender: Any?) {
        mainWindowController?.showCommandPalette()
    }

    @objc func recordMacro(_ sender: Any?) {
        mainWindowController?.recordMacro()
    }

    @objc func stopRecordingMacro(_ sender: Any?) {
        mainWindowController?.stopRecordingMacro()
    }

    @objc func playMacro(_ sender: Any?) {
        mainWindowController?.playMacro()
    }

    // Window actions
    @objc func splitEditor(_ sender: Any?) {
        mainWindowController?.splitEditor()
    }

    @objc func showPreferences(_ sender: Any?) {
        PreferencesWindowController.showPreferences()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        UpdateChecker.shared.checkNow()
    }

    @objc func showHelp(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = CommonKit.appName
        alert.informativeText = "A fast, lightweight text editor for macOS."
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - Line Operations Menu

    private func buildLineOperationsMenu() -> NSMenu {
        let menu = NSMenu(title: "Line Operations")

        let trimTrailing = NSMenuItem(title: "Trim Trailing Whitespace", action: #selector(trimTrailingWhitespace(_:)), keyEquivalent: "")
        trimTrailing.target = self
        menu.addItem(trimTrailing)

        let trimLeading = NSMenuItem(title: "Trim Leading Whitespace", action: #selector(trimLeadingWhitespace(_:)), keyEquivalent: "")
        trimLeading.target = self
        menu.addItem(trimLeading)

        let blankAbove = NSMenuItem(title: "Insert Blank Line Above", action: #selector(insertBlankLineAbove(_:)), keyEquivalent: "")
        blankAbove.target = self
        menu.addItem(blankAbove)

        let blankBelow = NSMenuItem(title: "Insert Blank Line Below", action: #selector(insertBlankLineBelow(_:)), keyEquivalent: "")
        blankBelow.target = self
        menu.addItem(blankBelow)

        let duplicateLineItem = NSMenuItem(title: "Duplicate Line", action: #selector(duplicateLine(_:)), keyEquivalent: "")
        duplicateLineItem.target = self
        menu.addItem(duplicateLineItem)

        menu.addItem(.separator())

        let tabsToSpaces = NSMenuItem(title: "Tabs to Spaces", action: #selector(tabsToSpaces(_:)), keyEquivalent: "")
        tabsToSpaces.target = self
        menu.addItem(tabsToSpaces)

        let spacesToTabs = NSMenuItem(title: "Spaces to Tabs", action: #selector(spacesToTabs(_:)), keyEquivalent: "")
        spacesToTabs.target = self
        menu.addItem(spacesToTabs)

        menu.addItem(.separator())

        let sortCI = NSMenuItem(title: "Sort Lines (Case Insensitive)", action: #selector(sortLinesCaseInsensitive(_:)), keyEquivalent: "")
        sortCI.target = self
        menu.addItem(sortCI)

        let sortByLen = NSMenuItem(title: "Sort Lines by Length", action: #selector(sortLinesByLength(_:)), keyEquivalent: "")
        sortByLen.target = self
        menu.addItem(sortByLen)

        let sortAsNumbers = NSMenuItem(title: "Sort Lines as Numbers", action: #selector(sortLinesAsIntegers(_:)), keyEquivalent: "")
        sortAsNumbers.target = self
        menu.addItem(sortAsNumbers)

        let shuffle = NSMenuItem(title: "Shuffle Lines", action: #selector(shuffleLines(_:)), keyEquivalent: "")
        shuffle.target = self
        menu.addItem(shuffle)

        menu.addItem(.separator())

        let removeEmpty = NSMenuItem(title: "Remove Empty Lines", action: #selector(removeEmptyLines(_:)), keyEquivalent: "")
        removeEmpty.target = self
        menu.addItem(removeEmpty)

        let removeEmptyPreserve = NSMenuItem(title: "Remove Empty Lines (Preserve Blank)", action: #selector(removeEmptyLinesPreservingBlank(_:)), keyEquivalent: "")
        removeEmptyPreserve.target = self
        menu.addItem(removeEmptyPreserve)

        let removeDups = NSMenuItem(title: "Remove All Duplicate Lines", action: #selector(removeDuplicateLines(_:)), keyEquivalent: "")
        removeDups.target = self
        menu.addItem(removeDups)

        let removeConsecDups = NSMenuItem(title: "Remove Consecutive Duplicates", action: #selector(removeConsecutiveDuplicateLines(_:)), keyEquivalent: "")
        removeConsecDups.target = self
        menu.addItem(removeConsecDups)

        return menu
    }

    // MARK: - Copy to Clipboard Menu

    private func buildCopyToClipboardMenu() -> NSMenu {
        let menu = NSMenu(title: "Copy to Clipboard")

        let copyPath = NSMenuItem(title: "Copy Full Path", action: #selector(copyFilePath(_:)), keyEquivalent: "")
        copyPath.target = self
        menu.addItem(copyPath)

        let copyName = NSMenuItem(title: "Copy File Name", action: #selector(copyFileName(_:)), keyEquivalent: "")
        copyName.target = self
        menu.addItem(copyName)

        let copyDir = NSMenuItem(title: "Copy Directory", action: #selector(copyFileDirectory(_:)), keyEquivalent: "")
        copyDir.target = self
        menu.addItem(copyDir)

        return menu
    }

    // MARK: - Format Menu

    private func buildFormatMenu() -> NSMenuItem {
        let formatMenuItem = NSMenuItem()
        let formatMenu = NSMenu(title: "Format")

        // Encoding submenu -- re-interpret file bytes with selected encoding
        let encodingMenuItem = NSMenuItem(title: "Encoding", action: nil, keyEquivalent: "")
        encodingMenuItem.submenu = buildEncodingMenu(isConvert: false)
        formatMenu.addItem(encodingMenuItem)

        // Convert to Encoding submenu -- convert content for saving
        let convertMenuItem = NSMenuItem(title: "Convert to Encoding", action: nil, keyEquivalent: "")
        convertMenuItem.submenu = buildEncodingMenu(isConvert: true)
        formatMenu.addItem(convertMenuItem)

        formatMenu.addItem(.separator())

        // EOL Conversion submenu
        let eolItem = NSMenuItem(title: "EOL Conversion", action: nil, keyEquivalent: "")
        eolItem.submenu = buildEOLConversionMenu()
        formatMenu.addItem(eolItem)

        formatMenuItem.submenu = formatMenu
        return formatMenuItem
    }

    /// Builds an encoding submenu with grouped encoding items.
    ///
    /// - Parameter isConvert: When `true`, items trigger content conversion.
    ///   When `false`, items re-interpret the file bytes with the selected encoding.
    private func buildEncodingMenu(isConvert: Bool) -> NSMenu {
        let menu = NSMenu(title: isConvert ? "Convert to Encoding" : "Encoding")
        let action: Selector = isConvert
            ? #selector(convertToEncodingAction(_:))
            : #selector(setEncodingAction(_:))
        let tag = isConvert ? 1 : 0

        for (groupIndex, group) in EncodingManager.encodingGroups.enumerated() {
            if groupIndex > 0 {
                menu.addItem(.separator())
            }

            // Add a disabled header item for the group
            let headerItem = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            headerItem.attributedTitle = NSAttributedString(
                string: group.title, attributes: headerAttrs
            )
            menu.addItem(headerItem)

            for encodingName in group.encodingNames {
                guard EncodingManager.encoding(forName: encodingName) != nil else { continue }

                let item = NSMenuItem(
                    title: encodingName,
                    action: action,
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = tag
                item.representedObject = encodingName
                menu.addItem(item)
            }
        }

        return menu
    }

    @objc func setEncodingAction(_ sender: NSMenuItem) {
        guard let encodingName = sender.representedObject as? String else { return }
        mainWindowController?.setEncoding(encodingName)
    }

    @objc func convertToEncodingAction(_ sender: NSMenuItem) {
        guard let encodingName = sender.representedObject as? String else { return }
        mainWindowController?.convertEncoding(to: encodingName)
    }

    // MARK: - EOL Conversion Menu

    private func buildEOLConversionMenu() -> NSMenu {
        let menu = NSMenu(title: "EOL Conversion")

        let crlfItem = NSMenuItem(title: "Windows (CRLF)", action: #selector(convertToCRLF(_:)), keyEquivalent: "")
        crlfItem.target = self
        menu.addItem(crlfItem)

        let lfItem = NSMenuItem(title: "Unix (LF)", action: #selector(convertToLF(_:)), keyEquivalent: "")
        lfItem.target = self
        menu.addItem(lfItem)

        let crItem = NSMenuItem(title: "Classic Mac (CR)", action: #selector(convertToCR(_:)), keyEquivalent: "")
        crItem.target = self
        menu.addItem(crItem)

        return menu
    }

    // MARK: - EOL Conversion Actions

    @objc func convertToCRLF(_ sender: Any?) {
        mainWindowController?.convertLineEnding(to: "CRLF")
    }

    @objc func convertToLF(_ sender: Any?) {
        mainWindowController?.convertLineEnding(to: "LF")
    }

    @objc func convertToCR(_ sender: Any?) {
        mainWindowController?.convertLineEnding(to: "CR")
    }

    // MARK: - Text View Helpers

    /// Runs a closure with the current editor's text view, if available.
    private func withTextView(_ body: (NSTextView) -> Void) {
        guard let tv = mainWindowController?.currentEditor?.textView else { return }
        body(tv)
    }

    // MARK: - Line Operations Actions

    @objc func trimTrailingWhitespace(_ sender: Any?) { withTextView(LineOperations.trimTrailingWhitespace) }
    @objc func trimLeadingWhitespace(_ sender: Any?) { withTextView(LineOperations.trimLeadingWhitespace) }
    @objc func insertBlankLineAbove(_ sender: Any?) { withTextView(LineOperations.insertBlankLineAbove) }
    @objc func insertBlankLineBelow(_ sender: Any?) { withTextView(LineOperations.insertBlankLineBelow) }
    @objc func tabsToSpaces(_ sender: Any?) { withTextView { LineOperations.tabsToSpaces(in: $0) } }
    @objc func spacesToTabs(_ sender: Any?) { withTextView { LineOperations.spacesToTabs(in: $0) } }
    @objc func sortLinesCaseInsensitive(_ sender: Any?) { withTextView { LineOperations.sortLinesCaseInsensitive(in: $0) } }
    @objc func sortLinesByLength(_ sender: Any?) { withTextView { LineOperations.sortLinesByLength(in: $0) } }
    @objc func sortLinesAsIntegers(_ sender: Any?) { withTextView { LineOperations.sortLinesAsIntegers(in: $0) } }
    @objc func shuffleLines(_ sender: Any?) { withTextView(LineOperations.shuffleLines) }
    @objc func removeEmptyLines(_ sender: Any?) { withTextView(LineOperations.removeEmptyLines) }
    @objc func removeEmptyLinesPreservingBlank(_ sender: Any?) { withTextView(LineOperations.removeEmptyLinesPreservingBlank) }
    @objc func removeDuplicateLines(_ sender: Any?) { withTextView(LineOperations.removeDuplicateLines) }
    @objc func removeConsecutiveDuplicateLines(_ sender: Any?) { withTextView(LineOperations.removeConsecutiveDuplicateLines) }

    // MARK: - Copy to Clipboard Actions

    @objc func copyFilePath(_ sender: Any?) {
        let url = mainWindowController?.tabManager.selectedTab?.filePath
        LineOperations.copyFilePath(from: url)
    }

    @objc func copyFileName(_ sender: Any?) {
        let url = mainWindowController?.tabManager.selectedTab?.filePath
        LineOperations.copyFileName(from: url)
    }

    @objc func copyFileDirectory(_ sender: Any?) {
        let url = mainWindowController?.tabManager.selectedTab?.filePath
        LineOperations.copyFileDirectory(from: url)
    }

    // Quick-Win actions
    @objc func reloadFromDisk(_ sender: Any?) {
        mainWindowController?.reloadFromDisk()
    }

    @objc func openContainingFolder(_ sender: Any?) {
        mainWindowController?.openContainingFolder()
    }

    @objc func openTerminalHere(_ sender: Any?) {
        mainWindowController?.openTerminalHere()
    }

    @objc func renameFile(_ sender: Any?) {
        mainWindowController?.renameFile()
    }

    @objc func saveCopyAs(_ sender: Any?) {
        mainWindowController?.saveCopyAs()
    }

    @objc func searchOnInternet(_ sender: Any?) {
        mainWindowController?.searchOnInternet()
    }

    @objc func showSummary(_ sender: Any?) {
        mainWindowController?.showSummary()
    }

    // Fold actions
    @objc func foldAll(_ sender: Any?) {
        mainWindowController?.foldAll()
    }

    @objc func unfoldAll(_ sender: Any?) {
        mainWindowController?.unfoldAll()
    }

    @objc func foldLevel(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else { return }
        mainWindowController?.foldLevel(menuItem.tag)
    }

    // Full Screen / Distraction-Free / Monitoring actions
    @objc func toggleFullScreen(_ sender: Any?) {
        mainWindowController?.toggleFullScreen()
    }

    @objc func toggleDistractionFree(_ sender: Any?) {
        mainWindowController?.toggleDistractionFree()
    }

    @objc func toggleMonitoring(_ sender: Any?) {
        mainWindowController?.toggleMonitoring()
    }

    // Macro / External Command actions
    @objc func runMacroMultipleTimes(_ sender: Any?) {
        mainWindowController?.runMacroMultipleTimes()
    }

    @objc func runExternalCommand(_ sender: Any?) {
        mainWindowController?.runExternalCommand()
    }

    @objc func showColumnEditor(_ sender: Any?) {
        mainWindowController?.showColumnEditor()
    }

    // MARK: - Print

    @objc func printDocument(_ sender: Any?) {
        guard let tv = mainWindowController?.currentEditor?.textView,
              let window = mainWindowController?.window else { return }
        let printOp = NSPrintOperation(view: tv)
        printOp.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
    }

    // MARK: - Date/Time Insertion

    @objc func insertDateTimeShort(_ sender: Any?) { withTextView(LineOperations.insertDateTimeShort) }
    @objc func insertDateTimeLong(_ sender: Any?) { withTextView(LineOperations.insertDateTimeLong) }
    @objc func insertDateTimeISO(_ sender: Any?) { withTextView(LineOperations.insertDateTimeISO) }

    // MARK: - Case Conversions

    @objc func toUpperCase(_ sender: Any?) { withTextView(CaseConverter.toUpperCase) }
    @objc func toLowerCase(_ sender: Any?) { withTextView(CaseConverter.toLowerCase) }
    @objc func toTitleCase(_ sender: Any?) { withTextView(CaseConverter.toTitleCase) }
    @objc func toggleCase(_ sender: Any?) { withTextView(CaseConverter.toggleCase) }
    @objc func toCamelCase(_ sender: Any?) { withTextView(CaseConverter.toCamelCase) }
    @objc func toSnakeCase(_ sender: Any?) { withTextView(CaseConverter.toSnakeCase) }
    @objc func sentenceCase(_ sender: Any?) { withTextView(CaseConverter.toSentenceCase) }
    @objc func randomCase(_ sender: Any?) { withTextView(CaseConverter.toRandomCase) }

    // MARK: - Comment Actions

    @objc func toggleLineComment(_ sender: Any?) {
        mainWindowController?.toggleLineComment()
    }

    @objc func toggleBlockComment(_ sender: Any?) {
        mainWindowController?.toggleBlockComment()
    }

    // MARK: - Duplicate Line

    @objc func duplicateLine(_ sender: Any?) { withTextView(LineOperations.duplicateLine) }

    // MARK: - Bookmark Actions

    @objc func toggleBookmark(_ sender: Any?) {
        mainWindowController?.toggleBookmark()
    }

    @objc func nextBookmark(_ sender: Any?) {
        mainWindowController?.nextBookmark()
    }

    @objc func previousBookmark(_ sender: Any?) {
        mainWindowController?.previousBookmark()
    }

    @objc func clearAllBookmarks(_ sender: Any?) {
        mainWindowController?.clearAllBookmarks()
    }

    // MARK: - Mark Actions

    @objc func clearAllMarks(_ sender: Any?) {
        mainWindowController?.clearAllMarks()
    }

    // MARK: - Hash Generation

    @objc func generateMD5(_ sender: Any?) {
        showHashResult(algorithm: "MD5") { HashGeneratorController.md5($0) }
    }

    @objc func generateSHA256(_ sender: Any?) {
        showHashResult(algorithm: "SHA-256") { HashGeneratorController.sha256($0) }
    }

    @objc func generateSHA512(_ sender: Any?) {
        showHashResult(algorithm: "SHA-512") { HashGeneratorController.sha512($0) }
    }

    private func showHashResult(algorithm: String, compute: (String) -> String) {
        guard let tv = mainWindowController?.currentEditor?.textView else { return }
        let selectedRange = tv.selectedRange()
        let text: String
        if selectedRange.length > 0 {
            text = (tv.string as NSString).substring(with: selectedRange)
        } else {
            text = tv.string
        }
        let hash = compute(text)
        let alert = NSAlert()
        alert.messageText = "\(algorithm) Hash"
        alert.informativeText = hash
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hash, forType: .string)
        }
    }
}

