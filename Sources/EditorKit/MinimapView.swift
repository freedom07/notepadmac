import AppKit
import CommonKit

// MARK: - MinimapViewDelegate

public protocol MinimapViewDelegate: AnyObject {
    func minimapView(_ minimap: MinimapView, didRequestScrollToLine line: Int)
}

// MARK: - MinimapView

public class MinimapView: NSView {

    public weak var delegate: MinimapViewDelegate?

    public var text: String = "" {
        didSet { needsDisplay = true }
    }

    public var viewportStartLine: Int = 0 {
        didSet { needsDisplay = true }
    }

    public var viewportLineCount: Int = 50 {
        didSet { needsDisplay = true }
    }

    public var totalLineCount: Int {
        text.components(separatedBy: "\n").count
    }

    override public var intrinsicContentSize: NSSize {
        NSSize(width: 80, height: NSView.noIntrinsicMetric)
    }

    // MARK: - Drawing

    override public func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Fill background with a slightly darker color
        let backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 1.0)
        backgroundColor.setFill()
        bounds.fill()

        let lines = text.components(separatedBy: "\n")
        let lineCount = max(1, totalLineCount)
        let lineHeight = bounds.height / CGFloat(lineCount)

        // Draw each line as a small colored rectangle
        let lineColor = NSColor(calibratedWhite: 0.55, alpha: 0.6)
        lineColor.setFill()

        for (index, line) in lines.enumerated() {
            let lineLength = CGFloat(line.count)
            let maxWidth: CGFloat = 70.0
            let width = min(maxWidth, lineLength * 0.8)

            guard width > 0 else { continue }

            let y = bounds.height - CGFloat(index + 1) * lineHeight
            let rect = NSRect(x: 4, y: y, width: width, height: max(1, lineHeight - 0.5))
            rect.fill()
        }

        // Draw semi-transparent overlay showing viewport position
        let viewportColor = NSColor(calibratedWhite: 1.0, alpha: 0.15)
        viewportColor.setFill()

        let viewportY = bounds.height - CGFloat(viewportStartLine + viewportLineCount) * lineHeight
        let viewportHeight = CGFloat(viewportLineCount) * lineHeight
        let viewportRect = NSRect(x: 0, y: viewportY, width: bounds.width, height: viewportHeight)
        viewportRect.fill()
    }

    // MARK: - Mouse Handling

    override public func mouseDown(with event: NSEvent) {
        handleMouseEvent(event)
    }

    override public func mouseDragged(with event: NSEvent) {
        handleMouseEvent(event)
    }

    private func handleMouseEvent(_ event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let lineCount = max(1, totalLineCount)
        let lineHeight = bounds.height / CGFloat(lineCount)
        let clickedLine = Int((bounds.height - location.y) / lineHeight)
        let clampedLine = max(0, min(clickedLine, lineCount - 1))
        delegate?.minimapView(self, didRequestScrollToLine: clampedLine)
    }
}
