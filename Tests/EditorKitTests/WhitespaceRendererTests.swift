import XCTest
@testable import EditorKit

final class WhitespaceRendererTests: XCTestCase {

    // MARK: - WhitespaceMode Enum Tests

    func testWhitespaceModeRawValues() {
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.hidden.rawValue, 0)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.spacesAndTabs.rawValue, 1)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.eolOnly.rawValue, 2)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.allCharacters.rawValue, 3)
    }

    func testWhitespaceModeInitFromRawValue() {
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode(rawValue: 0), .hidden)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode(rawValue: 1), .spacesAndTabs)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode(rawValue: 2), .eolOnly)
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode(rawValue: 3), .allCharacters)
        XCTAssertNil(WhitespaceLayoutManager.WhitespaceMode(rawValue: 99))
    }

    func testWhitespaceModeDisplayNames() {
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.hidden.displayName, "Hide")
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.spacesAndTabs.displayName, "Spaces & Tabs")
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.eolOnly.displayName, "Line Endings")
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.allCharacters.displayName, "All Characters")
    }

    func testWhitespaceModeAllCasesCount() {
        XCTAssertEqual(WhitespaceLayoutManager.WhitespaceMode.allCases.count, 4)
    }

    func testWhitespaceModeAllCasesOrder() {
        let allCases = WhitespaceLayoutManager.WhitespaceMode.allCases
        XCTAssertEqual(allCases[0], .hidden)
        XCTAssertEqual(allCases[1], .spacesAndTabs)
        XCTAssertEqual(allCases[2], .eolOnly)
        XCTAssertEqual(allCases[3], .allCharacters)
    }

    // MARK: - WhitespaceLayoutManager Instance Tests

    func testDefaultModeIsHidden() {
        let layoutManager = WhitespaceLayoutManager()
        XCTAssertEqual(layoutManager.whitespaceMode, .hidden)
    }

    func testModeCanBeChanged() {
        let layoutManager = WhitespaceLayoutManager()

        layoutManager.whitespaceMode = .spacesAndTabs
        XCTAssertEqual(layoutManager.whitespaceMode, .spacesAndTabs)

        layoutManager.whitespaceMode = .eolOnly
        XCTAssertEqual(layoutManager.whitespaceMode, .eolOnly)

        layoutManager.whitespaceMode = .allCharacters
        XCTAssertEqual(layoutManager.whitespaceMode, .allCharacters)

        layoutManager.whitespaceMode = .hidden
        XCTAssertEqual(layoutManager.whitespaceMode, .hidden)
    }

    func testDefaultWhitespaceColor() {
        let layoutManager = WhitespaceLayoutManager()
        XCTAssertNotNil(layoutManager.whitespaceColor)
    }

    func testWhitespaceColorCanBeChanged() {
        let layoutManager = WhitespaceLayoutManager()
        let customColor = NSColor.red.withAlphaComponent(0.3)
        layoutManager.whitespaceColor = customColor
        XCTAssertEqual(layoutManager.whitespaceColor, customColor)
    }

    func testModeSwitchingRoundTrip() {
        let layoutManager = WhitespaceLayoutManager()
        for mode in WhitespaceLayoutManager.WhitespaceMode.allCases {
            layoutManager.whitespaceMode = mode
            XCTAssertEqual(layoutManager.whitespaceMode, mode)
        }
    }

    func testSettingSameModeDoesNotCrash() {
        let layoutManager = WhitespaceLayoutManager()
        layoutManager.whitespaceMode = .hidden
        layoutManager.whitespaceMode = .hidden
        XCTAssertEqual(layoutManager.whitespaceMode, .hidden)
    }

    func testModeEqualityAndInequality() {
        let a: WhitespaceLayoutManager.WhitespaceMode = .spacesAndTabs
        let b: WhitespaceLayoutManager.WhitespaceMode = .spacesAndTabs
        let c: WhitespaceLayoutManager.WhitespaceMode = .eolOnly
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
