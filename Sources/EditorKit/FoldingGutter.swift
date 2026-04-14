import AppKit
import SyntaxKit
import CommonKit

public protocol FoldingGutterDelegate: AnyObject { func foldingGutter(_ gutter: FoldingGutter, didToggleFoldAt line: Int) }

public class FoldingGutter: NSView {
    public var foldRegions: [FoldRegion] = [] { didSet { needsDisplay = true } }
    public var collapsedLines: Set<Int> = [] { didSet { needsDisplay = true } }
    public weak var delegate: FoldingGutterDelegate?
    private let lineHeight: CGFloat = 16.0
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect); guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setFillColor(NSColor.secondaryLabelColor.cgColor)
        for region in foldRegions {
            let y = bounds.height - CGFloat(region.startLine + 1) * lineHeight
            guard dirtyRect.intersects(CGRect(x: 0, y: y, width: bounds.width, height: lineHeight)) else { continue }
            let cx = bounds.width / 2; let cy = y + lineHeight / 2
            if collapsedLines.contains(region.startLine) { ctx.move(to: CGPoint(x: cx-3, y: cy-4)); ctx.addLine(to: CGPoint(x: cx-3, y: cy+4)); ctx.addLine(to: CGPoint(x: cx+4, y: cy)) }
            else { ctx.move(to: CGPoint(x: cx-4, y: cy+3)); ctx.addLine(to: CGPoint(x: cx+4, y: cy+3)); ctx.addLine(to: CGPoint(x: cx, y: cy-4)) }
            ctx.closePath(); ctx.fillPath()
        }
    }
    public override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil); let line = Int((bounds.height - p.y) / lineHeight)
        for r in foldRegions where r.startLine == line { if collapsedLines.contains(line) { collapsedLines.remove(line) } else { collapsedLines.insert(line) }; delegate?.foldingGutter(self, didToggleFoldAt: line); break }
    }

    // MARK: - Fold Level Controls

    /// Collapse all fold regions.
    public func foldAll() {
        for region in foldRegions {
            collapsedLines.insert(region.startLine)
        }
    }

    /// Expand all fold regions.
    public func unfoldAll() {
        collapsedLines.removeAll()
    }

    /// Collapse all regions whose nesting depth is greater than or equal to `level`.
    ///
    /// Depth is 1-based: top-level regions are depth 1, regions nested inside
    /// those are depth 2, etc.
    public func foldLevel(_ level: Int) {
        guard level >= 1 else { return }
        // Reset all folds first.
        collapsedLines.removeAll()
        // computeDepths returns depths in sorted order, so use sorted regions.
        let sorted = foldRegions.sorted {
            $0.startLine < $1.startLine || ($0.startLine == $1.startLine && $0.endLine > $1.endLine)
        }
        let depths = computeDepths()
        for (index, depth) in depths.enumerated() where depth >= level {
            collapsedLines.insert(sorted[index].startLine)
        }
    }

    /// Toggle the fold state of the region at the given 0-based line number.
    public func foldCurrentBlock(at line: Int) {
        guard let region = foldRegions.first(where: { $0.startLine == line }) else { return }
        if collapsedLines.contains(region.startLine) {
            collapsedLines.remove(region.startLine)
        } else {
            collapsedLines.insert(region.startLine)
        }
        delegate?.foldingGutter(self, didToggleFoldAt: line)
    }

    /// Compute the nesting depth (1-based) for each fold region.
    ///
    /// Uses a stack-based approach: regions are sorted by start line
    /// (ties broken by wider region first). A stack tracks open parent
    /// regions; depth equals stack size + 1.
    internal func computeDepths() -> [Int] {
        let sorted = foldRegions.sorted {
            $0.startLine < $1.startLine || ($0.startLine == $1.startLine && $0.endLine > $1.endLine)
        }
        var depths = [Int]()
        depths.reserveCapacity(sorted.count)
        // Stack of endLine values for currently open parent regions
        var stack: [Int] = []
        for region in sorted {
            // Pop regions whose endLine is before this region's start
            while let top = stack.last, top < region.startLine {
                stack.removeLast()
            }
            depths.append(stack.count + 1)
            stack.append(region.endLine)
        }
        return depths
    }
}
