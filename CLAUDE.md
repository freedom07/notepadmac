# NotepadMac — Development Guide

## Project Overview

NotepadMac is a native macOS text editor (Swift + AppKit) inspired by Notepad++.
12 internal modules, zero external dependencies, Swift Package Manager build.

## Quick Commands

```bash
swift build                      # Debug build
swift test                       # Run all tests
bash Scripts/build-app.sh        # Build .app bundle (debug)
bash Scripts/build-app.sh release # Build .app bundle (release)
bash Scripts/create-dmg.sh       # Build release DMG
bash Scripts/version.sh get      # Show current version
bash Scripts/version.sh bump patch # Bump patch version (0.1.0 → 0.1.1)
```

## Architecture

```
Sources/
├── NotepadNext/          # App shell (AppDelegate, MainWindowController, menus)
├── NotepadNextCore/      # Core logic (macros, plugins, preferences, CLI args)
├── TextCore/             # Piece Table engine, LineIndex, TextBuffer
├── EditorKit/            # EditorTextView, line numbers, minimap, split view
├── SyntaxKit/            # Syntax highlighting (19 langs), code folding
├── ThemeKit/             # Theme system (16 built-in themes)
├── SearchKit/            # Find/Replace, Find in Files, regex
├── FileKit/              # File I/O, encoding detection, file watching
├── TabKit/               # Tab bar UI, tab management
├── MarkdownKit/          # Markdown → HTML renderer, WKWebView preview
├── PanelKit/             # Dockable panel framework (left/right/bottom)
└── CommonKit/            # Shared utilities, extensions, constants
```

**Dependency rule:** CommonKit ← TextCore ← everything else. No circular deps.

## Version Management

Version is stored in `Sources/NotepadNextCore/Version.swift`:
```swift
public let appVersion = "0.1.0"
public let appBuild = "1"
```

Use the version script — do NOT edit manually:
```bash
bash Scripts/version.sh bump patch  # 0.1.0 → 0.1.1
bash Scripts/version.sh bump minor  # 0.1.1 → 0.2.0
bash Scripts/version.sh bump major  # 0.2.0 → 1.0.0
```

## Release Process

### 1. Prepare the release

```bash
# Bump version
bash Scripts/version.sh bump patch
VERSION=$(bash Scripts/version.sh get)

# Update create-dmg.sh VERSION variable if needed
# (currently hardcoded — keep in sync with Version.swift)

# Commit
git add Sources/NotepadNextCore/Version.swift
git commit -m "Bump version to $VERSION"
```

### 2. Tag and push

```bash
git tag "v$VERSION"
git push origin main --tags
```

### 3. Automatic release (GitHub Actions)

Once the tag is pushed, `.github/workflows/release.yml` automatically:
1. Runs `swift test` — fails the release if tests break
2. Runs `bash Scripts/create-dmg.sh` — builds the release DMG
3. Creates a GitHub Release with auto-generated release notes
4. Attaches `NotepadMac-{VERSION}.dmg` to the release

Users download the DMG from the GitHub Releases page.

### 4. Code signing (optional, requires Apple Developer ID)

If you have a Developer ID ($99/year), sign before distributing:
```bash
codesign --deep --force --options runtime \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  .build/release/NotepadMac.app

xcrun notarytool submit NotepadMac-*.dmg \
  --apple-id "your@email.com" --team-id TEAMID --wait

xcrun stapler staple NotepadMac-*.dmg
```

## CI/CD Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `build.yml` | Push/PR to main | `swift build` — compile check |
| `test.yml` | Push/PR to main | `swift test --parallel` — run all tests |
| `lint.yml` | Push/PR to main | SwiftLint code quality check |
| `release.yml` | Tag `v*` pushed | Test → Build DMG → Create GitHub Release |

## Code Style

- **SwiftFormat** config: `.swiftformat` (4-space indent, 120 char width)
- **SwiftLint** config: `.swiftlint.yml`
- No external dependencies — keep it that way
- Each module should be independently testable

## Common Tasks

### Adding a new syntax language
Edit `Sources/SyntaxKit/BuiltinLanguages.swift` — add a new `LanguageDefinition`.

### Adding a new theme
Edit `Sources/ThemeKit/BuiltinThemes.swift` — add a new theme JSON string.

### Adding a new panel
1. Create a `NSViewController` subclass
2. Register it in `MainWindowController.registerPanels()` with a `PanelDescriptor`

## Important Notes

- Bundle identifier: `com.notepadmac.app`
- Minimum macOS: 13.0 (Ventura)
- Swift target name is still `NotepadNext` (internal) — display name is `NotepadMac`
- UserDefaults prefix: `NotepadMac.`
- App Support directory: `~/Library/Application Support/NotepadMac/`
- `Scripts/build-app.sh` and `Scripts/create-dmg.sh` auto-read version from `Version.swift`
