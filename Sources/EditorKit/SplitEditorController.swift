import AppKit
import CommonKit

// MARK: - SplitOrientation

public enum SplitOrientation {
    case horizontal
    case vertical
}

// MARK: - SplitEditorController

public class SplitEditorController: NSSplitViewController {

    public var primaryEditor: EditorViewController
    public var secondaryEditor: EditorViewController?
    public private(set) var splitOrientation: SplitOrientation = .vertical

    public var isSplit: Bool {
        secondaryEditor != nil
    }

    // MARK: - Synchronized Scrolling

    /// When `true`, scrolling one editor pane scrolls the other to match.
    public var isSyncScrollEnabled: Bool = false {
        didSet { updateScrollSync() }
    }

    /// Tracks NotificationCenter observers for scroll synchronization.
    private var scrollObservers: [NSObjectProtocol] = []

    /// Guard flag to prevent recursive scroll updates.
    private var isSyncingScroll: Bool = false

    // MARK: - Initialization

    public init(primaryEditor: EditorViewController) {
        self.primaryEditor = primaryEditor
        super.init(nibName: nil, bundle: nil)
        let primaryItem = NSSplitViewItem(viewController: primaryEditor)
        addSplitViewItem(primaryItem)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = (splitOrientation == .vertical)
    }

    // MARK: - Split Management

    public func splitEditor(orientation: SplitOrientation) {
        if isSplit {
            unsplitEditor()
        }

        splitOrientation = orientation
        splitView.isVertical = (orientation == .vertical)

        let newEditor = EditorViewController()
        let secondaryItem = NSSplitViewItem(viewController: newEditor)
        addSplitViewItem(secondaryItem)
        secondaryEditor = newEditor

        // Re-apply sync scroll if enabled
        if isSyncScrollEnabled {
            updateScrollSync()
        }
    }

    public func unsplitEditor() {
        removeScrollObservers()
        guard let secondary = secondaryEditor else { return }
        for item in splitViewItems where item.viewController === secondary {
            removeSplitViewItem(item)
            break
        }
        secondaryEditor = nil
    }

    public func setSameDocument(text: String) {
        primaryEditor.text = text
        secondaryEditor?.text = text
    }

    // MARK: - Scroll Sync

    private func updateScrollSync() {
        removeScrollObservers()

        guard isSyncScrollEnabled,
              let secondary = secondaryEditor else { return }

        let primaryClipView = primaryEditor.scrollView.contentView
        let secondaryClipView = secondary.scrollView.contentView

        // Enable postsBoundsChangedNotifications for both clip views
        primaryClipView.postsBoundsChangedNotifications = true
        secondaryClipView.postsBoundsChangedNotifications = true

        let primaryObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: primaryClipView,
            queue: nil
        ) { [weak self] _ in
            self?.syncScroll(from: primaryClipView, to: secondaryClipView)
        }

        let secondaryObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: secondaryClipView,
            queue: nil
        ) { [weak self] _ in
            self?.syncScroll(from: secondaryClipView, to: primaryClipView)
        }

        scrollObservers = [primaryObserver, secondaryObserver]
    }

    private func syncScroll(from source: NSClipView, to target: NSClipView) {
        guard !isSyncingScroll else { return }
        isSyncingScroll = true
        target.scroll(to: source.bounds.origin)
        target.superview?.reflectScrolledClipView(target)
        isSyncingScroll = false
    }

    private func removeScrollObservers() {
        for observer in scrollObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        scrollObservers.removeAll()
    }

    deinit {
        removeScrollObservers()
    }
}
