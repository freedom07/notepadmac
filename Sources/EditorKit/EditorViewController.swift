import AppKit
import TextCore
import CommonKit

// MARK: - EditorViewController

/// A view controller that hosts a complete code editor with scroll view,
/// text view, and line-number gutter.
///
/// Use ``text`` to get or set the editor content, and subscribe to changes
/// via ``onTextDidChange`` and ``onCursorDidMove`` callbacks.
///
/// ```swift
/// let editor = EditorViewController()
/// editor.text = "Hello, NotepadNext!"
/// editor.onTextDidChange = { newText in
///     print("Content changed:", newText.prefix(80))
/// }
/// editor.onCursorDidMove = { line, column in
///     statusBar.update(line: line, column: column)
/// }
/// ```
@available(macOS 13.0, *)
public class EditorViewController: NSViewController {

    // MARK: - Multi-Cursor

    /// Controller for multi-cursor and occurrence-selection operations.
    public let multiCursorController = MultiCursorController()

    // MARK: - Completion

    /// The completion provider for keyword and document-word auto-completion.
    public let completionProvider = CompletionProvider()

    // MARK: - Bookmarks

    /// The bookmark manager for toggling and navigating line bookmarks.
    public let bookmarkManager = BookmarkManager()

    // MARK: - Subviews

    /// The scroll view that wraps the text view.
    public let scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = true
        sv.autohidesScrollers = true
        sv.borderType = .noBorder
        return sv
    }()

    /// The editor text view.
    public let textView: EditorTextView = {
        let textStorage = NSTextStorage()
        let layoutManager = WhitespaceLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = false
        textContainer.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        layoutManager.addTextContainer(textContainer)

        let tv = EditorTextView(frame: .zero, textContainer: textContainer)
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isRichText = false
        return tv
    }()

    /// Highlights all occurrences of the word under the cursor.
    public let smartHighlighter = SmartHighlighter()

    // MARK: - Public API

    /// The full text content of the editor.
    public var text: String {
        get { textView.string }
        set {
            textView.string = newValue
            textView.didChangeText()
        }
    }

    /// Called whenever the editor text changes. Receives the full new text.
    public var onTextDidChange: ((String) -> Void)?

    /// Called whenever the cursor position changes. Receives (line, column),
    /// both 1-based.
    public var onCursorDidMove: ((Int, Int) -> Void)?

    /// The whitespace visualisation mode for this editor. Changing this value
    /// immediately redraws the editor to show or hide whitespace indicators.
    public var whitespaceMode: WhitespaceLayoutManager.WhitespaceMode {
        get { (textView.layoutManager as? WhitespaceLayoutManager)?.whitespaceMode ?? .hidden }
        set { (textView.layoutManager as? WhitespaceLayoutManager)?.whitespaceMode = newValue }
    }

    // MARK: - Lifecycle

    public override func loadView() {
        let containerView = NSView()
        containerView.autoresizingMask = [.width, .height]

        configureScrollView(in: containerView)
        configureTextView()
        configureLineNumberView(in: containerView)
        registerNotifications()
        multiCursorController.textView = textView

        // Wire up auto-completion.
        textView.completionProvider = completionProvider

        self.view = containerView
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(textView)
        // Trigger initial line number display and cursor position
        lineNumberView?.currentLine = 1
        textView.setSelectedRange(NSRange(location: 0, length: 0))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup Helpers

    private var scrollViewLeadingConstraint: NSLayoutConstraint?

    private func configureScrollView(in container: NSView) {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        let leading = scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        scrollViewLeadingConstraint = leading

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            leading,
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        scrollView.documentView = textView
    }

    private func configureTextView() {
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true

        // Disable smart substitutions for code editing.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = true

        // Let lines extend beyond the visible width.
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    /// Standalone line-number view (replaces NSRulerView-based gutter which
    /// breaks text rendering on macOS 15).
    private var lineNumberView: LineNumberSideView?

    private func configureLineNumberView(in container: NSView) {
        let lnv = LineNumberSideView(textView: textView, scrollView: scrollView)
        lnv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lnv)

        scrollViewLeadingConstraint?.isActive = false
        NSLayoutConstraint.activate([
            lnv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            lnv.topAnchor.constraint(equalTo: container.topAnchor),
            lnv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            lnv.widthAnchor.constraint(greaterThanOrEqualToConstant: 33),
            scrollView.leadingAnchor.constraint(equalTo: lnv.trailingAnchor),
        ])

        lineNumberView = lnv
    }

    // MARK: - Notifications

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )

        // Also observe selection changes to update cursor position.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: textView
        )
    }

    @objc private func textDidChange(_ notification: Notification) {
        onTextDidChange?(textView.string)
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        let line = textView.currentLineNumber()
        let column = textView.currentColumnNumber()
        lineNumberView?.currentLine = line
        onCursorDidMove?(line, column)
        smartHighlighter.cursorDidMove(in: textView)
    }
}
