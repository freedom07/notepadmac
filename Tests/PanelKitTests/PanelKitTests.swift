import XCTest
@testable import PanelKit

final class PanelDescriptorTests: XCTestCase {

    func testPanelDescriptorInit() {
        let desc = PanelDescriptor(
            id: "file-browser",
            title: "Files",
            position: .left,
            iconSystemName: "folder"
        )
        XCTAssertEqual(desc.id, "file-browser")
        XCTAssertEqual(desc.title, "Files")
        XCTAssertEqual(desc.position, .left)
        XCTAssertEqual(desc.iconSystemName, "folder")
    }

    func testPanelPositionCases() {
        let cases = PanelPosition.allCases
        XCTAssertEqual(cases.count, 3)
        XCTAssertTrue(cases.contains(.left))
        XCTAssertTrue(cases.contains(.right))
        XCTAssertTrue(cases.contains(.bottom))
    }

    func testPanelPositionRawValues() {
        XCTAssertEqual(PanelPosition.left.rawValue, "left")
        XCTAssertEqual(PanelPosition.right.rawValue, "right")
        XCTAssertEqual(PanelPosition.bottom.rawValue, "bottom")
    }
}

@available(macOS 13.0, *)
final class PanelContainerControllerTests: XCTestCase {

    func testAddAndRemovePanel() {
        let container = PanelContainerController(position: .left)
        _ = container.view // trigger loadView

        let panelVC = NSViewController()
        panelVC.view = NSView()
        let desc = PanelDescriptor(id: "test", title: "Test", position: .left, iconSystemName: "gear")
        container.addPanel(panelVC, descriptor: desc)

        XCTAssertTrue(container.hasPanel(id: "test"))
        // Panels start hidden (isVisible: false) until explicitly toggled
        XCTAssertFalse(container.hasVisiblePanels)

        container.removePanel(id: "test")
        XCTAssertFalse(container.hasPanel(id: "test"))
    }

    func testTogglePanel() {
        let container = PanelContainerController(position: .bottom)
        _ = container.view

        let panelVC = NSViewController()
        panelVC.view = NSView()
        let desc = PanelDescriptor(id: "results", title: "Results", position: .bottom, iconSystemName: "magnifyingglass")
        container.addPanel(panelVC, descriptor: desc)

        // Panels start hidden
        XCTAssertFalse(container.hasVisiblePanels)

        // Toggle on (first click shows)
        let shown = container.togglePanel(id: "results")
        XCTAssertTrue(shown)
        XCTAssertTrue(container.hasVisiblePanels)

        // Toggle off
        let hidden = container.togglePanel(id: "results")
        XCTAssertFalse(hidden)
        XCTAssertFalse(container.hasVisiblePanels)
    }

    func testMultiplePanels() {
        let container = PanelContainerController(position: .left)
        _ = container.view

        let vc1 = NSViewController()
        vc1.view = NSView()
        let vc2 = NSViewController()
        vc2.view = NSView()

        container.addPanel(vc1, descriptor: PanelDescriptor(id: "files", title: "Files", position: .left, iconSystemName: "folder"))
        container.addPanel(vc2, descriptor: PanelDescriptor(id: "funcs", title: "Functions", position: .left, iconSystemName: "function"))

        XCTAssertTrue(container.hasPanel(id: "files"))
        XCTAssertTrue(container.hasPanel(id: "funcs"))

        // Selecting second panel
        container.selectPanel(id: "funcs")
        // Both still registered
        XCTAssertTrue(container.hasPanel(id: "files"))

        container.removePanel(id: "files")
        XCTAssertFalse(container.hasPanel(id: "files"))
        XCTAssertTrue(container.hasPanel(id: "funcs"))
    }

    func testHasPanelReturnsFalseForUnknown() {
        let container = PanelContainerController(position: .right)
        _ = container.view
        XCTAssertFalse(container.hasPanel(id: "nonexistent"))
    }
}
