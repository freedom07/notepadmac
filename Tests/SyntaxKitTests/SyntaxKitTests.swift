import XCTest
@testable import SyntaxKit
import CommonKit

final class SyntaxKitTests: XCTestCase {
    func testLanguageRegistryLookupByExtension() {
        let registry = LanguageRegistry.shared
        XCTAssertNotNil(registry.language(forExtension: "swift"))
        XCTAssertNotNil(registry.language(forExtension: "py"))
        XCTAssertNotNil(registry.language(forExtension: "js"))
        XCTAssertNotNil(registry.language(forExtension: "html"))
        XCTAssertNotNil(registry.language(forExtension: "json"))
    }
    func testLanguageRegistryLookupByID() {
        XCTAssertNotNil(LanguageRegistry.shared.language(forID: "swift"))
        XCTAssertNotNil(LanguageRegistry.shared.language(forID: "python"))
    }
    func testAllLanguagesCount() {
        XCTAssertGreaterThanOrEqual(LanguageRegistry.shared.allLanguages.count, 29)
    }
    func testHighlightRulesExist() {
        for lang in LanguageRegistry.shared.allLanguages {
            XCTAssertGreaterThanOrEqual(lang.rules.count, 2, "\(lang.id) should have at least 2 rules")
        }
    }
    func testNewLanguageLookups() {
        let registry = LanguageRegistry.shared
        // PHP
        XCTAssertNotNil(registry.language(forExtension: "php"))
        XCTAssertNotNil(registry.language(forExtension: "phtml"))
        XCTAssertEqual(registry.language(forExtension: "php")?.id, "php")
        // Kotlin
        XCTAssertNotNil(registry.language(forExtension: "kt"))
        XCTAssertNotNil(registry.language(forExtension: "kts"))
        XCTAssertEqual(registry.language(forExtension: "kt")?.id, "kotlin")
        // Perl
        XCTAssertNotNil(registry.language(forExtension: "pl"))
        XCTAssertNotNil(registry.language(forExtension: "pm"))
        XCTAssertNotNil(registry.language(forExtension: "t"))
        XCTAssertEqual(registry.language(forExtension: "pl")?.id, "perl")
        // Lua
        XCTAssertNotNil(registry.language(forExtension: "lua"))
        XCTAssertEqual(registry.language(forExtension: "lua")?.id, "lua")
        // R
        XCTAssertNotNil(registry.language(forExtension: "r"))
        XCTAssertNotNil(registry.language(forExtension: "R"))
        XCTAssertEqual(registry.language(forExtension: "r")?.id, "r")
        // Dart
        XCTAssertNotNil(registry.language(forExtension: "dart"))
        XCTAssertEqual(registry.language(forExtension: "dart")?.id, "dart")
        // Objective-C
        XCTAssertNotNil(registry.language(forExtension: "m"))
        XCTAssertNotNil(registry.language(forExtension: "mm"))
        XCTAssertEqual(registry.language(forExtension: "m")?.id, "objc")
        // Scala
        XCTAssertNotNil(registry.language(forExtension: "scala"))
        XCTAssertNotNil(registry.language(forExtension: "sc"))
        XCTAssertEqual(registry.language(forExtension: "scala")?.id, "scala")
        // Diff
        XCTAssertNotNil(registry.language(forExtension: "diff"))
        XCTAssertNotNil(registry.language(forExtension: "patch"))
        XCTAssertEqual(registry.language(forExtension: "diff")?.id, "diff")
        // Makefile
        XCTAssertNotNil(registry.language(forExtension: "makefile"))
        XCTAssertNotNil(registry.language(forExtension: "mk"))
        XCTAssertEqual(registry.language(forExtension: "mk")?.id, "makefile")
    }
}
