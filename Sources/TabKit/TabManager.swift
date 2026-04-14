import AppKit
import CommonKit

// MARK: - TabManager

/// Manages the ordered collection of open tabs and the current selection.
///
/// `TabManager` is the source of truth for tab state. UI components observe changes
/// through the `onTabsChanged` closure and react accordingly.
public final class TabManager {

    // MARK: - Properties

    /// The ordered list of open tabs.
    public private(set) var tabs: [TabItem] = []

    /// Index of the currently selected tab, or `-1` when no tabs are open.
    public var selectedIndex: Int = -1 {
        didSet {
            if selectedIndex != oldValue {
                onTabsChanged?()
            }
        }
    }

    /// The currently selected tab, or `nil` when no tabs are open.
    public var selectedTab: TabItem? {
        guard tabs.indices.contains(selectedIndex) else { return nil }
        return tabs[selectedIndex]
    }

    /// Callback invoked whenever the tab list or selection changes.
    /// Assign this to trigger UI redraws.
    public var onTabsChanged: (() -> Void)?

    // MARK: - Initializer

    public init() {}

    // MARK: - Tab Operations

    /// Adds a new tab and selects it.
    ///
    /// - Parameters:
    ///   - title: Display title for the new tab.
    ///   - filePath: Optional file URL for the document.
    /// - Returns: The newly created `TabItem`.
    @discardableResult
    public func addTab(title: String, filePath: URL? = nil) -> TabItem {
        let tab = TabItem(title: title, filePath: filePath)
        tabs.append(tab)
        selectedIndex = tabs.count - 1
        onTabsChanged?()
        return tab
    }

    /// Closes the tab at the given index.
    ///
    /// After closing, the selection moves to the nearest remaining tab. If the last tab
    /// is closed the selection becomes `-1`.
    ///
    /// - Parameter index: Index of the tab to close.
    public func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        tabs.remove(at: index)

        if tabs.isEmpty {
            selectedIndex = -1
        } else if selectedIndex >= tabs.count {
            selectedIndex = tabs.count - 1
        } else if selectedIndex > index {
            selectedIndex -= 1
        }
        // When selectedIndex == index (and still valid), the tab at that position is now the next one.

        onTabsChanged?()
    }

    /// Closes all tabs except the one at the given index.
    ///
    /// - Parameter index: Index of the tab to keep.
    public func closeOtherTabs(except index: Int) {
        guard tabs.indices.contains(index) else { return }
        let kept = tabs[index]
        tabs = [kept]
        selectedIndex = 0
        onTabsChanged?()
    }

    /// Closes all open tabs.
    public func closeAllTabs() {
        tabs.removeAll()
        selectedIndex = -1
        onTabsChanged?()
    }

    /// Selects the tab at the given index.
    ///
    /// - Parameter index: Index of the tab to select.
    public func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Moves a tab from one position to another.
    ///
    /// The selection follows the moved tab so the user's active document does not change.
    ///
    /// - Parameters:
    ///   - from: Current index of the tab.
    ///   - to: Destination index.
    public func moveTab(from: Int, to: Int) {
        guard tabs.indices.contains(from),
              tabs.indices.contains(to),
              from != to else { return }

        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)

        // Keep the moved tab selected.
        if selectedIndex == from {
            selectedIndex = to
        } else if from < selectedIndex, to >= selectedIndex {
            selectedIndex -= 1
        } else if from > selectedIndex, to <= selectedIndex {
            selectedIndex += 1
        }

        onTabsChanged?()
    }

    /// Closes all tabs to the left of the given index.
    ///
    /// Pinned tabs are not closed. The selection adjusts to track the same tab when possible.
    ///
    /// - Parameter index: Reference index; tabs at indices `0..<index` are closed.
    public func closeTabsToLeft(of index: Int) {
        guard tabs.indices.contains(index) else { return }
        let kept = tabs[index]
        var indicesToRemove: [Int] = []
        for i in 0..<index {
            if !tabs[i].isPinned {
                indicesToRemove.append(i)
            }
        }
        // Remove from end to preserve indices
        for i in indicesToRemove.reversed() {
            tabs.remove(at: i)
        }
        // Recalculate selection to follow the kept tab
        if let newIndex = tabs.firstIndex(where: { $0.id == kept.id }) {
            selectedIndex = newIndex
        } else if tabs.isEmpty {
            selectedIndex = -1
        } else {
            selectedIndex = min(selectedIndex, tabs.count - 1)
        }
        onTabsChanged?()
    }

    /// Closes all tabs to the right of the given index.
    ///
    /// Pinned tabs are not closed. The selection adjusts to track the same tab when possible.
    ///
    /// - Parameter index: Reference index; tabs at indices `(index+1)...` are closed.
    public func closeTabsToRight(of index: Int) {
        guard tabs.indices.contains(index) else { return }
        let selectedTab = self.selectedTab
        var indicesToRemove: [Int] = []
        for i in (index + 1)..<tabs.count {
            if !tabs[i].isPinned {
                indicesToRemove.append(i)
            }
        }
        for i in indicesToRemove.reversed() {
            tabs.remove(at: i)
        }
        // Restore selection
        if let sel = selectedTab, let newIndex = tabs.firstIndex(where: { $0.id == sel.id }) {
            selectedIndex = newIndex
        } else if tabs.isEmpty {
            selectedIndex = -1
        } else {
            selectedIndex = min(selectedIndex, tabs.count - 1)
        }
        onTabsChanged?()
    }

    /// Closes all tabs that are not modified (unchanged).
    ///
    /// Pinned tabs are not closed regardless of modification state.
    /// The selection moves to the nearest remaining tab.
    public func closeUnchangedTabs() {
        let selectedTab = self.selectedTab
        tabs.removeAll { !$0.isModified && !$0.isPinned }

        if let sel = selectedTab, let newIndex = tabs.firstIndex(where: { $0.id == sel.id }) {
            selectedIndex = newIndex
        } else if tabs.isEmpty {
            selectedIndex = -1
        } else {
            selectedIndex = min(max(selectedIndex, 0), tabs.count - 1)
        }
        onTabsChanged?()
    }

    /// Toggles the pinned state of the tab at the given index.
    ///
    /// When a tab is pinned, it moves to the end of the pinned-tab group (leading edge).
    /// When unpinned, it moves to just after the last pinned tab.
    ///
    /// - Parameter index: Index of the tab to toggle.
    public func togglePin(at index: Int) {
        guard tabs.indices.contains(index) else { return }

        // Remember the currently selected tab's identity before mutating
        let previouslySelectedTab = self.selectedTab
        let tab = tabs[index]
        tab.isPinned.toggle()

        // Remove and reinsert at the correct position
        tabs.remove(at: index)
        let pinnedCount = tabs.filter { $0.isPinned }.count
        tabs.insert(tab, at: pinnedCount)

        // Restore selection to follow the previously-selected tab
        if let sel = previouslySelectedTab,
           let newIndex = tabs.firstIndex(where: { $0.id == sel.id }) {
            selectedIndex = newIndex
        } else {
            selectedIndex = min(max(selectedIndex, 0), tabs.count - 1)
        }

        onTabsChanged?()
    }

    /// Finds an existing tab whose `filePath` matches the given URL.
    ///
    /// - Parameter url: File URL to search for.
    /// - Returns: The matching `TabItem`, or `nil` if no tab has that path.
    public func tab(for url: URL) -> TabItem? {
        tabs.first { $0.filePath?.standardizedFileURL == url.standardizedFileURL }
    }
}
