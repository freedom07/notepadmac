import AppKit

// MARK: - WhitespaceLayoutManager

/// An `NSLayoutManager` subclass that draws visible indicators for whitespace
/// characters (spaces, tabs, line endings) on top of the normal text rendering.
///
/// Set ``whitespaceMode`` to control which characters are visualised:
///
/// ```swift
/// let layoutManager = WhitespaceLayoutManager()
/// layoutManager.whitespaceMode = .allCharacters
/// ```
///
/// The symbols used are:
/// - **Space** → `·` (middle dot)
/// - **Tab** → `→` (rightwards arrow)
/// - **Line ending** → `↵` (downwards arrow with corner leftwards)
@available(macOS 13.0, *)
public final class WhitespaceLayoutManager: NSLayoutManager {

    // MARK: - WhitespaceMode

    /// Controls which invisible characters are rendered.
    public enum WhitespaceMode: Int, CaseIterable {
        /// Don't show anything (default).
        case hidden = 0
        /// Show `·` for spaces and `→` for tabs.
        case spacesAndTabs
        /// Show `↵` for line endings.
        case eolOnly
        /// Show all: spaces, tabs, and line endings.
        case allCharacters

        /// A human-readable label for display in menus.
        public var displayName: String {
            switch self {
            case .hidden:        return "Hide"
            case .spacesAndTabs: return "Spaces & Tabs"
            case .eolOnly:       return "Line Endings"
            case .allCharacters: return "All Characters"
            }
        }
    }

    // MARK: - Public Properties

    /// The current whitespace visualisation mode.
    public var whitespaceMode: WhitespaceMode = .hidden {
        didSet {
            if oldValue != whitespaceMode {
                invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textStorage?.length ?? 0))
            }
        }
    }

    /// The color used to draw whitespace symbols. Defaults to a subtle,
    /// semi-transparent tertiary label color.
    public var whitespaceColor: NSColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.5)

    // MARK: - Drawing

    override public func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)

        guard whitespaceMode != .hidden, let textStorage = textStorage else { return }

        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let text = textStorage.string as NSString

        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: whitespaceColor,
        ]

        text.enumerateSubstrings(
            in: charRange,
            options: .byComposedCharacterSequences
        ) { [weak self] substring, substringRange, _, _ in
            guard let self = self, let char = substring else { return }

            let symbol: String? = self.symbol(for: char)
            guard let symbol = symbol else { return }

            let glyphRange = self.glyphRange(forCharacterRange: substringRange, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { return }

            let container = self.textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil)
            guard container != nil else { return }

            let location = self.location(forGlyphAt: glyphRange.location)
            let lineFragment = self.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
            let drawPoint = NSPoint(
                x: origin.x + lineFragment.origin.x + location.x,
                y: origin.y + lineFragment.origin.y
            )
            symbol.draw(at: drawPoint, withAttributes: attrs)
        }
    }

    // MARK: - Private Helpers

    /// Returns the symbol string to draw for a given character, or `nil` if the
    /// character should not be visualised in the current mode.
    private func symbol(for character: String) -> String? {
        switch character {
        case " ":
            return (whitespaceMode == .spacesAndTabs || whitespaceMode == .allCharacters) ? "\u{00B7}" : nil
        case "\t":
            return (whitespaceMode == .spacesAndTabs || whitespaceMode == .allCharacters) ? "\u{2192}" : nil
        case "\n", "\r\n", "\r":
            return (whitespaceMode == .eolOnly || whitespaceMode == .allCharacters) ? "\u{21B5}" : nil
        default:
            return nil
        }
    }
}
