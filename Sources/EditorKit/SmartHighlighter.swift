import AppKit
import CommonKit

// MARK: - SmartHighlighter

/// Automatically highlights all occurrences of the word under the cursor.
///
/// Attach to an ``EditorViewController`` to get Notepad++-style "smart
/// highlighting": when the caret sits inside (or at the boundary of) a word,
/// every other occurrence of that exact word is softly highlighted. Moves and
/// edits are debounced so the feature stays responsive even in large files.
///
/// ```swift
/// let highlighter = SmartHighlighter()
/// highlighter.cursorDidMove(in: textView)
/// ```
@available(macOS 13.0, *)
public final class SmartHighlighter {

    // MARK: - Public Properties

    /// Master toggle. When `false`, `cursorDidMove(in:)` is a no-op and
    /// any existing highlights are cleared.
    public var isEnabled: Bool = true

    /// The background color applied to matching occurrences.
    public var highlightColor: NSColor = NSColor.systemYellow.withAlphaComponent(0.18)

    /// Words shorter than this are ignored (avoids noisy single-char highlights).
    public var minWordLength: Int = 2

    // MARK: - Private State

    private let debouncer = Debouncer(delay: 0.15)
    private var currentHighlightedWord: String?
    private var highlightRanges: [NSRange] = []

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Call this when the cursor position changes. Internally debounced so
    /// rapid arrow-key presses only trigger one highlight pass.
    public func cursorDidMove(in textView: NSTextView) {
        guard isEnabled else {
            clearHighlights(in: textView)
            return
        }
        debouncer.debounce { [weak self] in
            self?.updateHighlights(in: textView)
        }
    }

    /// Removes all smart-highlight background attributes previously applied.
    public func clearHighlights(in textView: NSTextView) {
        guard let textStorage = textView.textStorage,
              let layoutManager = textView.layoutManager else { return }
        for range in highlightRanges {
            let clamped = NSIntersectionRange(range, NSRange(location: 0, length: textStorage.length))
            if clamped.length > 0 {
                layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: clamped)
            }
        }
        highlightRanges = []
        currentHighlightedWord = nil
    }

    // MARK: - Internal (visible for testing)

    /// Extracts the word range at the given UTF-16 position.
    /// Returns `nil` when the position is not inside a word.
    internal func wordRange(at position: Int, in text: String) -> NSRange? {
        let nsText = text as NSString
        guard position >= 0, position <= nsText.length else { return nil }
        guard let regex = try? NSRegularExpression(pattern: "\\w+", options: []) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        return matches.first(where: {
            NSLocationInRange(position, $0.range) ||
            position == $0.range.location + $0.range.length
        })?.range
    }

    // MARK: - Private

    private func updateHighlights(in textView: NSTextView) {
        guard isEnabled, let textStorage = textView.textStorage else { return }

        // 1. Clear previous highlights.
        clearHighlights(in: textView)

        // 2. Only highlight when the caret is a zero-length insertion point.
        let selectedRange = textView.selectedRange()
        guard selectedRange.length == 0 else { return }

        // 3. Determine the word under the cursor.
        let text = textStorage.string
        guard let wordRange = wordRange(at: selectedRange.location, in: text) else { return }
        let word = (text as NSString).substring(with: wordRange)
        guard word.count >= minWordLength else { return }

        // 4. Find all whole-word occurrences.
        let escaped = NSRegularExpression.escapedPattern(for: word)
        guard let regex = try? NSRegularExpression(pattern: "\\b\(escaped)\\b", options: []) else { return }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))

        // 5. Apply highlights (skip the occurrence at cursor).
        //    Use temporary attributes on the layout manager so we don't modify
        //    the text storage (which would trigger didChangeNotification and
        //    conflict with syntax-highlighting backgroundColor).
        guard let layoutManager = textView.layoutManager else { return }
        for match in matches {
            if match.range.location == wordRange.location { continue }
            layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: match.range)
            highlightRanges.append(match.range)
        }
        currentHighlightedWord = word
    }
}
