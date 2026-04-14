import AppKit

/// A layer-backed view that displays line numbers beside an NSTextView.
///
/// Uses `wantsUpdateLayer` and child NSTextField labels instead of
/// overriding `draw(_:)`, which breaks sibling NSScrollView text
/// rendering on macOS 15.
@available(macOS 13.0, *)
public final class LineNumberSideView: NSView {

    private weak var textView: NSTextView?
    private weak var scrollView: NSScrollView?

    public var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) {
        didSet { refreshLineNumbers() }
    }
    public var textColor: NSColor = .secondaryLabelColor
    public var currentLineColor: NSColor = .labelColor
    public var currentLine: Int = 1 {
        didSet { if oldValue != currentLine { refreshLineNumbers() } }
    }

    /// Reusable label pool to avoid allocation churn.
    private var labelPool: [NSTextField] = []

    /// Thin separator line on the right edge of the gutter.
    private let separatorLine = NSView()

    public init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true

        // Separator line (1px on the right edge)
        separatorLine.wantsLayer = true
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)
        NSLayoutConstraint.activate([
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.topAnchor.constraint(equalTo: topAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.widthAnchor.constraint(equalToConstant: 1),
        ])

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func handleChange(_ n: Notification) {
        invalidateIntrinsicContentSize()
        refreshLineNumbers()
    }

    // MARK: - Layer-backed (no draw() override)

    public override var isFlipped: Bool { true }
    public override var wantsUpdateLayer: Bool { true }

    public override func updateLayer() {
        // Slightly different shade from editor background for visual separation
        let bg = NSColor.textBackgroundColor.blended(withFraction: 0.08, of: .gray)
            ?? NSColor.controlBackgroundColor
        layer?.backgroundColor = bg.cgColor
        separatorLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    public override func layout() {
        super.layout()
        refreshLineNumbers()
    }

    // MARK: - Line Numbers

    private func refreshLineNumbers() {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = scrollView
        else { return }

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        // Hide all existing labels first
        for label in labelPool {
            label.isHidden = true
        }

        // Empty document: still show line 1
        if glyphRange.length == 0 {
            let label = labelAt(index: 0)
            label.stringValue = "1"
            label.font = font
            label.textColor = currentLine == 1 ? currentLineColor : textColor
            let lineHeight = font.pointSize * 1.5
            let insetY = textView.textContainerInset.height
            label.frame = NSRect(x: 0, y: insetY, width: bounds.width - 8, height: lineHeight)
            label.isHidden = false
            return
        }

        let string = textView.string as NSString
        let startCharIndex = layoutManager.characterRange(
            forGlyphRange: NSRange(location: 0, length: glyphRange.location),
            actualGlyphRange: nil
        ).location
        var lineNumber = countNewlines(in: string, upTo: startCharIndex) + 1
        let padding: CGFloat = 8

        var labelIndex = 0
        var glyphIndex = glyphRange.location
        while glyphIndex < NSMaxRange(glyphRange) {
            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            lineRect.origin.y += textView.textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y

            let label = labelAt(index: labelIndex)
            label.stringValue = "\(lineNumber)"
            label.font = font
            label.textColor = lineNumber == currentLine ? currentLineColor : textColor
            label.frame = NSRect(x: 0, y: lineRect.origin.y, width: bounds.width - padding, height: lineRect.height)
            label.isHidden = false

            var nextRange = NSRange(location: NSNotFound, length: 0)
            layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &nextRange)
            glyphIndex = NSMaxRange(nextRange)
            lineNumber += 1
            labelIndex += 1
        }

        // Handle the extra line fragment after a trailing newline (e.g., "\n" at end)
        layoutManager.ensureLayout(for: textContainer)
        let extraRect = layoutManager.extraLineFragmentRect
        if extraRect.height > 0 {
            var adjustedRect = extraRect
            adjustedRect.origin.y += textView.textContainerInset.height
            adjustedRect.origin.y -= visibleRect.origin.y

            if adjustedRect.origin.y < bounds.height {
                let label = labelAt(index: labelIndex)
                label.stringValue = "\(lineNumber)"
                label.font = font
                label.textColor = lineNumber == currentLine ? currentLineColor : textColor
                label.frame = NSRect(x: 0, y: adjustedRect.origin.y, width: bounds.width - padding, height: adjustedRect.height)
                label.isHidden = false
            }
        }
    }

    private func labelAt(index: Int) -> NSTextField {
        if index < labelPool.count { return labelPool[index] }
        let label = NSTextField(labelWithString: "")
        label.alignment = .right
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        addSubview(label)
        labelPool.append(label)
        return label
    }

    // MARK: - Sizing

    public override var intrinsicContentSize: NSSize {
        guard let textView = textView else { return NSSize(width: 33, height: NSView.noIntrinsicMetric) }
        let string = textView.string as NSString
        let lineCount = max(countNewlines(in: string, upTo: string.length) + 1, 1)
        let digitCount = max(String(lineCount).count, 2)
        let sample = String(repeating: "8", count: digitCount) as NSString
        let size = sample.size(withAttributes: [.font: font])
        return NSSize(width: ceil(size.width + 16), height: NSView.noIntrinsicMetric)
    }

    // MARK: - Helpers

    private func countNewlines(in string: NSString, upTo location: Int) -> Int {
        guard location > 0, location <= string.length else { return 0 }
        let sub = string.substring(to: location)
        let normalized = sub.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n").count - 1
    }
}
