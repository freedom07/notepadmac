import AppKit
import CommonKit

public enum ThemeType: String, Codable, Sendable { case light, dark }

public struct TokenStyle: Codable, Sendable {
    public let foreground: String
    public let fontStyle: String?
    public init(foreground: String, fontStyle: String? = nil) {
        self.foreground = foreground; self.fontStyle = fontStyle
    }
}

public struct Theme: Codable, Sendable {
    public let name: String
    public let type: ThemeType
    public let colors: [String: String]
    public let tokenColors: [String: TokenStyle]

    public init(name: String, type: ThemeType, colors: [String: String], tokenColors: [String: TokenStyle]) {
        self.name = name; self.type = type; self.colors = colors; self.tokenColors = tokenColors
    }

    public static func colorFromHex(_ hex: String) -> NSColor {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .labelColor }
        return NSColor(
            red: CGFloat((val >> 16) & 0xFF) / 255.0,
            green: CGFloat((val >> 8) & 0xFF) / 255.0,
            blue: CGFloat(val & 0xFF) / 255.0, alpha: 1.0)
    }

    public func color(forKey key: String) -> NSColor {
        guard let hex = colors[key] else { return .labelColor }
        return Theme.colorFromHex(hex)
    }

    public func tokenColor(forKey key: String) -> NSColor {
        guard let style = tokenColors[key] else { return .labelColor }
        return Theme.colorFromHex(style.foreground)
    }

    public func tokenAttributes(forKey key: String) -> [NSAttributedString.Key: Any] {
        guard let style = tokenColors[key] else { return [:] }
        var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: Theme.colorFromHex(style.foreground)]
        if let fs = style.fontStyle {
            let base = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            if fs.contains("bold") && fs.contains("italic") {
                let desc = base.fontDescriptor.withSymbolicTraits([.bold, .italic])
                attrs[.font] = NSFont(descriptor: desc, size: 13) ?? base
            } else if fs.contains("bold") {
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
            } else if fs.contains("italic") {
                let desc = base.fontDescriptor.withSymbolicTraits(.italic)
                attrs[.font] = NSFont(descriptor: desc, size: 13) ?? base
            }
        }
        return attrs
    }
}
