import AppKit
import CommonKit

// MARK: - TabBarViewDelegate

/// Delegate protocol for responding to tab bar interactions.
public protocol TabBarViewDelegate: AnyObject {

    /// Called when the user selects a tab.
    func tabBarView(_ tabBar: TabBarView, didSelectTabAt index: Int)

    /// Called when the user closes a tab (via the close button or middle-click).
    func tabBarView(_ tabBar: TabBarView, didCloseTabAt index: Int)

    /// Called when the user clicks the "+" button to create a new tab.
    func tabBarViewDidClickAddButton(_ tabBar: TabBarView)

    /// Called when the user drags a tab from one position to another.
    func tabBarView(_ tabBar: TabBarView, didMoveTabFrom sourceIndex: Int, to destinationIndex: Int)
}

// MARK: - TabBarView

/// A custom-drawn tab bar for managing document tabs.
///
/// `TabBarView` renders tabs using Core Graphics, supports hover effects with a close button,
/// a modified-document indicator, and a trailing "+" button. It handles left-click to select,
/// middle-click to close, and right-click context menus.
public final class TabBarView: NSView {

    // MARK: - Constants

    private enum Layout {
        static let tabMinWidth: CGFloat = 80
        static let tabMaxWidth: CGFloat = 200
        static let tabHeight: CGFloat = 30
        static let addButtonWidth: CGFloat = 28
        static let closeButtonSize: CGFloat = 14
        static let closeButtonPadding: CGFloat = 6
        static let horizontalTextPadding: CGFloat = 24
        static let cornerRadius: CGFloat = 4
    }

    // MARK: - Tab Color Coding

    /// Maps color tag indices to their corresponding colors.
    public static let tabColors: [Int: NSColor] = [
        1: .systemRed,
        2: .systemBlue,
        3: .systemGreen,
        4: .systemOrange,
        5: .systemPurple,
    ]

    // MARK: - Properties

    /// Tabs to display. Setting this triggers a redraw.
    public var tabs: [TabItem] = [] {
        didSet {
            invalidateCachedTabWidth()
            if isDragging { isDragging = false; dragSourceIndex = -1; dragInsertionIndex = -1; mouseDownTabIndex = -1; dragStartPoint = .zero }
            needsDisplay = true
        }
    }

    /// Index of the currently selected tab.
    public var selectedIndex: Int = -1 {
        didSet { needsDisplay = true }
    }

    /// Delegate for tab bar actions.
    public weak var delegate: TabBarViewDelegate?

    /// Index of the tab currently under the mouse, or `-1`.
    private var hoveredIndex: Int = -1

    /// Tracking area for mouse-moved events.
    private var trackingArea: NSTrackingArea?

    // MARK: - Drag State

    /// Whether a tab drag is in progress.
    private var isDragging = false

    /// Index of the tab being dragged.
    private var dragSourceIndex: Int = -1

    /// Index where the dragged tab would be inserted.
    private var dragInsertionIndex: Int = -1

    /// Point where the mouse was pressed (used for drag threshold).
    private var dragStartPoint: NSPoint = .zero

    /// Index of the tab under the initial mouse-down, or `-1`.
    private var mouseDownTabIndex: Int = -1

    // MARK: - Initializers

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        updateTrackingAreas()
    }

    // MARK: - Intrinsic Size

    public override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Layout.tabHeight)
    }

    // MARK: - Tracking Areas

    public override func updateTrackingAreas() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    // MARK: - Geometry Helpers

    /// Cached tab width, invalidated when tabs or bounds change.
    private var _cachedTabWidth: CGFloat?
    private var _cachedBoundsWidth: CGFloat = 0

    private func invalidateCachedTabWidth() { _cachedTabWidth = nil }

    /// Computes the width for each tab so they fill the available space evenly.
    private func tabWidth() -> CGFloat {
        if let cached = _cachedTabWidth, _cachedBoundsWidth == bounds.width {
            return cached
        }
        guard !tabs.isEmpty else { return Layout.tabMinWidth }
        let available = bounds.width - Layout.addButtonWidth
        let natural = available / CGFloat(tabs.count)
        let w = min(max(natural, Layout.tabMinWidth), Layout.tabMaxWidth)
        _cachedTabWidth = w
        _cachedBoundsWidth = bounds.width
        return w
    }

    /// Returns the frame for the tab at the given index.
    private func frameForTab(at index: Int) -> NSRect {
        let w = tabWidth()
        return NSRect(x: CGFloat(index) * w, y: 0, width: w, height: Layout.tabHeight)
    }

    /// Returns the frame for the "+" button.
    private func addButtonFrame() -> NSRect {
        let w = tabWidth()
        let x = CGFloat(tabs.count) * w
        return NSRect(x: x, y: 0, width: Layout.addButtonWidth, height: Layout.tabHeight)
    }

    /// Returns the frame for the close button inside a tab frame.
    private func closeButtonFrame(in tabFrame: NSRect) -> NSRect {
        let size = Layout.closeButtonSize
        let x = tabFrame.maxX - size - Layout.closeButtonPadding
        let y = tabFrame.midY - size / 2
        return NSRect(x: x, y: y, width: size, height: size)
    }

    /// Returns the tab index at the given point, or `nil`.
    private func tabIndex(at point: NSPoint) -> Int? {
        for i in tabs.indices {
            if frameForTab(at: i).contains(point) {
                return i
            }
        }
        return nil
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        let bgColor = NSColor.windowBackgroundColor.cgColor
        ctx.setFillColor(bgColor)
        ctx.fill(bounds)

        // Bottom separator
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 0, y: 0.5))
        ctx.addLine(to: CGPoint(x: bounds.width, y: 0.5))
        ctx.strokePath()

        // Tabs
        for i in tabs.indices {
            drawTab(at: i, in: ctx)
        }

        // Drag insertion indicator
        if isDragging, dragInsertionIndex >= 0, !tabs.isEmpty {
            drawInsertionIndicator(at: dragInsertionIndex, in: ctx)
        }

        // Add button
        drawAddButton(in: ctx)
    }

    private func drawTab(at index: Int, in ctx: CGContext) {
        let tab = tabs[index]
        let frame = frameForTab(at: index)
        let isSelected = index == selectedIndex
        let isHovered = index == hoveredIndex

        // Reduce opacity for the tab being dragged
        if isDragging && index == dragSourceIndex {
            ctx.saveGState()
            ctx.setAlpha(0.5)
        }

        // Tab background
        let tabRect = frame.insetBy(dx: 1, dy: 2)
        let path = CGPath(roundedRect: tabRect,
                          cornerWidth: Layout.cornerRadius,
                          cornerHeight: Layout.cornerRadius,
                          transform: nil)

        if isSelected {
            ctx.setFillColor(NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor)
        } else if isHovered {
            ctx.setFillColor(NSColor.labelColor.withAlphaComponent(0.06).cgColor)
        } else {
            ctx.setFillColor(NSColor.clear.cgColor)
        }
        ctx.addPath(path)
        ctx.fillPath()

        // Separator between tabs
        if index > 0, index != selectedIndex, index - 1 != selectedIndex {
            ctx.setStrokeColor(NSColor.separatorColor.cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: frame.minX, y: frame.minY + 6))
            ctx.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 6))
            ctx.strokePath()
        }

        // Title
        let titleColor: NSColor = isSelected ? .labelColor : .secondaryLabelColor
        let font = NSFont.systemFont(ofSize: 12, weight: isSelected ? .medium : .regular)

        var displayTitle = tab.title
        if tab.isModified {
            displayTitle = "\u{25CF} " + displayTitle // ● prefix
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: titleColor,
            .paragraphStyle: paragraphStyle,
        ]

        let closeSpace: CGFloat = (isHovered || isSelected) ? Layout.closeButtonSize + Layout.closeButtonPadding : 0
        let maxTextWidth = frame.width - Layout.horizontalTextPadding - closeSpace - 8
        let textHeight = font.ascender - font.descender + font.leading

        let textRect = NSRect(
            x: frame.minX + 8,
            y: frame.midY - textHeight / 2,
            width: maxTextWidth,
            height: textHeight
        )
        (displayTitle as NSString).draw(in: textRect, withAttributes: attrs)

        // Close button on hover
        if isHovered || isSelected {
            let closeRect = closeButtonFrame(in: frame)
            drawCloseButton(in: closeRect, ctx: ctx)
        }

        // Color tag bar at the bottom of the tab
        if tab.colorTag > 0, let color = TabBarView.tabColors[tab.colorTag] {
            let barHeight: CGFloat = 3
            let barRect = NSRect(
                x: tabRect.minX,
                y: tabRect.minY,
                width: tabRect.width,
                height: barHeight
            )
            ctx.setFillColor(color.cgColor)
            ctx.fill(barRect)
        }

        // Restore alpha if this tab was drawn with reduced opacity
        if isDragging && index == dragSourceIndex {
            ctx.restoreGState()
        }
    }

    private func drawCloseButton(in rect: NSRect, ctx: CGContext) {
        ctx.saveGState()
        let inset: CGFloat = 3
        let inner = rect.insetBy(dx: inset, dy: inset)

        ctx.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineCap(.round)

        ctx.move(to: CGPoint(x: inner.minX, y: inner.minY))
        ctx.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY))
        ctx.move(to: CGPoint(x: inner.maxX, y: inner.minY))
        ctx.addLine(to: CGPoint(x: inner.minX, y: inner.maxY))
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawAddButton(in ctx: CGContext) {
        let frame = addButtonFrame()

        // Plus sign
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let armLength: CGFloat = 5

        ctx.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)

        ctx.move(to: CGPoint(x: center.x - armLength, y: center.y))
        ctx.addLine(to: CGPoint(x: center.x + armLength, y: center.y))
        ctx.move(to: CGPoint(x: center.x, y: center.y - armLength))
        ctx.addLine(to: CGPoint(x: center.x, y: center.y + armLength))
        ctx.strokePath()
    }

    // MARK: - Mouse Events

    public override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Add button
        if addButtonFrame().contains(point) {
            delegate?.tabBarViewDidClickAddButton(self)
            return
        }

        // Tab selection / close
        if let index = tabIndex(at: point) {
            let tabFrame = frameForTab(at: index)
            let closeRect = closeButtonFrame(in: tabFrame)
            if closeRect.contains(point) {
                delegate?.tabBarView(self, didCloseTabAt: index)
            } else {
                delegate?.tabBarView(self, didSelectTabAt: index)
                // Record potential drag start
                dragStartPoint = point
                mouseDownTabIndex = index
            }
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard mouseDownTabIndex >= 0, tabs.indices.contains(mouseDownTabIndex) else { return }

        if !isDragging {
            let dx = point.x - dragStartPoint.x
            let dy = point.y - dragStartPoint.y
            if sqrt(dx * dx + dy * dy) < 3 { return } // drag threshold
            isDragging = true
            dragSourceIndex = mouseDownTabIndex
        }

        dragInsertionIndex = computeInsertionIndex(at: point)
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        if isDragging, dragSourceIndex >= 0, dragInsertionIndex >= 0 {
            var dest = dragInsertionIndex
            if dest > dragSourceIndex { dest -= 1 }
            dest = max(0, min(dest, tabs.count - 1))
            if dest != dragSourceIndex {
                delegate?.tabBarView(self, didMoveTabFrom: dragSourceIndex, to: dest)
            }
        }
        isDragging = false
        dragSourceIndex = -1
        dragInsertionIndex = -1
        mouseDownTabIndex = -1
        dragStartPoint = .zero
        needsDisplay = true
    }

    public override func otherMouseDown(with event: NSEvent) {
        // Middle-click to close
        guard event.buttonNumber == 2 else {
            super.otherMouseDown(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if let index = tabIndex(at: point) {
            delegate?.tabBarView(self, didCloseTabAt: index)
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = tabIndex(at: point) else {
            super.rightMouseDown(with: event)
            return
        }
        showContextMenu(for: index, at: point, with: event)
    }

    public override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newHovered = tabIndex(at: point) ?? -1
        if newHovered != hoveredIndex {
            hoveredIndex = newHovered
            needsDisplay = true
        }
    }

    public override func mouseExited(with event: NSEvent) {
        if hoveredIndex != -1 {
            hoveredIndex = -1
            needsDisplay = true
        }
    }

    // MARK: - Drag Helpers

    /// Returns the insertion index for a dragged tab based on the mouse position.
    private func computeInsertionIndex(at point: NSPoint) -> Int {
        for i in tabs.indices {
            let frame = frameForTab(at: i)
            if point.x < frame.midX { return i }
        }
        return tabs.count
    }

    /// Draws a vertical insertion indicator at the given tab index.
    private func drawInsertionIndicator(at index: Int, in ctx: CGContext) {
        let x: CGFloat
        if index >= tabs.count {
            let lastFrame = frameForTab(at: tabs.count - 1)
            x = lastFrame.maxX
        } else {
            x = frameForTab(at: index).minX
        }
        ctx.saveGState()
        ctx.setFillColor(NSColor.controlAccentColor.cgColor)
        ctx.fill(NSRect(x: x - 1, y: 4, width: 2, height: Layout.tabHeight - 8))
        ctx.restoreGState()
    }

    // MARK: - Context Menu

    private func showContextMenu(for index: Int, at point: NSPoint, with event: NSEvent) {
        let menu = NSMenu()

        let closeItem = NSMenuItem(title: "Close", action: #selector(contextClose(_:)), keyEquivalent: "")
        closeItem.tag = index
        closeItem.target = self
        menu.addItem(closeItem)

        let closeOthersItem = NSMenuItem(title: "Close Others", action: #selector(contextCloseOthers(_:)), keyEquivalent: "")
        closeOthersItem.tag = index
        closeOthersItem.target = self
        closeOthersItem.isEnabled = tabs.count > 1
        menu.addItem(closeOthersItem)

        let closeAllItem = NSMenuItem(title: "Close All", action: #selector(contextCloseAll(_:)), keyEquivalent: "")
        closeAllItem.target = self
        menu.addItem(closeAllItem)

        menu.addItem(.separator())

        let tab = tabs[index]
        let copyPathItem = NSMenuItem(title: "Copy Path", action: #selector(contextCopyPath(_:)), keyEquivalent: "")
        copyPathItem.tag = index
        copyPathItem.target = self
        copyPathItem.isEnabled = tab.filePath != nil
        menu.addItem(copyPathItem)

        menu.addItem(.separator())

        // Apply Color submenu
        let colorMenu = NSMenu()
        let colorNames: [(Int, String)] = [
            (1, "Red"), (2, "Blue"), (3, "Green"), (4, "Orange"), (5, "Purple")
        ]
        for (colorIndex, colorName) in colorNames {
            let item = NSMenuItem(title: colorName, action: #selector(contextApplyColor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [index, colorIndex]
            colorMenu.addItem(item)
        }
        colorMenu.addItem(.separator())
        let removeColorItem = NSMenuItem(title: "Remove Color", action: #selector(contextApplyColor(_:)), keyEquivalent: "")
        removeColorItem.target = self
        removeColorItem.representedObject = [index, 0]
        colorMenu.addItem(removeColorItem)

        let applyColorItem = NSMenuItem(title: "Apply Color", action: nil, keyEquivalent: "")
        applyColorItem.submenu = colorMenu
        menu.addItem(applyColorItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func contextClose(_ sender: NSMenuItem) {
        delegate?.tabBarView(self, didCloseTabAt: sender.tag)
    }

    @objc private func contextCloseOthers(_ sender: NSMenuItem) {
        // Close tabs from the end to avoid index shifting. Keep the tagged tab.
        let keepIndex = sender.tag
        for i in stride(from: tabs.count - 1, through: 0, by: -1) where i != keepIndex {
            delegate?.tabBarView(self, didCloseTabAt: i)
        }
    }

    @objc private func contextCloseAll(_ sender: NSMenuItem) {
        for i in stride(from: tabs.count - 1, through: 0, by: -1) {
            delegate?.tabBarView(self, didCloseTabAt: i)
        }
    }

    @objc private func contextCopyPath(_ sender: NSMenuItem) {
        guard tabs.indices.contains(sender.tag),
              let path = tabs[sender.tag].filePath?.path else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
    }

    @objc private func contextApplyColor(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [Int],
              pair.count == 2,
              tabs.indices.contains(pair[0]) else { return }
        tabs[pair[0]].colorTag = pair[1]
        needsDisplay = true
    }
}
