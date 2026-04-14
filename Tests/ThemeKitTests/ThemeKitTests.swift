import XCTest
@testable import ThemeKit
import CommonKit
import AppKit

final class ThemeKitTests: XCTestCase {

    // MARK: - Existing Tests

    func testHexToColorConversion() {
        let color = Theme.colorFromHex("#FF0000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
    }
    func testThemeManagerHas24Themes() {
        XCTAssertGreaterThanOrEqual(ThemeManager.shared.availableThemes.count, 24)
    }
    func testThemeManagerSetTheme() {
        let manager = ThemeManager.shared
        let monokai = manager.availableThemes.first { $0.name == "Monokai" }!
        manager.setTheme(monokai)
        XCTAssertEqual(manager.currentTheme.name, "Monokai")
    }
    func testBuiltinThemesDarkAndLightBalance() {
        let themes = ThemeManager.shared.availableThemes
        let dark = themes.filter { $0.type == .dark }.count
        let light = themes.filter { $0.type == .light }.count
        XCTAssertGreaterThan(dark, 0)
        XCTAssertGreaterThan(light, 0)
    }

    func testInvalidHexColor() {
        let color = Theme.colorFromHex("not-a-hex")
        XCTAssertEqual(color, .labelColor, "Invalid hex should return labelColor")
    }

    func testThemeNotFound() {
        let result = ThemeManager.shared.theme(named: "nonexistent")
        XCTAssertNil(result, "theme(named:) should return nil for unknown theme names")
    }

    // MARK: - colorFromHex Tests

    func testColorFromHexWithoutHash() {
        let color = Theme.colorFromHex("FF0000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01, "Red channel should be 1.0 for FF0000 without #")
        XCTAssertEqual(g, 0.0, accuracy: 0.01, "Green channel should be 0.0 for FF0000 without #")
        XCTAssertEqual(b, 0.0, accuracy: 0.01, "Blue channel should be 0.0 for FF0000 without #")
    }

    func testColorFromHexShortString() {
        // 3-char hex like "FFF" is not 6 chars, should fall back to .labelColor
        let color = Theme.colorFromHex("FFF")
        XCTAssertEqual(color, .labelColor, "3-char hex should fall back to labelColor")
    }

    func testColorFromHexEmpty() {
        let color = Theme.colorFromHex("")
        XCTAssertEqual(color, .labelColor, "Empty string should fall back to labelColor")
    }

    func testColorFromHexBlueChannel() {
        let color = Theme.colorFromHex("#0000FF")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01, "Red channel should be 0.0 for #0000FF")
        XCTAssertEqual(g, 0.0, accuracy: 0.01, "Green channel should be 0.0 for #0000FF")
        XCTAssertEqual(b, 1.0, accuracy: 0.01, "Blue channel should be 1.0 for #0000FF")
    }

    // MARK: - tokenAttributes Tests

    func testTokenAttributesBold() {
        let theme = Theme(
            name: "Test", type: .dark,
            colors: [:],
            tokenColors: ["keyword": TokenStyle(foreground: "#FF0000", fontStyle: "bold")]
        )
        let attrs = theme.tokenAttributes(forKey: "keyword")
        let font = attrs[.font] as? NSFont
        XCTAssertNotNil(font, "Bold fontStyle should produce a font attribute")
        XCTAssertEqual(font, NSFont.monospacedSystemFont(ofSize: 13, weight: .bold))
    }

    func testTokenAttributesItalic() {
        let theme = Theme(
            name: "Test", type: .dark,
            colors: [:],
            tokenColors: ["comment": TokenStyle(foreground: "#00FF00", fontStyle: "italic")]
        )
        let attrs = theme.tokenAttributes(forKey: "comment")
        let font = attrs[.font] as? NSFont
        XCTAssertNotNil(font, "Italic fontStyle should produce a font attribute")
        let traits = font!.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.italic), "Font should have italic trait")
    }

    func testTokenAttributesBoldItalic() {
        let theme = Theme(
            name: "Test", type: .dark,
            colors: [:],
            tokenColors: ["type": TokenStyle(foreground: "#0000FF", fontStyle: "bold italic")]
        )
        let attrs = theme.tokenAttributes(forKey: "type")
        let font = attrs[.font] as? NSFont
        XCTAssertNotNil(font, "Bold italic fontStyle should produce a font attribute")
        let traits = font!.fontDescriptor.symbolicTraits
        XCTAssertTrue(traits.contains(.bold), "Font should have bold trait")
        XCTAssertTrue(traits.contains(.italic), "Font should have italic trait")
    }

    func testTokenAttributesNoFontStyle() {
        let theme = Theme(
            name: "Test", type: .dark,
            colors: [:],
            tokenColors: ["keyword": TokenStyle(foreground: "#FF0000", fontStyle: nil)]
        )
        let attrs = theme.tokenAttributes(forKey: "keyword")
        // Should have foregroundColor but no font key when fontStyle is nil
        XCTAssertNotNil(attrs[.foregroundColor], "Should have foreground color")
        XCTAssertNil(attrs[.font], "Should not have font attribute when fontStyle is nil")
    }

    func testTokenAttributesMissingKey() {
        let theme = Theme(
            name: "Test", type: .dark,
            colors: [:],
            tokenColors: [:]
        )
        let attrs = theme.tokenAttributes(forKey: "nonexistent")
        XCTAssertTrue(attrs.isEmpty, "Missing key should return empty dictionary")
    }

    // MARK: - Theme Codable Tests

    func testThemeCodableRoundTrip() {
        let original = Theme(
            name: "RoundTrip",
            type: .light,
            colors: ["editorBackground": "#FFFFFF", "editorForeground": "#000000"],
            tokenColors: [
                "keyword": TokenStyle(foreground: "#FF0000", fontStyle: "bold"),
                "comment": TokenStyle(foreground: "#00FF00", fontStyle: "italic"),
            ]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(Theme.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.colors["editorBackground"], "#FFFFFF")
        XCTAssertEqual(decoded.colors["editorForeground"], "#000000")
        XCTAssertEqual(decoded.tokenColors["keyword"]?.foreground, "#FF0000")
        XCTAssertEqual(decoded.tokenColors["keyword"]?.fontStyle, "bold")
        XCTAssertEqual(decoded.tokenColors["comment"]?.foreground, "#00FF00")
        XCTAssertEqual(decoded.tokenColors["comment"]?.fontStyle, "italic")
    }

    func testTokenStyleCodableRoundTrip() {
        let original = TokenStyle(foreground: "#ABC123", fontStyle: "bold italic")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(TokenStyle.self, from: data)

        XCTAssertEqual(decoded.foreground, original.foreground)
        XCTAssertEqual(decoded.fontStyle, original.fontStyle)
    }

    // MARK: - ThemeManager Tests

    func testThemeManagerOnThemeChangedCallback() {
        let manager = ThemeManager.shared
        var callbackThemeName: String?
        manager.onThemeChanged = { theme in
            callbackThemeName = theme.name
        }
        let dracula = manager.availableThemes.first { $0.name == "Dracula" }!
        manager.setTheme(dracula)
        XCTAssertEqual(callbackThemeName, "Dracula", "onThemeChanged callback should be invoked with the new theme")
        manager.onThemeChanged = nil
    }

    func testThemeManagerSetThemeUpdates() {
        let manager = ThemeManager.shared
        let nord = manager.availableThemes.first { $0.name == "Nord" }!
        manager.setTheme(nord)
        XCTAssertEqual(manager.currentTheme.name, "Nord", "currentTheme should update after setTheme")

        let monokai = manager.availableThemes.first { $0.name == "Monokai" }!
        manager.setTheme(monokai)
        XCTAssertEqual(manager.currentTheme.name, "Monokai", "currentTheme should update again after another setTheme")
    }

    func testThemeManagerThemeNamed() {
        let manager = ThemeManager.shared
        let found = manager.theme(named: "Dracula")
        XCTAssertNotNil(found, "theme(named:) should find existing theme")
        XCTAssertEqual(found?.name, "Dracula")

        let notFound = manager.theme(named: "Does Not Exist")
        XCTAssertNil(notFound, "theme(named:) should return nil for unknown names")
    }

    // MARK: - Builtin Theme Validation Tests

    func testAllBuiltinThemesHaveRequiredColorKeys() {
        let requiredKeys = [
            "editorBackground", "editorForeground", "lineHighlight",
            "selectionBackground", "cursor", "gutterBackground", "gutterForeground",
        ]
        for theme in BuiltinThemes.allBuiltinThemes {
            for key in requiredKeys {
                XCTAssertNotNil(
                    theme.colors[key],
                    "Theme '\(theme.name)' is missing required color key '\(key)'"
                )
            }
        }
    }

    func testAllBuiltinThemesHaveAllTokenColorKeys() {
        let requiredTokenKeys = ["keyword", "comment"]
        for theme in BuiltinThemes.allBuiltinThemes {
            for key in requiredTokenKeys {
                XCTAssertNotNil(
                    theme.tokenColors[key],
                    "Theme '\(theme.name)' is missing required token color key '\(key)'"
                )
            }
        }
    }

    // MARK: - Dark Mode System Integration Tests

    func testObserveSystemAppearanceDoesNotCrash() {
        // Calling observeSystemAppearance should register the observer without error
        ThemeManager.shared.observeSystemAppearance()
        // No crash means success; observer is registered
    }

    func testThemeManagerHasOneDarkTheme() {
        let theme = ThemeManager.shared.theme(named: "One Dark")
        XCTAssertNotNil(theme, "ThemeManager should have 'One Dark' theme for dark mode switching")
        XCTAssertEqual(theme?.type, .dark)
    }

    func testThemeManagerHasDefaultLightTheme() {
        let theme = ThemeManager.shared.theme(named: "Default Light")
        XCTAssertNotNil(theme, "ThemeManager should have 'Default Light' theme for light mode switching")
        XCTAssertEqual(theme?.type, .light)
    }

    func testAllBuiltinThemesValidHexColors() {
        let hexRegex = try! NSRegularExpression(pattern: "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$")
        for theme in BuiltinThemes.allBuiltinThemes {
            for (key, hex) in theme.colors {
                let range = NSRange(hex.startIndex..., in: hex)
                let matches = hexRegex.numberOfMatches(in: hex, range: range)
                XCTAssertEqual(
                    matches, 1,
                    "Theme '\(theme.name)' color key '\(key)' has invalid hex value '\(hex)'"
                )
            }
            for (key, style) in theme.tokenColors {
                let hex = style.foreground
                let range = NSRange(hex.startIndex..., in: hex)
                let matches = hexRegex.numberOfMatches(in: hex, range: range)
                XCTAssertEqual(
                    matches, 1,
                    "Theme '\(theme.name)' token '\(key)' has invalid hex foreground '\(hex)'"
                )
            }
        }
    }
}
