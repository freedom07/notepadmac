# NotepadNext: 실제 프로젝트 설정 가이드

## 단계 1: 프로젝트 초기화

### 1.1 디렉토리 구조 생성

```bash
mkdir -p NotepadNext
cd NotepadNext

# 핵심 디렉토리
mkdir -p Sources/{NotepadNext,NotepadNextCore,SyntaxHighlighter}
mkdir -p Tests/{NotepadNextTests,UITests,SnapshotTests}
mkdir -p Scripts Resources/{DMG,Languages,Themes}
mkdir -p Docs .github/workflows .github/ISSUE_TEMPLATE
mkdir -p Sources/NotepadNext/{App,Editor,Core,UI,Plugins,Syntax,Themes,Resources,Utilities}

# 초기화
git init
```

### 1.2 Package.swift 작성

```swift
cat > Package.swift << 'EOF'
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
        .package(url: "https://github.com/tree-sitter/tree-sitter-swift.git", 
                 from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-markdown.git",
                 from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-log.git",
                 from: "1.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git",
                 from: "1.14.0"),
    ],
    targets: [
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
        
        .target(
            name: "NotepadNextCore",
            dependencies: [],
            path: "Sources/NotepadNextCore"
        ),
        
        .target(
            name: "SyntaxHighlighter",
            dependencies: [
                .product(name: "TreeSitter", package: "tree-sitter-swift"),
                "NotepadNextCore",
            ],
            path: "Sources/SyntaxHighlighter"
        ),
        
        .testTarget(
            name: "NotepadNextTests",
            dependencies: ["NotepadNextCore", "SyntaxHighlighter"],
            path: "Tests/NotepadNextTests"
        ),
        
        .testTarget(
            name: "NotepadNextUITests",
            dependencies: ["NotepadNext"],
            path: "Tests/UITests"
        ),
        
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
EOF
```

### 1.3 Xcode 프로젝트 생성

```bash
# Xcode 프로젝트는 기존 Xcode 앱으로 생성하거나,
# 다음 명령으로 SPM 프로젝트에서 Xcode 프로젝트로 변환

# Option 1: xcodegen 사용 (권장)
brew install xcodegen

cat > project.yml << 'EOF'
name: NotepadNext

options:
  bundleIdPrefix: com.notepadnext
  deploymentTarget: "12.0"
  swiftVersion: "5.9"

settings:
  SWIFT_STRICT_CONCURRENCY: complete
  CODE_SIGN_IDENTITY: "Apple Development"

targets:
  NotepadNext:
    type: application
    platform: macOS
    sources:
      - path: Sources/NotepadNext
        excludes:
          - "**/*.swift"
      - path: Sources/NotepadNext
        extensions: [swift]
    dependencies:
      - target: NotepadNextCore
      - target: SyntaxHighlighter
      - package: swift-log
    settings:
      PRODUCT_NAME: NotepadNext
      EXECUTABLE_NAME: NotepadNext

  NotepadNextCore:
    type: framework
    platform: macOS
    sources: Sources/NotepadNextCore

  SyntaxHighlighter:
    type: framework
    platform: macOS
    sources: Sources/SyntaxHighlighter
    dependencies:
      - target: NotepadNextCore
      - package: tree-sitter-swift

  NotepadNextTests:
    type: unitTests
    platform: macOS
    sources: Tests/NotepadNextTests
    dependencies:
      - target: NotepadNextCore
      - target: SyntaxHighlighter

  UITests:
    type: uiTests
    platform: macOS
    sources: Tests/UITests
    dependencies:
      - target: NotepadNext

schemes:
  NotepadNext:
    build:
      targets:
        - NotepadNext
    run:
      config: Debug
    test:
      targets: [NotepadNextTests, UITests]
      config: Debug

packages:
  swift-log:
    url: https://github.com/apple/swift-log.git
    from: 1.5.0
  tree-sitter-swift:
    url: https://github.com/tree-sitter/tree-sitter-swift.git
    from: 0.5.0
EOF

xcodegen generate
```

### 1.4 기본 파일 생성

```bash
# .gitignore
cat > .gitignore << 'EOF'
# Xcode
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/
build/
.build/
*.xcworkspace/

# SwiftPM
.swiftpm/
Package.resolved

# IDE
.vscode/
.DS_Store
*.swp

# Testing
.junit.xml
test-results/
__snapshots__/

# Build artifacts
*.app
*.dmg
*.zip
dist/

# Certificates
certificate.p12
build.keychain

# Environment
.env
.env.local
EOF

# README.md
cat > README.md << 'EOF'
# NotepadNext

macOS를 위한 고속 텍스트 에디터. Notepad++의 클론을 목표로 합니다.

## 특징

- 빠른 텍스트 처리 (Piece Table 기반)
- 구문 강조 (Tree-Sitter 기반)
- 정규식 검색/치환
- 플러그인 시스템
- 다국어 지원
- 자동 업데이트

## 시스템 요구사항

- macOS 12.0 이상
- Xcode 14.3 이상 (개발자용)

## 빌드

```bash
git clone https://github.com/username/NotepadNext.git
cd NotepadNext
xcodebuild build -scheme NotepadNext -configuration Release
```

## 설치

DMG 파일에서 또는 직접 빌드하여 설치합니다.

## 개발

[CONTRIBUTING.md](CONTRIBUTING.md)를 참조하세요.

## 라이센스

GNU General Public License v3.0
EOF

# CONTRIBUTING.md
cat > CONTRIBUTING.md << 'EOF'
# 기여하기

감사합니다! 기여를 환영합니다.

## 시작하기

1. Fork 및 Clone
2. `develop` 브랜치에서 작업
3. 기능별 브랜치 생성: `git checkout -b feature/amazing`
4. 커밋: `git commit -m 'feat: 설명'`
5. Push 및 PR 제출

## 코드 스타일

swift-format 및 SwiftLint를 사용합니다:

```bash
swift-format format -r Sources Tests
swiftlint lint
```

## 테스트

PR 제출 전 테스트를 실행하세요:

```bash
xcodebuild test -scheme NotepadNext
```

자세한 내용은 [CONTRIBUTING.md](Docs/CONTRIBUTING.md)를 참조하세요.
EOF

git add .
git commit -m "Initial commit: project setup"
```

---

## 단계 2: 코드 스타일 구성

### 2.1 SwiftFormat 설정

```bash
cat > .swiftformat << 'EOF'
# Formatting rules
--rules
redundantParens
closingBrace
numberFormatting
sortedImports
markEmptyFunctions

# Configuration
--exclude Tests, .build
--indent 4
--linewidth 120
--semicolons never
--wraparguments preserve
--wrappercollections preserve
EOF

# 설치 및 실행
brew install swift-format

# 프로젝트 전체 포맷팅
swift-format format -r Sources Tests
```

### 2.2 SwiftLint 설정

```bash
cat > .swiftlint.yml << 'EOF'
# SwiftLint 구성

# 비활성화할 규칙
disabled_rules:
  - line_length      # 120으로 설정 (기본값 더 작음)
  - nesting          # 중첩 허용
  - cyclomatic_complexity

# 활성화할 옵션 규칙
opt_in_rules:
  - discouraged_optional_boolean
  - explicit_init
  - redundant_nil_coalescing
  - strict_fileprivate
  - unused_import
  - force_unwrapping

# 제외 경로
excluded:
  - Pods
  - .build
  - build

# 규칙 설정
line_length: 120
function_body_length: 150
type_body_length: 200

force_cast: error
force_try: warning
force_unwrapping: error

# 네이밍 규칙
type_name:
  min_length: 3
  max_length: 50

identifier_name:
  min_length: 2
  max_length: 40

function_parameter_count: 5
EOF

# 설치
brew install swiftlint

# 실행
swiftlint lint --strict
```

---

## 단계 3: 핵심 모듈 구현

### 3.1 TextBuffer (Piece Table)

```bash
cat > Sources/NotepadNextCore/TextBuffer.swift << 'EOF'
import Foundation

/// Piece Table 기반의 텍스트 버퍼
/// 대용량 파일에서 효율적인 편집을 제공합니다.
public class TextBuffer {
    private var originalContent: String
    private var addedContent: String = ""
    private var pieces: [Piece] = []
    
    private struct Piece {
        let buffer: Buffer  // original 또는 added
        let start: Int
        let length: Int
    }
    
    private enum Buffer {
        case original
        case added
    }
    
    // Undo/Redo
    private var undoStack: [Operation] = []
    private var redoStack: [Operation] = []
    
    private struct Operation {
        let type: OperationType
        let range: Range<Int>
        let text: String?
    }
    
    private enum OperationType {
        case insert
        case delete
    }
    
    public init(content: String = "") {
        self.originalContent = content
        if content.isEmpty {
            self.pieces = []
        } else {
            self.pieces = [
                Piece(buffer: .original, start: 0, length: content.count)
            ]
        }
    }
    
    public var text: String {
        pieces.map { piece -> String in
            let buffer = piece.buffer == .original ? originalContent : addedContent
            let start = buffer.index(buffer.startIndex, 
                                     offsetBy: piece.start)
            let end = buffer.index(start, 
                                   offsetBy: piece.length)
            return String(buffer[start..<end])
        }.joined()
    }
    
    public var length: Int {
        pieces.reduce(0) { $0 + $1.length }
    }
    
    public var lineCount: Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count
    }
    
    public func insert(_ text: String, at index: Int) {
        guard index >= 0 && index <= length else { return }
        
        // Record operation for undo
        undoStack.append(Operation(type: .insert, 
                                   range: index..<(index + text.count), 
                                   text: nil))
        redoStack.removeAll()
        
        let startIdx = addedContent.count
        addedContent.append(text)
        
        let newPiece = Piece(buffer: .added, 
                            start: startIdx, 
                            length: text.count)
        
        // Find insertion point in pieces
        var currentPos = 0
        for (i, piece) in pieces.enumerated() {
            if currentPos + piece.length >= index {
                if currentPos == index {
                    pieces.insert(newPiece, at: i)
                    return
                } else {
                    // Split piece
                    let offsetInPiece = index - currentPos
                    let beforePiece = Piece(buffer: piece.buffer,
                                          start: piece.start,
                                          length: offsetInPiece)
                    let afterPiece = Piece(buffer: piece.buffer,
                                         start: piece.start + offsetInPiece,
                                         length: piece.length - offsetInPiece)
                    pieces.replaceSubrange(i...i, 
                                          with: [beforePiece, newPiece, afterPiece])
                    return
                }
            }
            currentPos += piece.length
        }
        
        pieces.append(newPiece)
    }
    
    public func delete(range: Range<Int>) {
        guard range.lowerBound >= 0 && range.upperBound <= length else { return }
        
        let deletedText = text[text.index(text.startIndex, 
                                         offsetBy: range.lowerBound)..<text.index(text.startIndex,
                                                                                  offsetBy: range.upperBound)]
        
        undoStack.append(Operation(type: .delete,
                                   range: range,
                                   text: String(deletedText)))
        redoStack.removeAll()
        
        var currentPos = 0
        var newPieces: [Piece] = []
        var deleteStart = range.lowerBound
        var deleteEnd = range.upperBound
        
        for piece in pieces {
            let pieceEnd = currentPos + piece.length
            
            if pieceEnd <= deleteStart || currentPos >= deleteEnd {
                // Keep entire piece
                newPieces.append(piece)
            } else {
                // Partial or complete deletion
                let offsetStart = max(0, deleteStart - currentPos)
                let offsetEnd = min(piece.length, deleteEnd - currentPos)
                
                if offsetStart > 0 {
                    newPieces.append(Piece(buffer: piece.buffer,
                                          start: piece.start,
                                          length: offsetStart))
                }
                if offsetEnd < piece.length {
                    newPieces.append(Piece(buffer: piece.buffer,
                                          start: piece.start + offsetEnd,
                                          length: piece.length - offsetEnd))
                }
            }
            currentPos = pieceEnd
        }
        
        pieces = newPieces
    }
    
    public func replace(range: Range<Int>, with text: String) {
        delete(range: range)
        insert(text, at: range.lowerBound)
    }
    
    public func undo() {
        guard !undoStack.isEmpty else { return }
        let operation = undoStack.removeLast()
        
        switch operation.type {
        case .insert:
            delete(range: operation.range)
            if let text = operation.text {
                redoStack.append(Operation(type: .delete,
                                          range: operation.range,
                                          text: text))
            }
        case .delete:
            if let text = operation.text {
                insert(text, at: operation.range.lowerBound)
                redoStack.append(Operation(type: .insert,
                                          range: operation.range,
                                          text: nil))
            }
        }
    }
    
    public func redo() {
        guard !redoStack.isEmpty else { return }
        let operation = redoStack.removeLast()
        
        switch operation.type {
        case .insert:
            insert(operation.text ?? "", at: operation.range.lowerBound)
            undoStack.append(Operation(type: .insert,
                                      range: operation.range,
                                      text: nil))
        case .delete:
            delete(range: operation.range)
            undoStack.append(Operation(type: .delete,
                                      range: operation.range,
                                      text: operation.text))
        }
    }
    
    public func line(at index: Int) -> TextLine? {
        let lines = text.split(separator: "\n", 
                              omittingEmptySubsequences: false,
                              omittingEmptySubsequences: false)
        guard index < lines.count else { return nil }
        return TextLine(number: index, text: String(lines[index]))
    }
}

public struct TextLine {
    public let number: Int
    public let text: String
}
EOF
```

### 3.2 SearchEngine

```bash
cat > Sources/NotepadNextCore/SearchEngine.swift << 'EOF'
import Foundation

public class SearchEngine {
    private weak var buffer: TextBuffer?
    
    public init(buffer: TextBuffer) {
        self.buffer = buffer
    }
    
    public struct SearchResult {
        public let range: Range<Int>
        public let lineNumber: Int
    }
    
    public func find(_ query: String, 
                    caseSensitive: Bool = false) -> [SearchResult] {
        guard let buffer = buffer else { return [] }
        let text = buffer.text
        let searchText = caseSensitive ? query : query.lowercased()
        let source = caseSensitive ? text : text.lowercased()
        
        var results: [SearchResult] = []
        var searchRange = source.startIndex..<source.endIndex
        
        while let range = source.range(of: searchText, range: searchRange) {
            let startOffset = source.distance(from: source.startIndex, to: range.lowerBound)
            let endOffset = startOffset + searchText.count
            
            let lineNumber = text[text.startIndex..<text.index(text.startIndex, offsetBy: startOffset)]
                .filter { $0 == "\n" }
                .count
            
            results.append(SearchResult(range: startOffset..<endOffset,
                                       lineNumber: lineNumber))
            
            searchRange = range.upperBound..<source.endIndex
        }
        
        return results
    }
    
    public func findRegex(_ pattern: String) -> [SearchResult] {
        guard let buffer = buffer,
              let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let text = buffer.text
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        
        var results: [SearchResult] = []
        let matches = regex.matches(in: text, range: range)
        
        for match in matches {
            let matchRange = match.range
            let startOffset = matchRange.location
            let endOffset = startOffset + matchRange.length
            
            let lineNumber = nsText.substring(to: startOffset)
                .filter { $0 == "\n" }
                .count
            
            results.append(SearchResult(range: startOffset..<endOffset,
                                       lineNumber: lineNumber))
        }
        
        return results
    }
}
EOF
```

### 3.3 Encoding Detection

```bash
cat > Sources/NotepadNextCore/Encoding.swift << 'EOF'
import Foundation

public enum TextEncoding: String {
    case utf8 = "UTF-8"
    case utf16 = "UTF-16"
    case utf32 = "UTF-32"
    case ascii = "ASCII"
    case iso8859_1 = "ISO-8859-1"
    case cp1252 = "Windows-1252"
    
    public static func detect(data: Data) -> TextEncoding {
        // UTF-8 BOM
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return .utf8
        }
        
        // UTF-16 BOM
        if data.starts(with: [0xFF, 0xFE]) || 
           data.starts(with: [0xFE, 0xFF]) {
            return .utf16
        }
        
        // UTF-32 BOM
        if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) ||
           data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            return .utf32
        }
        
        // Try UTF-8
        if let _ = String(data: data, encoding: .utf8) {
            return .utf8
        }
        
        // Try others
        for encoding: String.Encoding in [.utf16, .iso8859_1, .ascii] {
            if let _ = String(data: data, encoding: encoding) {
                return TextEncoding(rawValue: encoding.description) ?? .utf8
            }
        }
        
        return .utf8
    }
}
EOF
```

---

## 단계 4: GitHub Actions 설정

### 4.1 빌드 워크플로우

```bash
mkdir -p .github/workflows

cat > .github/workflows/build.yml << 'EOF'
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
      - uses: actions/checkout@v4
      
      - name: Build
        run: |
          xcodebuild build \
            -scheme NotepadNext \
            -configuration Release \
            -destination 'platform=macOS,arch=arm64'
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build
          path: build/Build/Products
EOF

chmod +x .github/workflows/build.yml
```

### 4.2 테스트 워크플로우

```bash
cat > .github/workflows/test.yml << 'EOF'
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme NotepadNext \
            -destination 'platform=macOS,arch=arm64' \
            -enableCodeCoverage YES
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          fail_ci_if_error: false
EOF

chmod +x .github/workflows/test.yml
```

### 4.3 린트 워크플로우

```bash
cat > .github/workflows/lint.yml << 'EOF'
name: Code Quality

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  format:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install swift-format
        run: brew install swift-format
      
      - name: Check formatting
        run: |
          swift-format lint --recursive \
            --configuration .swift-format \
            Sources Tests
  
  lint:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install SwiftLint
        run: brew install swiftlint
      
      - name: Run SwiftLint
        run: swiftlint lint --strict --config .swiftlint.yml
EOF

chmod +x .github/workflows/lint.yml
```

---

## 단계 5: 기본 PR 및 이슈 템플릿

```bash
mkdir -p .github/ISSUE_TEMPLATE

cat > .github/pull_request_template.md << 'EOF'
## 설명

이 PR이 무엇을 하는지 간단히 설명해주세요.

## 변경 사항

- 변경 사항 1
- 변경 사항 2

## 테스트 방법

어떻게 테스트했는지 설명해주세요.

## 체크리스트

- [ ] swift-format 실행됨
- [ ] SwiftLint 통과
- [ ] 테스트 추가/수정됨
- [ ] 문서 업데이트됨

## 관련 이슈

Closes #000
EOF

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: 버그 리포트
about: 버그를 보고해주세요
title: "[BUG] "
labels: bug
---

## 설명

버그를 간단히 설명해주세요.

## 재현 방법

1. ...
2. ...

## 예상 동작

어떻게 동작해야 하는지 설명해주세요.

## 실제 동작

실제로 어떻게 동작하는지 설명해주세요.

## 환경

- macOS 버전:
- NotepadNext 버전:
EOF

cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: 기능 제안
about: 새로운 기능을 제안해주세요
title: "[FEATURE] "
labels: enhancement
---

## 설명

추가되었으면 하는 기능을 설명해주세요.

## 왜 필요한가요?

이 기능이 필요한 이유를 설명해주세요.

## 제안된 구현

어떻게 구현되면 좋을지 설명해주세요.
EOF
```

---

## 단계 6: 최초 커밋

```bash
# 모든 파일 추가
git add .

# 모든 워크플로우 실행 가능하게 설정
chmod +x Scripts/*.sh 2>/dev/null || true

# 커밋
git commit -m "build: initial project setup with SPM and GitHub Actions

- Configure Xcode project structure
- Add SPM dependencies (tree-sitter, swift-log)
- Implement TextBuffer with piece table
- Add SearchEngine and Encoding detection
- Setup GitHub Actions workflows
- Configure code style (swift-format, SwiftLint)
- Add PR and issue templates"

# 초기 브랜치
git branch -M main
```

---

## 단계 7: 로컬 개발 워크플로우

```bash
# 개발 브랜치 생성
git checkout -b develop
git push -u origin develop

# 기능 개발
git checkout -b feature/my-feature
# ... 작업 ...
swift-format format -r Sources Tests
swiftlint lint
xcodebuild test -scheme NotepadNext

# 커밋 및 PR
git add .
git commit -m "feat(editor): add feature description"
git push -u origin feature/my-feature
# GitHub에서 PR 생성
```

---

## 검증 체크리스트

```
✓ Package.swift 설정 완료
✓ Xcode 프로젝트 생성
✓ 코어 모듈 (TextBuffer, SearchEngine) 구현
✓ SwiftFormat, SwiftLint 구성
✓ GitHub Actions 워크플로우 생성
✓ PR 및 이슈 템플릿 추가
✓ git 초기화 및 커밋
✓ develop 브랜치 생성
```

다음 단계:
1. 더 많은 기능 모듈 추가 (Syntax Highlighter 등)
2. UI 구현 (AppDelegate, EditorViewController)
3. 통합 테스트 추가
4. 릴리스 자동화 스크립트 작성
