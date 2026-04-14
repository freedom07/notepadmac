# Architecture

## Module Dependency Graph

```
NotepadNext (app)
├── NotepadNextCore ── CommonKit
├── EditorKit ── TextCore ── CommonKit
│   ├── SyntaxKit ── TextCore, CommonKit
│   └── ThemeKit ── CommonKit
├── FileKit ── TextCore ── CommonKit
├── TabKit ── CommonKit
├── SearchKit ── TextCore ── CommonKit
├── MarkdownKit ── CommonKit
├── PanelKit ── CommonKit
└── CommonKit (no dependencies)
```

## Modules

| Module | Purpose |
|--------|---------|
| **NotepadNextCore** | Macro system, plugin architecture, version info |
| **CommonKit** | Shared types: LineEnding, TextPosition, Debouncer, Disposable |
| **TextCore** | Piece Table data structure, LineIndex, TextBuffer with undo/redo |
| **PanelKit** | Dockable panel system for side panels and tool windows |
| **SyntaxKit** | Regex-based syntax highlighting for 22 languages, code folding |
| **ThemeKit** | JSON-based theme system with 16 built-in themes |
| **EditorKit** | NSTextView subclass, line numbers, minimap, split view, multi-cursor |
| **FileKit** | File I/O, encoding detection, file watching, session/auto-save |
| **TabKit** | Custom tab bar with Core Graphics, tab management |
| **SearchKit** | Find/replace engine, Find in Files, regex support |
| **MarkdownKit** | Markdown to HTML renderer, WKWebView preview |
| **NotepadNext** | App shell, menus, command palette, macro system, plugin system |

## Data Flow

1. User types → EditorTextView.keyDown
2. Text change → NSTextStorage updated
3. SyntaxHighlighter applies token colors
4. LineNumberGutter redraws line numbers
5. StatusBarView updates cursor position
6. TextBuffer records edit for undo/redo
