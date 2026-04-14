import XCTest
@testable import TabKit
import CommonKit

final class TabKitTests: XCTestCase {

    // MARK: - TabItem Tests

    func testTabItemInit() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let tab = TabItem(title: "test.txt", filePath: url, isModified: true, isPinned: true)

        XCTAssertFalse(tab.id.uuidString.isEmpty)
        XCTAssertEqual(tab.title, "test.txt")
        XCTAssertEqual(tab.filePath, url)
        XCTAssertTrue(tab.isModified)
        XCTAssertTrue(tab.isPinned)
    }

    func testTabItemInitDefaults() {
        let tab = TabItem(title: "Untitled")

        XCTAssertEqual(tab.title, "Untitled")
        XCTAssertNil(tab.filePath)
        XCTAssertFalse(tab.isModified)
        XCTAssertFalse(tab.isPinned)
    }

    func testTabItemTooltipWithFilePath() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let tab = TabItem(title: "test.txt", filePath: url)

        XCTAssertEqual(tab.tooltip, "/tmp/test.txt")
    }

    func testTabItemTooltipWithoutFilePath() {
        let tab = TabItem(title: "Untitled")

        XCTAssertEqual(tab.tooltip, "Untitled")
    }

    func testTabItemEquality() {
        let tab = TabItem(title: "A")
        let sameTab = tab

        XCTAssertTrue(tab.isEqual(sameTab))
    }

    func testTabItemInequality() {
        let tab1 = TabItem(title: "A")
        let tab2 = TabItem(title: "A")

        XCTAssertFalse(tab1.isEqual(tab2))
    }

    func testTabItemEqualityWithNonTabItem() {
        let tab = TabItem(title: "A")

        XCTAssertFalse(tab.isEqual("not a tab"))
    }

    func testTabItemHashConsistency() {
        let tab = TabItem(title: "A")

        XCTAssertEqual(tab.hash, tab.id.hashValue)
    }

    // MARK: - TabManager Tests

    func testAddTab() {
        let manager = TabManager()

        XCTAssertEqual(manager.tabs.count, 0)

        let tab = manager.addTab(title: "File1")

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(tab.title, "File1")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testAddMultipleTabs() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")

        XCTAssertEqual(manager.tabs.count, 3)
        XCTAssertEqual(manager.selectedIndex, 2)
    }

    func testCloseTab() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")

        manager.closeTab(at: 0)

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].title, "File2")
    }

    func testCloseLastRemainingTab() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.closeTab(at: 0)

        XCTAssertEqual(manager.tabs.count, 0)
        XCTAssertEqual(manager.selectedIndex, -1)
    }

    func testCloseTabAdjustsSelectionWhenSelectedAfterClosed() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")
        manager.selectTab(at: 2)

        manager.closeTab(at: 0)

        XCTAssertEqual(manager.selectedIndex, 1)
    }

    func testCloseTabAtInvalidIndex() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.closeTab(at: 5)

        XCTAssertEqual(manager.tabs.count, 1)
    }

    func testCloseOtherTabs() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")

        manager.closeOtherTabs(except: 1)

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].title, "File2")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testCloseOtherTabsInvalidIndex() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")

        manager.closeOtherTabs(except: 5)

        XCTAssertEqual(manager.tabs.count, 2)
    }

    func testCloseAllTabs() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")

        manager.closeAllTabs()

        XCTAssertEqual(manager.tabs.count, 0)
        XCTAssertEqual(manager.selectedIndex, -1)
    }

    func testSelectTab() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")

        manager.selectTab(at: 0)

        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testSelectTabInvalidIndex() {
        let manager = TabManager()

        manager.addTab(title: "File1")
        manager.selectTab(at: 10)

        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testMoveTab() {
        let manager = TabManager()

        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 0)

        manager.moveTab(from: 0, to: 2)

        XCTAssertEqual(manager.tabs[0].title, "B")
        XCTAssertEqual(manager.tabs[1].title, "C")
        XCTAssertEqual(manager.tabs[2].title, "A")
        XCTAssertEqual(manager.selectedIndex, 2)
    }

    func testMoveTabSameIndex() {
        let manager = TabManager()

        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.selectTab(at: 0)

        manager.moveTab(from: 0, to: 0)

        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testMoveTabInvalidIndex() {
        let manager = TabManager()

        manager.addTab(title: "A")

        manager.moveTab(from: 0, to: 5)

        XCTAssertEqual(manager.tabs[0].title, "A")
    }

    func testMoveTabSelectionFollowsWhenNotMoved() {
        let manager = TabManager()

        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 1)

        // Move tab from after selection to before it
        manager.moveTab(from: 2, to: 0)

        XCTAssertEqual(manager.selectedIndex, 2)
    }

    func testMoveTabSelectionAdjustsWhenMovedBefore() {
        let manager = TabManager()

        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 1)

        // Move tab from before selection to after it
        manager.moveTab(from: 0, to: 2)

        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testTabForURL() {
        let manager = TabManager()
        let url = URL(fileURLWithPath: "/tmp/hello.swift")

        manager.addTab(title: "hello.swift", filePath: url)
        manager.addTab(title: "world.swift", filePath: URL(fileURLWithPath: "/tmp/world.swift"))

        let found = manager.tab(for: url)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.title, "hello.swift")
    }

    func testTabForURLNotFound() {
        let manager = TabManager()

        manager.addTab(title: "hello.swift", filePath: URL(fileURLWithPath: "/tmp/hello.swift"))

        let found = manager.tab(for: URL(fileURLWithPath: "/tmp/missing.swift"))

        XCTAssertNil(found)
    }

    func testSelectedTab() {
        let manager = TabManager()

        XCTAssertNil(manager.selectedTab)

        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.selectTab(at: 0)

        XCTAssertEqual(manager.selectedTab?.title, "File1")
    }

    func testSelectedTabNilWhenEmpty() {
        let manager = TabManager()

        XCTAssertNil(manager.selectedTab)
        XCTAssertEqual(manager.selectedIndex, -1)
    }

    func testOnTabsChangedCalledOnAdd() {
        let manager = TabManager()
        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.addTab(title: "File1")

        // addTab triggers onTabsChanged via both selectedIndex didSet and explicit call
        XCTAssertGreaterThan(callCount, 0)
    }

    func testOnTabsChangedCalledOnClose() {
        let manager = TabManager()
        manager.addTab(title: "File1")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.closeTab(at: 0)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testOnTabsChangedCalledOnCloseAll() {
        let manager = TabManager()
        manager.addTab(title: "File1")
        manager.addTab(title: "File2")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.closeAllTabs()

        XCTAssertGreaterThan(callCount, 0)
    }

    func testOnTabsChangedCalledOnSelect() {
        let manager = TabManager()
        manager.addTab(title: "File1")
        manager.addTab(title: "File2")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.selectTab(at: 0)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testOnTabsChangedCalledOnMove() {
        let manager = TabManager()
        manager.addTab(title: "File1")
        manager.addTab(title: "File2")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.moveTab(from: 0, to: 1)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testCloseTabSelectionWhenSelectedAtEnd() {
        let manager = TabManager()
        manager.addTab(title: "File1")
        manager.addTab(title: "File2")
        manager.addTab(title: "File3")
        // selectedIndex is 2 (last added)

        manager.closeTab(at: 2)

        XCTAssertEqual(manager.selectedIndex, 1)
    }

    func testAddTabWithFilePath() {
        let manager = TabManager()
        let url = URL(fileURLWithPath: "/tmp/test.txt")

        let tab = manager.addTab(title: "test.txt", filePath: url)

        XCTAssertEqual(tab.filePath, url)
    }

    // MARK: - closeTabsToLeft Tests

    func testCloseTabsToLeft() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.addTab(title: "D")
        manager.selectTab(at: 2) // Select "C"

        manager.closeTabsToLeft(of: 2)

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].title, "C")
        XCTAssertEqual(manager.tabs[1].title, "D")
        XCTAssertEqual(manager.selectedIndex, 0) // "C" is now at 0
    }

    func testCloseTabsToLeftAtZero() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.selectTab(at: 0)

        manager.closeTabsToLeft(of: 0)

        // Nothing to close to the left of index 0
        XCTAssertEqual(manager.tabs.count, 2)
    }

    func testCloseTabsToLeftInvalidIndex() {
        let manager = TabManager()
        manager.addTab(title: "A")

        manager.closeTabsToLeft(of: 5)

        XCTAssertEqual(manager.tabs.count, 1)
    }

    func testCloseTabsToLeftPreservesPinnedTabs() {
        let manager = TabManager()
        let pinned = manager.addTab(title: "Pinned")
        pinned.isPinned = true
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 2)

        manager.closeTabsToLeft(of: 2)

        // "Pinned" at 0 should survive, "B" at 1 should be closed
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].title, "Pinned")
        XCTAssertEqual(manager.tabs[1].title, "C")
    }

    // MARK: - closeTabsToRight Tests

    func testCloseTabsToRight() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.addTab(title: "D")
        manager.selectTab(at: 1) // Select "B"

        manager.closeTabsToRight(of: 1)

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.tabs[1].title, "B")
        XCTAssertEqual(manager.selectedIndex, 1)
    }

    func testCloseTabsToRightAtEnd() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.selectTab(at: 1)

        manager.closeTabsToRight(of: 1)

        // Nothing to close to the right
        XCTAssertEqual(manager.tabs.count, 2)
    }

    func testCloseTabsToRightInvalidIndex() {
        let manager = TabManager()
        manager.addTab(title: "A")

        manager.closeTabsToRight(of: 5)

        XCTAssertEqual(manager.tabs.count, 1)
    }

    func testCloseTabsToRightPreservesPinnedTabs() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        let pinned = manager.addTab(title: "Pinned")
        pinned.isPinned = true
        manager.addTab(title: "D")
        manager.selectTab(at: 0)

        manager.closeTabsToRight(of: 0)

        // "Pinned" at index 2 should survive, "B" and "D" should be closed
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.tabs[1].title, "Pinned")
    }

    func testCloseTabsToRightWhenSelectedIsRight() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        // selectedIndex is 2 (C)

        manager.closeTabsToRight(of: 0)

        // B and C removed. Selection adjusts.
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    // MARK: - closeUnchangedTabs Tests

    func testCloseUnchangedTabs() {
        let manager = TabManager()
        let a = manager.addTab(title: "A")
        a.isModified = true
        manager.addTab(title: "B") // unchanged
        let c = manager.addTab(title: "C")
        c.isModified = true
        manager.addTab(title: "D") // unchanged
        manager.selectTab(at: 0)

        manager.closeUnchangedTabs()

        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.tabs[1].title, "C")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testCloseUnchangedTabsPreservesPinned() {
        let manager = TabManager()
        manager.addTab(title: "A") // unchanged, not pinned
        let pinned = manager.addTab(title: "Pinned")
        pinned.isPinned = true // unchanged but pinned
        manager.selectTab(at: 1)

        manager.closeUnchangedTabs()

        // "A" is removed (unchanged, not pinned), "Pinned" survives (pinned)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].title, "Pinned")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    func testCloseUnchangedTabsAllModified() {
        let manager = TabManager()
        let a = manager.addTab(title: "A")
        a.isModified = true
        let b = manager.addTab(title: "B")
        b.isModified = true

        manager.closeUnchangedTabs()

        XCTAssertEqual(manager.tabs.count, 2)
    }

    func testCloseUnchangedTabsAllUnchanged() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")

        manager.closeUnchangedTabs()

        XCTAssertEqual(manager.tabs.count, 0)
        XCTAssertEqual(manager.selectedIndex, -1)
    }

    func testCloseUnchangedTabsSelectionFollowsModified() {
        let manager = TabManager()
        manager.addTab(title: "A") // unchanged
        let b = manager.addTab(title: "B")
        b.isModified = true
        manager.addTab(title: "C") // unchanged
        manager.selectTab(at: 1) // select B

        manager.closeUnchangedTabs()

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.tabs[0].title, "B")
        XCTAssertEqual(manager.selectedIndex, 0)
    }

    // MARK: - togglePin Tests

    func testTogglePinBasic() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 1)

        manager.togglePin(at: 1) // Pin "B"

        XCTAssertTrue(manager.tabs[0].isPinned)
        XCTAssertEqual(manager.tabs[0].title, "B")
        XCTAssertEqual(manager.selectedIndex, 0) // selection follows B
    }

    func testTogglePinUnpin() {
        let manager = TabManager()
        let a = manager.addTab(title: "A")
        a.isPinned = true
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 0) // select pinned A

        manager.togglePin(at: 0) // Unpin "A"

        XCTAssertFalse(manager.tabs[0].isPinned)
        XCTAssertEqual(manager.tabs[0].title, "A") // stays at 0 (no other pinned tabs)
    }

    func testTogglePinMovesToPinnedGroup() {
        let manager = TabManager()
        let a = manager.addTab(title: "A")
        a.isPinned = true
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 2) // select C

        manager.togglePin(at: 2) // Pin "C"

        // C should move to index 1 (after A which is pinned)
        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertTrue(manager.tabs[0].isPinned)
        XCTAssertEqual(manager.tabs[1].title, "C")
        XCTAssertTrue(manager.tabs[1].isPinned)
        XCTAssertEqual(manager.tabs[2].title, "B")
        XCTAssertFalse(manager.tabs[2].isPinned)
        XCTAssertEqual(manager.selectedIndex, 1) // follows C
    }

    func testTogglePinInvalidIndex() {
        let manager = TabManager()
        manager.addTab(title: "A")

        manager.togglePin(at: 5)

        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertFalse(manager.tabs[0].isPinned)
    }

    func testTogglePinCallsOnTabsChanged() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.togglePin(at: 0)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testTogglePinSelectionFollowsNonToggled() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 0) // select A

        manager.togglePin(at: 2) // Pin C (not the selected tab)

        // A should remain selected, C moved to front
        XCTAssertEqual(manager.tabs[0].title, "C")
        XCTAssertEqual(manager.tabs[1].title, "A")
        XCTAssertEqual(manager.selectedIndex, 1) // A is now at index 1
    }

    // MARK: - moveTab Integration Tests

    func testMoveTabIntegrationWithPin() {
        let manager = TabManager()
        let a = manager.addTab(title: "A")
        a.isPinned = true
        manager.addTab(title: "B")
        manager.addTab(title: "C")
        manager.selectTab(at: 1)

        manager.moveTab(from: 2, to: 1)

        XCTAssertEqual(manager.tabs[0].title, "A")
        XCTAssertEqual(manager.tabs[1].title, "C")
        XCTAssertEqual(manager.tabs[2].title, "B")
        XCTAssertEqual(manager.selectedIndex, 2) // B moved from 1 to 2
    }

    func testCloseTabsToLeftCallsOnTabsChanged() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.closeTabsToLeft(of: 2)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testCloseTabsToRightCallsOnTabsChanged() {
        let manager = TabManager()
        manager.addTab(title: "A")
        manager.addTab(title: "B")
        manager.addTab(title: "C")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.closeTabsToRight(of: 0)

        XCTAssertGreaterThan(callCount, 0)
    }

    func testCloseUnchangedTabsCallsOnTabsChanged() {
        let manager = TabManager()
        manager.addTab(title: "A")

        var callCount = 0
        manager.onTabsChanged = { callCount += 1 }

        manager.closeUnchangedTabs()

        XCTAssertGreaterThan(callCount, 0)
    }
}
