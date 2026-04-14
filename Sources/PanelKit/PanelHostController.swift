import AppKit

// MARK: - PanelHostDelegate

/// Notifies the owner when panel visibility changes.
public protocol PanelHostDelegate: AnyObject {
    func panelHost(_ host: PanelHostController, didTogglePanel id: String, visible: Bool)
}

// MARK: - PanelHostController

/// Manages the split-view layout that hosts editor content and collapsible panels.
///
/// Layout structure:
/// ```
/// outerSplit (horizontal)
/// ├── leftContainer  (collapsible, holds left panels)
/// ├── centerSplit    (vertical, holds editor + bottom panel)
/// │   ├── editorArea (the main editor content)
/// │   └── bottomContainer (collapsible, holds bottom panels)
/// └── rightContainer (collapsible, holds right panels)
/// ```
@available(macOS 13.0, *)
public final class PanelHostController: NSSplitViewController {

    // MARK: - Public interface

    /// The view where the main editor should be placed.
    public let editorArea = NSView()

    /// The wrapper VC that owns editorArea. Add editor VCs as children of this
    /// controller so that the VC hierarchy matches the view hierarchy.
    public private(set) var editorWrapperController: NSViewController!

    public weak var panelDelegate: PanelHostDelegate?

    // MARK: - Split view items (initialized in setupSplitView, accessed after viewDidLoad)

    private var leftItem: NSSplitViewItem?
    private var centerItem: NSSplitViewItem?
    private var rightItem: NSSplitViewItem?

    private var centerSplitController: NSSplitViewController?
    private var editorItem: NSSplitViewItem?
    private var bottomItem: NSSplitViewItem?

    // MARK: - Panel containers

    /// Container view controllers for each dock area.
    private let leftContainer = PanelContainerController(position: .left)
    private let rightContainer = PanelContainerController(position: .right)
    private let bottomContainer = PanelContainerController(position: .bottom)

    // MARK: - Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupSplitView()
    }

    // MARK: - Setup

    private func setupSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        // Editor wrapper VC — exposed so consumers can add editor children here
        let editorVC = NSViewController()
        editorVC.view = editorArea
        editorWrapperController = editorVC

        // Center split: editor + bottom panel
        let centerSplit = NSSplitViewController()
        centerSplit.splitView.isVertical = false
        centerSplit.splitView.dividerStyle = .thin
        centerSplitController = centerSplit

        let edItem = NSSplitViewItem(viewController: editorVC)
        edItem.canCollapse = false
        editorItem = edItem
        centerSplit.addSplitViewItem(edItem)

        // Bottom panel: use plain viewController (not sidebar) for vertical split
        let btmItem = NSSplitViewItem(viewController: bottomContainer)
        btmItem.canCollapse = true
        btmItem.isCollapsed = true
        btmItem.minimumThickness = 100
        btmItem.maximumThickness = 500
        btmItem.preferredThicknessFraction = 0.25
        bottomItem = btmItem
        centerSplit.addSplitViewItem(btmItem)

        // Outer split: left | center | right
        let lItem = NSSplitViewItem(sidebarWithViewController: leftContainer)
        lItem.canCollapse = true
        lItem.isCollapsed = true
        lItem.minimumThickness = 150
        lItem.maximumThickness = 500
        lItem.preferredThicknessFraction = 0.2
        leftItem = lItem
        addSplitViewItem(lItem)

        let cItem = NSSplitViewItem(viewController: centerSplit)
        cItem.canCollapse = false
        centerItem = cItem
        addSplitViewItem(cItem)

        let rItem = NSSplitViewItem(sidebarWithViewController: rightContainer)
        rItem.canCollapse = true
        rItem.isCollapsed = true
        rItem.minimumThickness = 200
        rItem.maximumThickness = .greatestFiniteMagnitude
        rItem.preferredThicknessFraction = 0.5
        rightItem = rItem
        addSplitViewItem(rItem)
    }

    // MARK: - Panel Management

    /// Adds a panel to a dock area. The panel's view controller will be hosted in the
    /// appropriate container.
    public func addPanel(_ viewController: NSViewController, descriptor: PanelDescriptor) {
        container(for: descriptor.position).addPanel(viewController, descriptor: descriptor)
    }

    /// Removes a panel by id.
    public func removePanel(id: String) {
        for pos in PanelPosition.allCases {
            let c = container(for: pos)
            if c.hasPanel(id: id) {
                c.removePanel(id: id)
                if !c.hasVisiblePanels, let item = splitItem(for: pos) {
                    item.animator().isCollapsed = true
                }
                panelDelegate?.panelHost(self, didTogglePanel: id, visible: false)
                return
            }
        }
    }

    /// Shows or hides a specific panel. If the panel's dock area was collapsed,
    /// it is expanded.
    public func togglePanel(id: String) {
        for pos in PanelPosition.allCases {
            let c = container(for: pos)
            if c.hasPanel(id: id) {
                let isNowVisible = c.togglePanel(id: id)
                guard let item = splitItem(for: pos) else { return }
                if isNowVisible {
                    item.isCollapsed = false
                    // Explicitly set divider position so the panel opens at half width
                    let totalWidth = splitView.frame.width
                    if totalWidth > 0, let dividerIndex = self.dividerIndex(for: pos) {
                        let fraction = item.preferredThicknessFraction
                        let position = totalWidth * (1.0 - fraction)
                        splitView.setPosition(position, ofDividerAt: dividerIndex)
                    }
                } else if !c.hasVisiblePanels {
                    item.animator().isCollapsed = true
                }
                panelDelegate?.panelHost(self, didTogglePanel: id, visible: isNowVisible)
                return
            }
        }
    }

    /// Returns the divider index for a given panel position.
    private func dividerIndex(for position: PanelPosition) -> Int? {
        // Layout: left(0) | center(1) | right(2)
        // Dividers: 0 (left|center), 1 (center|right)
        // Collapsed items still count — indices are fixed.
        switch position {
        case .left: return 0
        case .right: return 1
        case .bottom: return nil
        }
    }

    /// Shows a specific panel, making it visible.
    public func showPanel(id: String) {
        for pos in PanelPosition.allCases {
            let c = container(for: pos)
            if c.hasPanel(id: id) {
                c.selectPanel(id: id)
                splitItem(for: pos)?.animator().isCollapsed = false
                panelDelegate?.panelHost(self, didTogglePanel: id, visible: true)
                return
            }
        }
    }

    /// Returns whether a specific panel is currently visible and its dock area is expanded.
    public func isPanelVisible(id: String) -> Bool {
        for pos in PanelPosition.allCases {
            let c = container(for: pos)
            if c.hasPanel(id: id) {
                guard let item = splitItem(for: pos) else { return false }
                return !item.isCollapsed && c.isPanelVisible(id: id)
            }
        }
        return false
    }

    /// Hides a dock area entirely.
    public func hideDockArea(_ position: PanelPosition) {
        splitItem(for: position)?.animator().isCollapsed = true
    }

    /// Shows a dock area.
    public func showDockArea(_ position: PanelPosition) {
        splitItem(for: position)?.animator().isCollapsed = false
    }

    /// Whether a dock area is visible.
    public func isDockAreaVisible(_ position: PanelPosition) -> Bool {
        guard let item = splitItem(for: position) else { return false }
        return !item.isCollapsed
    }

    // MARK: - Private helpers

    private func container(for position: PanelPosition) -> PanelContainerController {
        switch position {
        case .left: return leftContainer
        case .right: return rightContainer
        case .bottom: return bottomContainer
        }
    }

    private func splitItem(for position: PanelPosition) -> NSSplitViewItem? {
        switch position {
        case .left: return leftItem
        case .right: return rightItem
        case .bottom: return bottomItem
        }
    }
}
