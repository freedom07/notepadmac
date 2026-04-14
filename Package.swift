// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "NotepadNext",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NotepadNext", targets: ["NotepadNext"]),
        .library(name: "TextCore", targets: ["TextCore"]),
        .library(name: "EditorKit", targets: ["EditorKit"]),
        .library(name: "FileKit", targets: ["FileKit"]),
        .library(name: "TabKit", targets: ["TabKit"]),
        .library(name: "SearchKit", targets: ["SearchKit"]),
        .library(name: "SyntaxKit", targets: ["SyntaxKit"]),
        .library(name: "ThemeKit", targets: ["ThemeKit"]),
        .library(name: "MarkdownKit", targets: ["MarkdownKit"]),
        .library(name: "CommonKit", targets: ["CommonKit"]),
        .library(name: "NotepadNextCore", targets: ["NotepadNextCore"]),
        .library(name: "PanelKit", targets: ["PanelKit"]),
    ],
    targets: [
        // App core library (testable logic extracted from the executable)
        .target(
            name: "NotepadNextCore",
            dependencies: ["CommonKit"],
            path: "Sources/NotepadNextCore"
        ),
        // App
        .executableTarget(
            name: "NotepadNext",
            dependencies: [
                "NotepadNextCore",
                "TextCore", "EditorKit", "FileKit", "TabKit",
                "SearchKit", "SyntaxKit", "ThemeKit", "MarkdownKit", "CommonKit",
                "PanelKit"
            ],
            path: "Sources/NotepadNext"
        ),
        // Core text engine
        .target(
            name: "TextCore",
            dependencies: ["CommonKit"],
            path: "Sources/TextCore"
        ),
        // Syntax highlighting engine
        .target(
            name: "SyntaxKit",
            dependencies: ["TextCore", "CommonKit"],
            path: "Sources/SyntaxKit"
        ),
        // Theme management
        .target(
            name: "ThemeKit",
            dependencies: ["CommonKit"],
            path: "Sources/ThemeKit"
        ),
        // Markdown preview
        .target(
            name: "MarkdownKit",
            dependencies: ["CommonKit"],
            path: "Sources/MarkdownKit"
        ),
        // Editor view components
        .target(
            name: "EditorKit",
            dependencies: ["TextCore", "SyntaxKit", "ThemeKit", "CommonKit"],
            path: "Sources/EditorKit"
        ),
        // File I/O, encoding, file watching
        .target(
            name: "FileKit",
            dependencies: ["TextCore", "CommonKit"],
            path: "Sources/FileKit"
        ),
        // Tab bar and tab management
        .target(
            name: "TabKit",
            dependencies: ["CommonKit"],
            path: "Sources/TabKit"
        ),
        // Search and replace engine
        .target(
            name: "SearchKit",
            dependencies: ["TextCore", "CommonKit"],
            path: "Sources/SearchKit"
        ),
        // Shared utilities and extensions
        .target(
            name: "CommonKit",
            path: "Sources/CommonKit"
        ),
        // Dockable panel framework
        .target(
            name: "PanelKit",
            dependencies: [],
            path: "Sources/PanelKit"
        ),
        // Tests
        .testTarget(
            name: "TextCoreTests",
            dependencies: ["TextCore", "CommonKit"]
        ),
        .testTarget(
            name: "SearchKitTests",
            dependencies: ["SearchKit", "TextCore", "CommonKit"]
        ),
        .testTarget(name: "FileKitTests", dependencies: ["FileKit", "CommonKit"]),
        .testTarget(name: "SyntaxKitTests", dependencies: ["SyntaxKit", "CommonKit"]),
        .testTarget(name: "ThemeKitTests", dependencies: ["ThemeKit", "CommonKit"]),
        .testTarget(name: "EditorKitTests", dependencies: ["EditorKit", "TextCore", "CommonKit"]),
        .testTarget(name: "MarkdownKitTests", dependencies: ["MarkdownKit", "CommonKit"]),
        .testTarget(name: "CommonKitTests", dependencies: ["CommonKit"]),
        .testTarget(name: "TabKitTests", dependencies: ["TabKit", "CommonKit"]),
        .testTarget(name: "PanelKitTests", dependencies: ["PanelKit"]),
        .testTarget(name: "NotepadNextTests", dependencies: ["NotepadNextCore", "CommonKit"]),
    ]
)
