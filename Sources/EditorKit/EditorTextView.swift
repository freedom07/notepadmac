import AppKit
import TextCore
import CommonKit

// MARK: - EditorTextView

/// A text view tailored for code editing, with line-number support and
/// current-line highlighting.
///
/// Use this inside an `NSScrollView` together with ``LineNumberSideView`` for a
/// full editor experience. The view is pre-configured with a monospace font,
/// increased line height, and sensible defaults for code editing (no smart
/// quotes, no automatic dash substitution).
@available(macOS 13.0, *)
public class EditorTextView: NSTextView {

    // MARK: - Public Properties

    /// Background color used to highlight the line where the cursor sits.
    public var currentLineHighlightColor: NSColor = NSColor.selectedTextBackgroundColor.withAlphaComponent(0.12) {
        didSet { needsDisplay = true }
    }

    /// Whether line numbers are visible. Toggling this shows or hides the
    /// ``LineNumberSideView`` beside the scroll view.
    public var showsLineNumbers: Bool = true {
        didSet {
            guard let container = enclosingScrollView?.superview else { return }
            for sibling in container.subviews where sibling is LineNumberSideView {
                sibling.isHidden = !showsLineNumbers
            }
        }
    }

    /// The column at which to draw a vertical edge indicator line.
    /// Set to `nil` to disable the indicator. Common values: 80, 100, 120.
    public var edgeColumn: Int? = nil {
        didSet { needsDisplay = true }
    }

    /// The color used to draw the edge column indicator line.
    public var edgeColumnColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.3) {
        didSet { needsDisplay = true }
    }

    /// The completion provider used for auto-completion suggestions.
    /// Set this from the ``EditorViewController`` to enable keyword and
    /// document-word completion.
    public var completionProvider: CompletionProvider?

    // MARK: - Initialisation

    public override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Monospace font: prefer SF Mono, fall back to Menlo.
        let preferredFont = NSFont(name: "SF Mono", size: 13)
            ?? NSFont(name: "Menlo", size: 13)
            ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        self.font = preferredFont

        // Line height multiplier of 1.5.
        configureDefaultParagraphStyle()

        // Disable smart substitutions for code editing.
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false

        // Allow horizontal scrolling for long lines.
        isHorizontallyResizable = true
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = false
        textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Slight inset from the edges.
        textContainerInset = NSSize(width: 4, height: 4)

        // Enable automatic link detection for clickable URLs.
        isAutomaticLinkDetectionEnabled = true
    }

    // MARK: - Paragraph Style (Line Height)

    private func configureDefaultParagraphStyle() {
        let paragraphStyle = NSMutableParagraphStyle()
        let lineHeight = (font?.pointSize ?? 13) * 1.5
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        defaultParagraphStyle = paragraphStyle
        typingAttributes[.paragraphStyle] = paragraphStyle
    }

    // MARK: - Text Change Notifications

    public override func didChangeText() {
        super.didChangeText()

        // Re-scan the visible portion for clickable URLs after text changes.
        if isAutomaticLinkDetectionEnabled, let visibleRange = visibleCharacterRange() {
            checkTextInDocument(nil)
            _ = visibleRange // link detection scoped by NSTextView internally
        }
    }

    /// Returns the character range currently visible in the scroll view.
    private func visibleCharacterRange() -> NSRange? {
        guard let layoutManager = layoutManager, let textContainer = textContainer else { return nil }
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        return layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    // MARK: - Selection / Cursor

    public override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting flag: Bool
    ) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: flag)
        needsDisplay = true
    }

    // MARK: - Current Line Highlight

    public override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawCurrentLineHighlight()
        drawEdgeColumnIndicator(in: rect)
    }

    private func drawCurrentLineHighlight() {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer
        else { return }

        let selectedRange = selectedRange()
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: selectedRange.location, length: 0),
            actualCharacterRange: nil
        )
        var lineRect = layoutManager.lineFragmentRect(forGlyphAt: max(glyphRange.location, 0), effectiveRange: nil)
        lineRect.origin.x = 0
        lineRect.size.width = bounds.width
        lineRect.origin.y += textContainerInset.height

        currentLineHighlightColor.setFill()
        let path = NSBezierPath(rect: lineRect)
        path.fill()
    }

    // MARK: - Edge Column Indicator

    private func drawEdgeColumnIndicator(in dirtyRect: NSRect) {
        guard let col = edgeColumn, let font = self.font else { return }
        let charWidth = NSAttributedString(string: " ", attributes: [.font: font]).size().width
        let x = textContainerInset.width + CGFloat(col) * charWidth
        edgeColumnColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: dirtyRect.minY))
        path.line(to: NSPoint(x: x, y: dirtyRect.maxY))
        path.lineWidth = 0.5
        path.stroke()
    }

    // MARK: - Auto-Completion

    /// Provides completions for the partial word range using the attached
    /// ``CompletionProvider``. Falls back to the default NSTextView behavior
    /// when no provider is set.
    public override func completions(
        forPartialWordRange charRange: NSRange,
        indexOfSelectedItem index: UnsafeMutablePointer<Int>
    ) -> [String]? {
        guard let provider = completionProvider, provider.isEnabled else {
            return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
        }

        let nsString = self.string as NSString
        guard charRange.location != NSNotFound,
              charRange.location + charRange.length <= nsString.length else {
            return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
        }

        let partial = nsString.substring(with: charRange)
        let results = provider.completions(forPartialWord: partial, in: self.string)

        if results.isEmpty {
            return super.completions(forPartialWordRange: charRange, indexOfSelectedItem: index)
        }

        index.pointee = 0
        return results
    }

    // MARK: - Public Helpers

    /// Scrolls the text view so the given 1-based line number is visible.
    public func scrollToLine(_ lineNumber: Int) {
        guard lineNumber >= 1,
              let layoutManager = layoutManager,
              let textContainer = textContainer
        else { return }

        let string = self.string as NSString
        var currentLine = 1
        var characterIndex = 0

        while currentLine < lineNumber, characterIndex < string.length {
            let lineRange = string.lineRange(for: NSRange(location: characterIndex, length: 0))
            currentLine += 1
            characterIndex = NSMaxRange(lineRange)
        }

        guard characterIndex <= string.length, string.length > 0 else { return }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: min(characterIndex, string.length - 1))
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        var scrollPoint = lineRect.origin
        scrollPoint.y += textContainerInset.height
        scrollPoint.y -= (enclosingScrollView?.contentView.bounds.height ?? 0) / 3
        scrollPoint.y = max(scrollPoint.y, 0)
        scrollToVisible(NSRect(origin: scrollPoint, size: enclosingScrollView?.contentView.bounds.size ?? bounds.size))
    }

    /// Returns the 1-based line number at the current insertion point.
    public func currentLineNumber() -> Int {
        let location = selectedRange().location
        let string = self.string as NSString
        guard location <= string.length else { return 1 }
        let substring = string.substring(to: location)
        // Normalize CRLF and CR to LF to handle all line ending types
        let normalized = substring.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n").count
    }

    /// Returns the 1-based column number at the current insertion point.
    public func currentColumnNumber() -> Int {
        let location = selectedRange().location
        let string = self.string as NSString
        guard location <= string.length else { return 1 }
        let lineRange = string.lineRange(for: NSRange(location: location, length: 0))
        return location - lineRange.location + 1
    }

}
