# NotepadNext: Build System & CI/CD Pipeline Design

## 1. Project Setup & Architecture

### 1.1 Build System Choice: Xcode + SPM

**Recommendation: Xcode Project with SPM Dependencies**

For a Mac-native text editor, use Xcode project as the primary build system with SPM for dependency management:

```
Advantages:
- Native Xcode integration for AppKit development
- Superior code signing & notarization tooling
- Better asset management (xibs, storyboards, color sets)
- Faster incremental builds for UI development
- Debugger & Interface Builder integration
- Mature SwiftUI/AppKit support

vs Tuist:
- Tuist adds complexity without major benefits for a single macOS app
- Code generation overhead for incremental development
- Better suited for multi-app monorepos

vs Pure SPM:
- SPM lacks native targets for macOS app bundles
- Limited asset handling for resources
- Requires custom build scripts for notarization
```

### 1.2 Directory Structure

```
NotepadNext/
├── Sources/
│   ├── NotepadNext/                    # Main app target
│   │   ├── App/
│   │   │   ├── AppDelegate.swift
│   │   │   ├── main.swift
│   │   │   └── Application.swift
│   │   ├── Editor/
│   │   │   ├── EditorViewController.swift
│   │   │   ├── EditorView.swift
│   │   │   ├── EditorState.swift
│   │   │   └── Theme/
│   │   ├── Core/
│   │   │   ├── TextBuffer.swift         # Piece table implementation
│   │   │   ├── TextLine.swift
│   │   │   ├── Encoding.swift
│   │   │   ├── SearchEngine.swift
│   │   │   └── LineEndings.swift
│   │   ├── UI/
│   │   │   ├── Components/
│   │   │   ├── WindowController.swift
│   │   │   ├── Preferences/
│   │   │   └── Utilities/
│   │   ├── Plugins/
│   │   │   ├── PluginManager.swift
│   │   │   ├── PluginProtocol.swift
│   │   │   └── BuiltInPlugins/
│   │   ├── Syntax/
│   │   │   ├── TreeSitterBridge.swift
│   │   │   ├── LanguageProvider.swift
│   │   │   └── Languages/
│   │   ├── Themes/
│   │   │   ├── ThemeManager.swift
│   │   │   ├── ThemeParser.swift
│   │   │   └── Builtin/
│   │   ├── Resources/
│   │   │   ├── Localizable.xcstrings
│   │   │   ├── Assets.xcassets/
│   │   │   └── Languages/
│   │   └── Utilities/
│   │       ├── FileManager.swift
│   │       ├── Logger.swift
│   │       └── Preferences.swift
│   │
│   ├── NotepadNextCore/                # Framework target (reusable)
│   │   ├── TextBuffer.swift
│   │   ├── TextLine.swift
│   │   ├── Encoding.swift
│   │   ├── SearchEngine.swift
│   │   └── Public/
│   │       └── NotepadNextCore.h
│   │
│   └── SyntaxHighlighter/              # Framework target
│       ├── TreeSitterBridge.swift
│       ├── LanguageDefinition.swift
│       └── Public/
│           └── SyntaxHighlighter.h
│
├── Tests/
│   ├── NotepadNextTests/
│   │   ├── Core/
│   │   │   ├── TextBufferTests.swift
│   │   │   ├── EncodingTests.swift
│   │   │   └── SearchEngineTests.swift
│   │   ├── Editor/
│   │   │   ├── EditorViewTests.swift
│   │   │   └── ThemeTests.swift
│   │   └── Performance/
│   │       ├── LargeFileTests.swift
│   │       └── SearchPerformanceTests.swift
│   │
│   ├── UITests/
│   │   ├── EditorUITests.swift
│   │   ├── MenuTests.swift
│   │   └── PreferencesUITests.swift
│   │
│   └── SnapshotTests/
│       └── SyntaxHighlightingSnapshotTests.swift
│
├── Package.swift                       # SPM manifest
├── NotepadNext.xcodeproj/
│   ├── project.pbxproj
│   ├── xcshareddata/
│   │   ├── xcschemes/
│   │   │   ├── NotepadNext.xcscheme
│   │   │   ├── NotepadNextCore.xcscheme
│   │   │   └── Tests.xcscheme
│   │   └── CodeSnippets/
│   └── xcuserdata/
│
├── .github/
│   ├── workflows/
│   │   ├── build.yml
│   │   ├── test.yml
│   │   ├── lint.yml
│   │   ├── release.yml
│   │   └── notarize.yml
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── performance_issue.md
│   └── pull_request_template.md
│
├── Scripts/
│   ├── build-dmg.sh
│   ├── notarize.sh
│   ├── generate-appcast.sh
│   ├── extract-strings.sh
│   └── version-bump.sh
│
├── Resources/
│   ├── DMG/
│   │   ├── background.png
│   │   ├── background@2x.png
│   │   └── ds_store_template
│   ├── Languages/
│   │   ├── swift.json
│   │   ├── python.json
│   │   └── ...
│   └── Themes/
│       ├── default-light.json
│       ├── default-dark.json
│       └── ...
│
├── Docs/
│   ├── CONTRIBUTING.md
│   ├── ARCHITECTURE.md
│   ├── BUILDING.md
│   ├── CODE_STYLE.md
│   └── LOCALIZATION.md
│
├── .swiftformat                        # Code style config
├── .swiftlint.yml                      # Linting rules
├── .gitignore
└── README.md
```

### 1.3 Xcode Project Configuration

Create an Xcode project with proper target organization:

```swift
// Package.swift (for SPM dependencies)
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NotepadNext",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "NotepadNext", targets: ["NotepadNext"]),
        .library(name: "NotepadNextCore", targets: ["NotepadNextCore"]),
        .library(name: "SyntaxHighlighter", targets: ["SyntaxHighlighter"]),
    ],
    dependencies: [
        // Syntax Highlighting
        .package(url: "https://github.com/tree-sitter/tree-sitter-swift.git", 
                 from: "0.5.0"),
        
        // Markdown
        .package(url: "https://github.com/apple/swift-markdown.git",
                 from: "0.2.0"),
        
        // Auto-updates (choose one)
        // Option 1: Sparkle (via framework, not SPM)
        // Option 2: Use native macOS features
        
        // Logging
        .package(url: "https://github.com/apple/swift-log.git",
                 from: "1.5.0"),
        
        // Testing
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
                 from: "1.14.0"),
        
        // JSON parsing (for themes/language configs)
        // Built-in JSONDecoder is sufficient
    ],
    targets: [
        // Main app executable
        .executableTarget(
            name: "NotepadNext",
            dependencies: [
                "NotepadNextCore",
                "SyntaxHighlighter",
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/NotepadNext",
            resources: [
                .process("Resources"),
            ]
        ),
        
        // Core text engine (reusable)
        .target(
            name: "NotepadNextCore",
            dependencies: [],
            path: "Sources/NotepadNextCore"
        ),
        
        // Syntax highlighting
        .target(
            name: "SyntaxHighlighter",
            dependencies: [
                .product(name: "TreeSitter", package: "tree-sitter-swift"),
                "NotepadNextCore",
            ],
            path: "Sources/SyntaxHighlighter"
        ),
        
        // Unit tests
        .testTarget(
            name: "NotepadNextTests",
            dependencies: ["NotepadNextCore", "SyntaxHighlighter"],
            path: "Tests/NotepadNextTests"
        ),
        
        // UI tests
        .testTarget(
            name: "NotepadNextUITests",
            dependencies: ["NotepadNext"],
            path: "Tests/UITests"
        ),
        
        // Snapshot tests
        .testTarget(
            name: "SyntaxHighlightingSnapshotTests",
            dependencies: [
                "SyntaxHighlighter",
                .product(name: "SnapshotTesting", 
                        package: "swift-snapshot-testing"),
            ],
            path: "Tests/SnapshotTests"
        ),
    ]
)
```

---

## 2. Key Dependencies

### 2.1 Recommended Dependencies

| Dependency | Purpose | Integration | Status |
|-----------|---------|-----------|--------|
| tree-sitter-swift | Syntax highlighting | SPM package | Essential |
| swift-markdown | Markdown parsing | SPM package | Optional |
| swift-log | Structured logging | SPM package | Recommended |
| SnapshotTesting | Testing syntax output | SPM package (test only) | Recommended |
| Sparkle | Auto-updates | Framework (CocoaPods) | Optional but nice |

### 2.2 Tree-Sitter Integration

Tree-Sitter provides blazingly fast syntax highlighting:

```swift
// SyntaxHighlighter/TreeSitterBridge.swift

import TreeSitter

public class TreeSitterHighlighter {
    private let language: TSLanguage
    private let parser: TSParser
    
    public init(language: String) throws {
        guard let language = ts_language_for_name(language) else {
            throw HighlightError.unsupportedLanguage(language)
        }
        
        self.language = language
        self.parser = ts_parser_new()
        ts_parser_set_language(self.parser, language)
    }
    
    public func highlight(source: String) -> [HighlightRange] {
        let bytes = source.utf8
        let tree = ts_parser_parse_string(parser, nil, 
                                         Array(bytes), 
                                         UInt32(bytes.count))
        defer { ts_tree_delete(tree) }
        
        var ranges: [HighlightRange] = []
        walkTree(ts_tree_root_node(tree), source: source, ranges: &ranges)
        return ranges
    }
    
    private func walkTree(_ node: TSNode, 
                         source: String, 
                         ranges: inout [HighlightRange]) {
        let type = String(cString: ts_node_type(node))
        let startByte = Int(ts_node_start_byte(node))
        let endByte = Int(ts_node_end_byte(node))
        
        // Map tree-sitter node types to token types
        let tokenType = mapNodeType(type)
        
        ranges.append(HighlightRange(
            start: startByte,
            end: endByte,
            type: tokenType
        ))
        
        for i in 0..<ts_node_child_count(node) {
            let child = ts_node_child(node, i)
            walkTree(child, source: source, ranges: &ranges)
        }
    }
    
    private func mapNodeType(_ type: String) -> TokenType {
        switch type {
        case "keyword": return .keyword
        case "function": return .function
        case "string": return .string
        case "comment": return .comment
        case "number": return .number
        default: return .default
        }
    }
    
    deinit {
        ts_parser_delete(parser)
    }
}

public enum TokenType {
    case keyword, function, string, comment, number, `default`
}

public struct HighlightRange {
    public let start: Int
    public let end: Int
    public let type: TokenType
}

public enum HighlightError: Error {
    case unsupportedLanguage(String)
    case parsingFailed
}
```

### 2.3 Auto-Updates with Sparkle

While Sparkle isn't available via SPM, integrate it as a framework:

```swift
// Sources/NotepadNext/App/UpdateManager.swift

import Sparkle

class UpdateManager {
    static let shared = UpdateManager()
    
    private let updater: SPUUpdater
    
    init() {
        // Use Sparkle for checking and installing updates
        updater = SPUUpdater(hostBundle: Bundle.main,
                            applicationBundle: Bundle.main,
                            userDriver: SPUStandardUserDriver(
                                hostBundle: Bundle.main),
                            delegate: nil)
    }
    
    func checkForUpdates() {
        updater.checkForUpdates()
    }
    
    func automaticallyCheckForUpdates() {
        updater.automaticallyChecksForUpdates = true
        updater.checkForUpdatesInBackground()
    }
}
```

**Installation:**
```bash
# CocoaPods (if using)
pod 'Sparkle'

# Or: Download and link framework manually from Sparkle releases
```

### 2.4 Dependency Philosophy

```
MINIMIZE external dependencies:
✓ Use native macOS frameworks (AppKit, Foundation)
✓ Use Swift Package Manager for critical libraries
✓ Prefer system frameworks (Threading, Collections)
✗ Avoid heavy frameworks (RxSwift, Combine complexity)
✗ Bundle only what's necessary

Current minimal footprint:
- tree-sitter-swift (syntax highlighting core)
- swift-log (logging abstraction)
- SnapshotTesting (testing only)
- Sparkle (optional, for auto-updates)
```

---

## 3. Testing Strategy

### 3.1 Test Target Organization

```
NotepadNextTests/
├── Core/
│   ├── TextBufferTests.swift           # Unit tests for piece table
│   ├── EncodingTests.swift             # Character encoding
│   └── SearchEngineTests.swift         # Search/replace logic
├── Editor/
│   ├── EditorViewTests.swift
│   └── ThemeTests.swift
├── Performance/
│   ├── LargeFileTests.swift            # Large file handling
│   └── SearchPerformanceTests.swift    # Search speed benchmarks
└── Utilities/
    └── PreferencesTests.swift

UITests/
├── EditorUITests.swift                 # Editor interactions
├── MenuTests.swift                     # Menu functionality
└── PreferencesUITests.swift            # Settings UI

SnapshotTests/
└── SyntaxHighlightingSnapshotTests.swift
```

### 3.2 Unit Tests: Text Engine

```swift
// Tests/NotepadNextTests/Core/TextBufferTests.swift

import XCTest
@testable import NotepadNextCore

final class TextBufferTests: XCTestCase {
    var buffer: TextBuffer!
    
    override func setUp() {
        super.setUp()
        buffer = TextBuffer()
    }
    
    func testInsertText() {
        buffer.insert("Hello", at: 0)
        XCTAssertEqual(buffer.text, "Hello")
        XCTAssertEqual(buffer.length, 5)
    }
    
    func testDeleteText() {
        buffer.insert("Hello World", at: 0)
        buffer.delete(range: 5..<11)
        XCTAssertEqual(buffer.text, "Hello")
    }
    
    func testReplaceText() {
        buffer.insert("Hello World", at: 0)
        buffer.replace(range: 0..<5, with: "Hi")
        XCTAssertEqual(buffer.text, "Hi World")
    }
    
    func testUndoRedo() {
        buffer.insert("Hello", at: 0)
        buffer.insert(" World", at: 5)
        XCTAssertEqual(buffer.text, "Hello World")
        
        buffer.undo()
        XCTAssertEqual(buffer.text, "Hello")
        
        buffer.redo()
        XCTAssertEqual(buffer.text, "Hello World")
    }
    
    func testLargeFilePerformance() {
        measure(metrics: [XCTClockMetric()]) {
            let largeText = String(repeating: "x", count: 1_000_000)
            buffer.insert(largeText, at: 0)
            _ = buffer.text
        }
    }
    
    func testLineOperations() {
        buffer.insert("Line 1\nLine 2\nLine 3", at: 0)
        
        let line2 = buffer.line(at: 1)
        XCTAssertEqual(line2?.text, "Line 2")
        
        let lineCount = buffer.lineCount
        XCTAssertEqual(lineCount, 3)
    }
    
    func testEncodingDetection() {
        let utf8Data = "Hello".data(using: .utf8)!
        let detected = TextEncoding.detect(data: utf8Data)
        XCTAssertEqual(detected, .utf8)
    }
}

// Tests/NotepadNextTests/Core/SearchEngineTests.swift

import XCTest
@testable import NotepadNextCore

final class SearchEngineTests: XCTestCase {
    var buffer: TextBuffer!
    var search: SearchEngine!
    
    override func setUp() {
        super.setUp()
        buffer = TextBuffer()
        search = SearchEngine(buffer: buffer)
    }
    
    func testBasicSearch() {
        buffer.insert("The quick brown fox", at: 0)
        
        let results = search.find("brown")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].range, 10..<15)
    }
    
    func testCaseSensitiveSearch() {
        buffer.insert("Hello hello HELLO", at: 0)
        
        let results = search.find("Hello", caseSensitive: true)
        XCTAssertEqual(results.count, 1)
    }
    
    func testRegexSearch() {
        buffer.insert("test123 and test456", at: 0)
        
        let results = search.findRegex("test\\d+")
        XCTAssertEqual(results.count, 2)
    }
    
    func testSearchPerformance() {
        let largeText = (0..<100_000).map { "line\($0)\n" }.joined()
        buffer.insert(largeText, at: 0)
        
        measure(metrics: [XCTClockMetric()]) {
            _ = search.find("line50000")
        }
    }
}
```

### 3.3 Snapshot Tests: Syntax Highlighting

```swift
// Tests/SnapshotTests/SyntaxHighlightingSnapshotTests.swift

import XCTest
import SnapshotTesting
@testable import SyntaxHighlighter

final class SyntaxHighlightingSnapshotTests: XCTestCase {
    func testSwiftHighlighting() throws {
        let source = """
        func fibonacci(n: Int) -> Int {
            if n <= 1 { return n }
            return fibonacci(n - 1) + fibonacci(n - 2)
        }
        """
        
        let highlighter = try TreeSitterHighlighter(language: "swift")
        let ranges = highlighter.highlight(source: source)
        
        assertSnapshot(of: ranges, as: .json)
    }
    
    func testPythonHighlighting() throws {
        let source = """
        def fibonacci(n):
            if n <= 1:
                return n
            return fibonacci(n - 1) + fibonacci(n - 2)
        """
        
        let highlighter = try TreeSitterHighlighter(language: "python")
        let ranges = highlighter.highlight(source: source)
        
        assertSnapshot(of: ranges, as: .json)
    }
    
    func testMarkdownHighlighting() throws {
        let source = """
        # Title
        
        This is **bold** and *italic* text.
        
        ```swift
        let x = 42
        ```
        """
        
        let highlighter = try TreeSitterHighlighter(language: "markdown")
        let ranges = highlighter.highlight(source: source)
        
        assertSnapshot(of: ranges, as: .json)
    }
}
```

### 3.4 UI Tests

```swift
// Tests/UITests/EditorUITests.swift

import XCTest

final class EditorUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launch()
    }
    
    func testOpenFile() {
        let menuBars = app.menuBars
        menuBars.menus.matching(NSPredicate(format: "label == 'File'"))
            .element.click()
        
        let openMenuItem = app.menuItems["Open"]
        openMenuItem.click()
        
        // File dialog handling
        XCTAssertTrue(app.windows.count > 0)
    }
    
    func testTextEditing() {
        let editor = app.textViews.firstMatch
        editor.click()
        
        editor.typeText("Hello World")
        let text = editor.value as? String
        XCTAssertEqual(text, "Hello World")
    }
    
    func testFindAndReplace() {
        let menuBars = app.menuBars
        menuBars.menus.matching(NSPredicate(format: "label == 'Edit'"))
            .element.click()
        
        app.menuItems["Find"].click()
        
        let findField = app.textFields.firstMatch
        findField.typeText("Hello")
        
        // Verify find results
        XCTAssertTrue(app.staticTexts["1 of 1"].exists)
    }
    
    func testThemeSwitching() {
        // Navigate to Preferences
        // Change theme
        // Verify UI updates
    }
}
```

### 3.5 Test Execution Configuration

```yaml
# .github/workflows/test.yml (part of CI, see section 4)

name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run unit tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64' \
            -testPlan UnitTests \
            -resultBundlePath test-results
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results

  performance-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run performance tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -testPlan PerformanceTests \
            -destination 'platform=macOS,arch=arm64'

  snapshot-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run snapshot tests
        run: |
          xcodebuild test \
            -scheme SyntaxHighlightingSnapshotTests \
            -destination 'platform=macOS,arch=arm64'
      
      - name: Upload snapshot diffs (on failure)
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: snapshot-diffs
          path: ./__snapshots__
```

---

## 4. CI/CD Pipeline (GitHub Actions)

### 4.1 Build Workflow

```yaml
# .github/workflows/build.yml

name: Build

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for versioning
      
      - name: Setup Xcode
        run: |
          sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
          xcodebuild -version
      
      - name: Cache SPM
        uses: actions/cache@v3
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: ${{ runner.os }}-spm-${{ hashFiles('Package.swift.lock') }}
          restore-keys: |
            ${{ runner.os }}-spm-
      
      - name: Build for Release
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -configuration Release \
            -destination 'platform=macOS,arch=arm64,variant=native' \
            -derivedDataPath build
      
      - name: Build for Testing
        run: |
          xcodebuild build-for-testing \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64,variant=native' \
            -derivedDataPath build
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build-artifacts
          path: build/Build/Products
```

### 4.2 Test Workflow

```yaml
# .github/workflows/test.yml

name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  unit-tests:
    runs-on: macos-latest
    strategy:
      matrix:
        xcode-version: ['14.3', '15.0']
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode version
        run: sudo xcode-select -s "/Applications/Xcode_${{ matrix.xcode-version }}.app"
      
      - name: Run unit tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -testPlan UnitTests \
            -destination 'platform=macOS,arch=arm64,variant=native' \
            -enableCodeCoverage YES \
            -resultBundlePath test-results.xcresult
      
      - name: Generate coverage report
        run: |
          xcrun xccov view test-results.xcresult > coverage.txt
          cat coverage.txt
      
      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.txt
          flags: unittests
          fail_ci_if_error: false

  snapshot-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run snapshot tests
        run: |
          xcodebuild test \
            -scheme SyntaxHighlightingSnapshotTests \
            -destination 'platform=macOS,arch=arm64,variant=native'
      
      - name: Upload snapshot diffs
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: snapshot-diffs
          path: ./__snapshots__

  performance-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Run performance tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -testPlan PerformanceTests \
            -destination 'platform=macOS,arch=arm64,variant=native' \
            -resultBundlePath perf-results.xcresult
      
      - name: Parse performance metrics
        run: |
          xcrun xccov view perf-results.xcresult > perf-metrics.txt
      
      - name: Comment on PR with performance metrics
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const metrics = fs.readFileSync('perf-metrics.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Performance Metrics\n```\n' + metrics + '\n```'
            });
```

### 4.3 Linting & Code Quality

```yaml
# .github/workflows/lint.yml

name: Code Quality

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  swift-format:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install swift-format
        run: |
          brew install swift-format
      
      - name: Check code formatting
        run: |
          swift-format lint \
            --recursive \
            --configuration .swift-format \
            Sources Tests
      
      - name: Comment on PR if formatting needed
        if: failure() && github.event_name == 'pull_request'
        run: |
          swift-format format -r --configuration .swift-format Sources Tests
          git diff > formatting.patch
        
      - name: Upload formatting patch
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: formatting-patch
          path: formatting.patch

  swiftlint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install SwiftLint
        run: brew install swiftlint
      
      - name: Run SwiftLint
        run: swiftlint lint --strict --config .swiftlint.yml
      
      - name: Comment violations on PR
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const { execSync } = require('child_process');
            const output = execSync('swiftlint lint --config .swiftlint.yml', {
              encoding: 'utf8'
            });
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## SwiftLint Issues\n```\n' + output + '\n```'
            });

  security-scan:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run security linter
        run: |
          # Check for hardcoded secrets
          brew install truffleHog
          trufflehog filesystem . --json > security-report.json || true
      
      - name: Check dependencies for vulnerabilities
        run: |
          # Use OWASP Dependency-Check or similar
          xcodebuild clean build -dry-run \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64'
```

### 4.4 Release & Notarization Workflow

```yaml
# .github/workflows/release.yml

name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-notarize:
    runs-on: macos-latest
    
    env:
      APPLE_ID: ${{ secrets.APPLE_ID }}
      APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
      TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
      NOTARY_PROFILE: ${{ secrets.NOTARY_PROFILE }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Setup certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.APPLE_CERTIFICATE_BASE64 }}
          CERTIFICATE_PASSWORD: ${{ secrets.APPLE_CERTIFICATE_PASSWORD }}
        run: |
          echo $CERTIFICATE_BASE64 | base64 -D > certificate.p12
          security create-keychain -p "" build.keychain
          security unlock-keychain -p "" build.keychain
          security import certificate.p12 \
            -k build.keychain \
            -P $CERTIFICATE_PASSWORD \
            -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -k "" build.keychain
      
      - name: Build for distribution
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -configuration Release \
            -destination 'platform=macOS,arch=arm64' \
            -keychain build.keychain \
            -signingStyle automatic \
            -derivedDataPath build
      
      - name: Create app bundle
        run: |
          mkdir -p dist
          cp -r build/Build/Products/Release/NotepadNext.app dist/
      
      - name: Code sign app
        run: |
          codesign --verbose=4 \
            --sign "$TEAM_ID" \
            --timestamp \
            --options=runtime \
            dist/NotepadNext.app
      
      - name: Create DMG
        run: |
          ./Scripts/build-dmg.sh \
            --app dist/NotepadNext.app \
            --output dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg
      
      - name: Notarize DMG
        run: |
          ./Scripts/notarize.sh \
            --dmg dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg \
            --apple-id $APPLE_ID \
            --password $APPLE_ID_PASSWORD \
            --team-id $TEAM_ID
      
      - name: Staple notarization
        run: |
          xcrun stapler staple \
            dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg
      
      - name: Create zip archive
        run: |
          cd dist
          zip -r NotepadNext-${{ steps.version.outputs.VERSION }}.zip \
            NotepadNext.app
      
      - name: Generate appcast entry
        id: appcast
        run: |
          ./Scripts/generate-appcast.sh \
            --version ${{ steps.version.outputs.VERSION }} \
            --dmg dist/NotepadNext-${{ steps.version.outputs.VERSION }}.dmg \
            --zip dist/NotepadNext-${{ steps.version.outputs.VERSION }}.zip \
            --notes CHANGELOG.md
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            dist/NotepadNext-*.dmg
            dist/NotepadNext-*.zip
          body_path: CHANGELOG.md
          draft: false
          prerelease: ${{ contains(github.ref, '-') }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Update Sparkle appcast
        run: |
          git config user.name "Release Bot"
          git config user.email "noreply@github.com"
          git add appcast.xml
          git commit -m "Update appcast for v${{ steps.version.outputs.VERSION }}"
          git push
      
      - name: Clean up
        if: always()
        run: |
          security delete-keychain build.keychain
          rm -f certificate.p12
```

### 4.5 Notarization Script

```bash
#!/bin/bash
# Scripts/notarize.sh

set -e

DMG=""
APPLE_ID=""
PASSWORD=""
TEAM_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dmg) DMG="$2"; shift 2 ;;
        --apple-id) APPLE_ID="$2"; shift 2 ;;
        --password) PASSWORD="$2"; shift 2 ;;
        --team-id) TEAM_ID="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [[ -z "$DMG" ]] || [[ -z "$APPLE_ID" ]]; then
    echo "Usage: notarize.sh --dmg <path> --apple-id <id> --password <pwd> --team-id <id>"
    exit 1
fi

echo "Submitting $DMG for notarization..."

xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --password "$PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

echo "Notarization complete!"
```

---

## 5. Release Process

### 5.1 Semantic Versioning

```
Version format: MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]

Examples:
  1.0.0       - Initial release
  1.1.0       - New features
  1.1.1       - Bug fix
  1.1.0-beta1 - Beta release
  2.0.0-rc1   - Release candidate
```

### 5.2 Version Bump Script

```bash
#!/bin/bash
# Scripts/version-bump.sh

set -e

CURRENT_VERSION=$(grep -m1 'MARKETING_VERSION' NotepadNext.xcodeproj/project.pbxproj | \
    sed 's/.*MARKETING_VERSION = //; s/;.*//' | xargs)

echo "Current version: $CURRENT_VERSION"
echo "Select version type: (major|minor|patch|custom)"
read VERSION_TYPE

case $VERSION_TYPE in
    major)
        NEW_VERSION=$(echo $CURRENT_VERSION | awk -F. '{print ($1+1)".0.0"}')
        ;;
    minor)
        NEW_VERSION=$(echo $CURRENT_VERSION | awk -F. '{print $1".".($2+1)".0"}')
        ;;
    patch)
        NEW_VERSION=$(echo $CURRENT_VERSION | awk -F. '{print $1"."$2".".($3+1)}')
        ;;
    custom)
        read -p "Enter new version: " NEW_VERSION
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo "Bumping version from $CURRENT_VERSION to $NEW_VERSION"

# Update Xcode project
sed -i '' "s/MARKETING_VERSION = $CURRENT_VERSION/MARKETING_VERSION = $NEW_VERSION/" \
    NotepadNext.xcodeproj/project.pbxproj

# Update Info.plist (if exists)
if [[ -f "Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" Info.plist
fi

# Create git tag
git add NotepadNext.xcodeproj/project.pbxproj Info.plist 2>/dev/null || true
git commit -m "Bump version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"

echo "Version bumped to $NEW_VERSION"
echo "Push with: git push && git push --tags"
```

### 5.3 Changelog Generation

```bash
#!/bin/bash
# Scripts/generate-changelog.sh

# Generate changelog from git commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "$LAST_TAG" ]]; then
    COMMITS=$(git log --oneline)
else
    COMMITS=$(git log --oneline $LAST_TAG..HEAD)
fi

echo "# Changelog" > CHANGELOG_TEMP.md
echo "" >> CHANGELOG_TEMP.md

# Parse commits by type
echo "## Features" >> CHANGELOG_TEMP.md
echo "$COMMITS" | grep "^[^:]*: feat" | sed 's/^[^:]*: /- /' >> CHANGELOG_TEMP.md

echo "" >> CHANGELOG_TEMP.md
echo "## Bug Fixes" >> CHANGELOG_TEMP.md
echo "$COMMITS" | grep "^[^:]*: fix" | sed 's/^[^:]*: /- /' >> CHANGELOG_TEMP.md

echo "" >> CHANGELOG_TEMP.md
echo "## Other Changes" >> CHANGELOG_TEMP.md
echo "$COMMITS" | grep -v "^[^:]*: feat\|^[^:]*: fix" | sed 's/^/- /' >> CHANGELOG_TEMP.md

cat CHANGELOG_TEMP.md CHANGELOG.md > CHANGELOG_NEW.md
mv CHANGELOG_NEW.md CHANGELOG.md
rm CHANGELOG_TEMP.md
```

### 5.4 DMG Creation

```bash
#!/bin/bash
# Scripts/build-dmg.sh

set -e

APP=""
OUTPUT=""
BACKGROUND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --app) APP="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --background) BACKGROUND="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -z "$APP" ]] || [[ -z "$OUTPUT" ]]; then
    echo "Usage: build-dmg.sh --app <app> --output <dmg> [--background <png>]"
    exit 1
fi

TEMP_DMG="/tmp/NotepadNext-temp.dmg"
MOUNT_POINT="/tmp/NotepadNext-mount"

# Create temporary DMG
hdiutil create -volname "NotepadNext" \
    -srcfolder "$APP" \
    -ov -format UDRW "$TEMP_DMG"

# Mount DMG
mkdir -p "$MOUNT_POINT"
hdiutil attach -mountpoint "$MOUNT_POINT" "$TEMP_DMG"

# Add background if provided
if [[ -n "$BACKGROUND" ]]; then
    mkdir -p "$MOUNT_POINT/.background"
    cp "$BACKGROUND" "$MOUNT_POINT/.background/background.png"
fi

# Create symlink to Applications
ln -s /Applications "$MOUNT_POINT/Applications"

# Set window properties using AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "NotepadNext"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        
        set bounds of container window to {0, 0, 512, 384}
        set position of item "NotepadNext.app" to {64, 96}
        set position of item "Applications" to {320, 96}
        
        set background picture of icon view options of container window \
            to file ".background:background.png"
        
        close
        eject
    end tell
end tell
EOF

# Unmount
hdiutil detach "$MOUNT_POINT"

# Compress to final DMG
hdiutil convert "$TEMP_DMG" -format ULFO -o "$OUTPUT"
rm "$TEMP_DMG"

echo "DMG created: $OUTPUT"
```

---

## 6. Development Workflow

### 6.1 Git Strategy

```
Branch naming:
  - main         (stable, production-ready)
  - develop      (integration branch)
  - feature/*    (new features)
  - fix/*        (bug fixes)
  - release/*    (release preparation)

Commit message format:
  type(scope): subject

  Types: feat, fix, refactor, perf, test, docs, style, chore
  Example:
    feat(editor): add multi-selection support
    
    - Implement rectangular selection mode
    - Add keyboard shortcuts for selection
    - Tests added

Protection rules:
  main:
    - Require PR review (1 reviewer)
    - Require status checks to pass
    - Require branches to be up-to-date
    - Dismiss stale reviews
    - Allow auto-merge

  develop:
    - Require PR review (1 reviewer)
    - Require status checks to pass
    - Allow auto-merge
```

### 6.2 PR Template

```markdown
# .github/pull_request_template.md

## Description
Brief description of changes.

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactoring
- [ ] Performance improvement
- [ ] Documentation
- [ ] Dependencies update

## Changes
- Change 1
- Change 2

## Testing
How to test these changes?

## Screenshots (if applicable)
Add before/after screenshots.

## Checklist
- [ ] Code follows style guidelines (swift-format, SwiftLint)
- [ ] Tests added/updated and all pass
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Linked to issue

## Related Issues
Closes #123

## Notes
Any additional context.
```

### 6.3 Issue Templates

```markdown
# .github/ISSUE_TEMPLATE/bug_report.md

---
name: Bug Report
about: Report a bug
title: "[BUG] "
labels: bug
---

## Description
Clear description of the bug.

## Steps to Reproduce
1. Step 1
2. Step 2
3. ...

## Expected Behavior
What should happen.

## Actual Behavior
What actually happened.

## Environment
- macOS version:
- NotepadNext version:
- Xcode version (for developers):

## Screenshots
If applicable, add screenshots.

## Additional Context
Any other relevant info.

---
# .github/ISSUE_TEMPLATE/feature_request.md

---
name: Feature Request
about: Suggest an improvement
title: "[FEATURE] "
labels: enhancement
---

## Description
Clear description of the requested feature.

## Use Case
Why this feature is needed.

## Proposed Solution
How you envision this working.

## Alternatives
Other approaches considered.

## Additional Context
Any other relevant info.
```

### 6.4 Contributing Guidelines

```markdown
# CONTRIBUTING.md

## Getting Started

### Prerequisites
- macOS 12.0 or later
- Xcode 14.3 or later
- Git

### Setup
```bash
git clone https://github.com/username/NotepadNext.git
cd NotepadNext
git checkout develop
xcode_select --install  # If needed
```

### Building
```bash
xcodebuild build -scheme NotepadNext \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64'
```

### Running Tests
```bash
xcodebuild test -scheme NotepadNext \
  -destination 'platform=macOS,arch=arm64'
```

## Development Workflow

1. Create feature branch: `git checkout -b feature/amazing-feature`
2. Make changes following code style
3. Write/update tests
4. Run tests locally
5. Commit with clear message
6. Push to your fork
7. Create Pull Request

## Code Style

### Swift Code
- Follow [Google Swift Style Guide](https://google.github.io/swift)
- Max line length: 120 characters
- Use 4-space indentation
- Run swift-format before committing:
  ```bash
  swift-format format -r Sources Tests
  ```

### Naming Conventions
- Classes/Structs: PascalCase
- Functions/Variables: camelCase
- Constants: camelCase
- Private properties: leading underscore optional

### Documentation
Document public APIs with doc comments:
```swift
/// Brief description.
///
/// Longer description explaining usage.
///
/// - Parameter name: Description
/// - Returns: Description
/// - Throws: Possible errors
public func example(name: String) throws -> String
```

## Testing Requirements

- Unit tests for new features
- Tests for bug fixes
- Maintain >80% code coverage
- All tests must pass locally before PR

## Commit Message Guidelines

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types: feat, fix, docs, style, refactor, perf, test, chore, ci

Example:
```
feat(editor): add line wrapping toggle

Add button to toggle line wrapping in editor view.
Update settings to persist preference.

Closes #42
```

## Pull Request Process

1. Update CHANGELOG.md
2. Ensure all tests pass
3. Ensure code formatting is correct
4. Request review from maintainers
5. Address review feedback
6. Wait for approval before merging

## Reporting Issues

Use bug report template for bugs.
Use feature request template for features.
Include reproduction steps and environment info.

## Questions?

- Check existing issues/discussions
- Open a new discussion
- Contact maintainers

Thank you for contributing!
```

### 6.5 Code Style Configuration

```swift
// .swiftformat
--rules
# Remove redundant parentheses
redundantParens

# Format closures
closingBrace

# Standardize numeric literals
numberFormatting

# Sort imports
sortedImports

# Mark empty functions
markEmptyFunctions
--exclude Tests
```

```yaml
# .swiftlint.yml
disabled_rules:
  - line_length
  - nesting
  - type_name
opt_in_rules:
  - force_unwrapping
  - redundant_string_enum_value
  - strict_fileprivate
excluded:
  - Pods
  - .build
line_length: 120
function_body_length: 150
type_body_length: 200
force_cast: error
force_try: warning
```

---

## 7. Localization

### 7.1 String Catalog (.xcstrings)

```
Modern approach using Xcode 15+ String Catalog:

1. Create Localizable.xcstrings:
   - Xcode automatically generates from string literals
   - Supports translations in Xcode UI
   - No manual .strings files needed

2. Swift code:
   String(localized: "Welcome to NotepadNext")
   String(localized: "Line count: \(lineCount)", 
          defaultValue: "Line count: default")

3. Pluralization:
   String(localized: "^[\\(count) line](inflect: true)", 
          defaultValue: "lines")
```

### 7.2 Supported Languages

Priority order for localization:

1. **Tier 1 (Essential)**
   - English (en-US)
   - Korean (ko-KR)
   - Japanese (ja-JP)
   - Simplified Chinese (zh-Hans)

2. **Tier 2 (Community-driven)**
   - German (de-DE)
   - French (fr-FR)
   - Spanish (es-ES)
   - Portuguese (pt-BR)
   - Russian (ru-RU)

3. **Tier 3 (Contributed)**
   - Italian, Dutch, Polish, etc.

### 7.3 Localization Workflow

```bash
# Scripts/extract-strings.sh
#!/bin/bash

# Extract strings from source code
genstrings -o Resources/Localization Sources/NotepadNext/**/*.swift

# Generate .xliff for translators
xcodebuild -exportLocalizations \
    -localizationPath Resources/Localization \
    -project NotepadNext.xcodeproj

# After translation, import back
xcodebuild -importLocalizations \
    -localizationPath Resources/Localization/Translated.xliff \
    -project NotepadNext.xcodeproj
```

### 7.4 String Localization in Code

```swift
// Sources/NotepadNext/Resources/Strings+Generated.swift

import Foundation

extension String {
    // Menu items
    static var menuFile: String { 
        String(localized: "File") 
    }
    static var menuEdit: String { 
        String(localized: "Edit") 
    }
    static var menuSearch: String { 
        String(localized: "Search") 
    }
    
    // Dialogs
    static var confirmClose: String {
        String(localized: "Save changes before closing?")
    }
    static var confirmDelete: String {
        String(localized: "Are you sure?")
    }
    
    // Status messages
    static func lineCount(_ count: Int) -> String {
        String(localized: "^[\\(count) line](inflect: true)",
               defaultValue: "lines")
    }
}

// Usage
label.stringValue = .menuFile
button.title = .confirmDelete
status.stringValue = .lineCount(42)
```

---

## 8. Dependency Management Policy

### 8.1 Minimal Footprint Principle

```swift
APPROVED DEPENDENCIES (essential):
✓ tree-sitter-swift       - Syntax highlighting (core feature)
✓ swift-log               - Structured logging
✓ SnapshotTesting (test)  - Testing infrastructure

EVALUATE BEFORE ADDING:
? New dependencies must have:
  - Active maintenance
  - <10 transitive dependencies
  - Good test coverage
  - Clear documentation
  
DISCOURAGE:
✗ RxSwift, Combine (unnecessary complexity)
✗ ORM frameworks (use Core Data)
✗ Network libraries (use URLSession)
✗ Heavy UI frameworks (AppKit is native)
```

### 8.2 Dependency Update Policy

```yaml
# Dependabot configuration (.github/dependabot.yml)
version: 2
updates:
  - package-ecosystem: swift
    directory: "/"
    schedule:
      interval: weekly
    allow:
      - dependency-type: indirect
      - dependency-type: direct
    reviewers:
      - main-maintainer
    groups:
      development:
        dependency-types:
          - "dev-dependencies"
        update-types:
          - "minor"
          - "patch"
      production:
        dependency-types:
          - "production"
        update-types:
          - "patch"
```

---

## 9. Build Configuration Summary

### Build Settings Recommendations

```
SWIFT_VERSION: 5.9
SWIFT_STRICT_CONCURRENCY: complete
IPHONEOS_DEPLOYMENT_TARGET: N/A (macOS only)
MACOSX_DEPLOYMENT_TARGET: 12.0
APPLE_CLANG_CXX_LANGUAGE_DIALECT: c++17
ENABLE_TESTABILITY: Yes (Debug), No (Release)
CODE_SIGN_IDENTITY: Apple Development / Distribution
PROVISIONING_PROFILE_SPECIFIER: (auto)
ENABLE_BITCODE: No
STRIP_INSTALLED_PRODUCT: Yes (Release)
```

### Performance Optimization

```
Release build:
- Dead code stripping: Yes
- Link-time optimization: Yes
- Optimization level: Aggressive [-Osize or -Ofast]
- Whole module optimization: Yes
- Generate debug symbols (separate): Yes

Debug build:
- Optimization level: None [-Onone]
- Generate debug symbols: Yes
- Enable address sanitizer: Yes
- Enable undefined behavior sanitizer: Yes
```

---

## 10. Monitoring & Observability

### Build Metrics to Track

```
Key metrics:
- Build time (target: <2 min full build)
- Test execution time (target: <30 sec unit tests)
- Code coverage (target: >80%)
- Release build size (target: <50 MB)
- Number of dependencies (target: <5)
- PR review turnaround (target: <24 hours)

Monitoring:
- GitHub Actions build matrix success rates
- Test coverage trends
- Performance benchmark regressions
- Release cycle frequency
```

---

## Getting Started Checklist

- [ ] Initialize Xcode project with proper targets
- [ ] Create Package.swift with SPM dependencies
- [ ] Set up directory structure
- [ ] Create .xcworkspace if using Carthage/CocoaPods
- [ ] Configure GitHub Actions workflows
- [ ] Create PR and issue templates
- [ ] Set up branch protection rules
- [ ] Create CONTRIBUTING.md and CODE_STYLE.md
- [ ] Configure SwiftFormat and SwiftLint
- [ ] Create test targets with proper organization
- [ ] Add localization support
- [ ] Create release scripts
- [ ] Set up Apple Developer credentials (for notarization)
- [ ] Document build process in BUILDING.md
