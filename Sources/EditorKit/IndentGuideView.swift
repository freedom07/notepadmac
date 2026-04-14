import AppKit
import CommonKit

public class IndentGuideView: NSView {
    public var text: String = "" { didSet { needsDisplay = true } }
    public var tabWidth: Int = 4
    public var guideColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.3)
    public var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Calculate character width using NSAttributedString
        let spaceStr = NSAttributedString(string: " ", attributes: [.font: font])
        let charWidth = spaceStr.size().width
        let lineHeight = font.ascender - font.descender + font.leading
        let lines = text.components(separatedBy: "\n")

        ctx.setStrokeColor(guideColor.cgColor)
        ctx.setLineWidth(0.5)

        let firstVisible = max(0, Int(visibleRect.minY / lineHeight))
        let lastVisible = min(lines.count, Int(visibleRect.maxY / lineHeight) + 1)

        for i in firstVisible..<lastVisible {
            guard i < lines.count else { break }
            let spaces = lines[i].prefix(while: { $0 == " " }).count
            let tabs = lines[i].prefix(while: { $0 == "\t" }).count
            let level = (spaces / max(1, tabWidth)) + tabs

            // Only draw guides if there is actual indentation
            guard level > 0 else { continue }

            for l in 1...level {
                let x = CGFloat(l * tabWidth) * charWidth
                let y = CGFloat(i) * lineHeight
                ctx.move(to: CGPoint(x: x, y: bounds.height - y))
                ctx.addLine(to: CGPoint(x: x, y: bounds.height - y - lineHeight))
                ctx.strokePath()
            }
        }
    }
}
