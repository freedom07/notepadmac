import AppKit
import WebKit
import CommonKit

// MARK: - MarkdownRenderer

/// Converts Markdown text to styled HTML using regex-based parsing.
@available(macOS 13.0, *)
public final class MarkdownRenderer {

    public init() {}

    // MARK: - Public API

    /// Converts a Markdown string into an HTML fragment.
    public func renderToHTML(markdown: String) -> String {
        var html = escapeHTML(markdown)

        // Fenced code blocks (``` ... ```) — must come before inline code
        html = renderCodeBlocks(html)

        // Extract code blocks into placeholders to protect from further transforms
        var codeBlockStore: [String: String] = [:]
        html = extractCodeBlocks(html, store: &codeBlockStore)

        // Tables — must come before other line-level transforms
        html = renderTables(html)

        // Blockquotes
        html = renderBlockquotes(html)

        // Horizontal rules
        html = renderHorizontalRules(html)

        // Headers (# through ######)
        html = renderHeaders(html)

        // Unordered lists
        html = renderUnorderedLists(html)

        // Ordered lists
        html = renderOrderedLists(html)

        // Images (must come before links)
        html = renderImages(html)

        // Links
        html = renderLinks(html)

        // Bold (**text** or __text__)
        html = renderBold(html)

        // Italic (*text* or _text_)
        html = renderItalic(html)

        // Inline code (`code`)
        html = renderInlineCode(html)

        // Paragraphs — wrap remaining bare lines
        html = renderParagraphs(html)

        // Restore code blocks from placeholders
        html = restoreCodeBlocks(html, store: codeBlockStore)

        return html
    }

    /// Wraps an HTML body fragment in a full HTML document with CSS styling.
    public func wrapInHTMLTemplate(body: String, darkMode: Bool) -> String {
        let bgColor = darkMode ? "#1e1e1e" : "#ffffff"
        let textColor = darkMode ? "#d4d4d4" : "#24292e"
        let codeBg = darkMode ? "#2d2d2d" : "#f6f8fa"
        let codeBorder = darkMode ? "#444444" : "#e1e4e8"
        let blockquoteBorder = darkMode ? "#555555" : "#dfe2e5"
        let blockquoteFg = darkMode ? "#9e9e9e" : "#6a737d"
        let linkColor = darkMode ? "#58a6ff" : "#0366d6"
        let tableBorder = darkMode ? "#444444" : "#dfe2e5"
        let tableStripeBg = darkMode ? "#2a2a2a" : "#f6f8fa"
        let hrColor = darkMode ? "#444444" : "#e1e4e8"
        let keywordColor = darkMode ? "#569cd6" : "#d73a49"
        let stringColor = darkMode ? "#ce9178" : "#032f62"
        let commentColor = darkMode ? "#6a9955" : "#6a737d"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                font-size: 14px;
                line-height: 1.6;
                color: \(textColor);
                background-color: \(bgColor);
                padding: 20px 28px;
                margin: 0;
                -webkit-font-smoothing: antialiased;
            }
            h1, h2, h3, h4, h5, h6 {
                margin-top: 24px;
                margin-bottom: 16px;
                font-weight: 600;
                line-height: 1.25;
            }
            h1 { font-size: 2em; border-bottom: 1px solid \(hrColor); padding-bottom: 0.3em; }
            h2 { font-size: 1.5em; border-bottom: 1px solid \(hrColor); padding-bottom: 0.3em; }
            h3 { font-size: 1.25em; }
            h4 { font-size: 1em; }
            h5 { font-size: 0.875em; }
            h6 { font-size: 0.85em; color: \(blockquoteFg); }
            p { margin-top: 0; margin-bottom: 16px; }
            a { color: \(linkColor); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code {
                font-family: "SF Mono", SFMono-Regular, Menlo, Consolas, monospace;
                font-size: 85%;
                background-color: \(codeBg);
                border: 1px solid \(codeBorder);
                border-radius: 3px;
                padding: 0.2em 0.4em;
            }
            pre {
                background-color: \(codeBg);
                border: 1px solid \(codeBorder);
                border-radius: 6px;
                padding: 16px;
                overflow-x: auto;
                line-height: 1.45;
                margin-bottom: 16px;
            }
            pre code {
                background: none;
                border: none;
                padding: 0;
                font-size: 85%;
            }
            .keyword { color: \(keywordColor); font-weight: 600; }
            .string { color: \(stringColor); }
            .comment { color: \(commentColor); font-style: italic; }
            blockquote {
                margin: 0 0 16px 0;
                padding: 0 16px;
                border-left: 4px solid \(blockquoteBorder);
                color: \(blockquoteFg);
            }
            ul, ol { padding-left: 2em; margin-bottom: 16px; }
            li { margin-bottom: 4px; }
            hr {
                height: 2px;
                background-color: \(hrColor);
                border: none;
                margin: 24px 0;
            }
            img { max-width: 100%; height: auto; border-radius: 4px; }
            table {
                border-collapse: collapse;
                width: 100%;
                margin-bottom: 16px;
            }
            th, td {
                border: 1px solid \(tableBorder);
                padding: 8px 12px;
                text-align: left;
            }
            th {
                font-weight: 600;
                background-color: \(tableStripeBg);
            }
            tr:nth-child(even) {
                background-color: \(tableStripeBg);
            }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Rendering Helpers

    private func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Replaces `<pre><code ...>...</code></pre>` blocks with unique placeholders.
    private func extractCodeBlocks(_ html: String, store: inout [String: String]) -> String {
        let pattern = "<pre><code[^>]*>[\\s\\S]*?</code></pre>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        var result = html
        let matches = regex.matches(in: html, range: range)
        for (index, match) in matches.reversed().enumerated() {
            guard let matchRange = Range(match.range, in: result) else { continue }
            let original = String(result[matchRange])
            let placeholder = "<!--CODEBLOCK-\(matches.count - 1 - index)-PLACEHOLDER-->"
            store[placeholder] = original
            result = result.replacingCharacters(in: matchRange, with: placeholder)
        }
        return result
    }

    /// Restores code block placeholders with their original content.
    private func restoreCodeBlocks(_ html: String, store: [String: String]) -> String {
        var result = html
        for (placeholder, original) in store {
            result = result.replacingOccurrences(of: placeholder, with: original)
        }
        return result
    }

    private func renderCodeBlocks(_ html: String) -> String {
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<pre><code class=\"language-$1\">$2</code></pre>")
    }

    private func renderTables(_ html: String) -> String {
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Detect table: current line has pipes, next line is separator
            if line.contains("|"),
               i + 1 < lines.count,
               isTableSeparator(lines[i + 1]) {

                var tableHTML = "<table>\n<thead>\n<tr>\n"
                let headers = parseTableRow(line)
                for header in headers {
                    tableHTML += "<th>\(header.trimmingCharacters(in: .whitespaces))</th>\n"
                }
                tableHTML += "</tr>\n</thead>\n<tbody>\n"

                // Skip header and separator
                i += 2

                // Body rows
                while i < lines.count, lines[i].contains("|") {
                    let cells = parseTableRow(lines[i])
                    tableHTML += "<tr>\n"
                    for cell in cells {
                        tableHTML += "<td>\(cell.trimmingCharacters(in: .whitespaces))</td>\n"
                    }
                    tableHTML += "</tr>\n"
                    i += 1
                }

                tableHTML += "</tbody>\n</table>"
                result.append(tableHTML)
            } else {
                result.append(line)
                i += 1
            }
        }

        return result.joined(separator: "\n")
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        let stripped = trimmed.replacingOccurrences(of: "|", with: "")
                             .replacingOccurrences(of: "-", with: "")
                             .replacingOccurrences(of: ":", with: "")
                             .trimmingCharacters(in: .whitespaces)
        return stripped.isEmpty
    }

    private func parseTableRow(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|")
        // Remove leading/trailing empty elements from outer pipes
        if let first = cells.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            cells.removeFirst()
        }
        if let last = cells.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            cells.removeLast()
        }
        return cells
    }

    private func renderBlockquotes(_ html: String) -> String {
        let pattern = "(?m)^&gt; (.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        var result = regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<blockquote><p>$1</p></blockquote>")
        // Merge consecutive blockquotes into a single blockquote
        result = wrapConsecutiveTags(result, tag: "blockquote", wrapper: "blockquote")
        // Remove the inner <blockquote></blockquote> tags that are now redundant
        result = result.replacingOccurrences(of: "<blockquote>\n<blockquote>", with: "<blockquote>")
        result = result.replacingOccurrences(of: "</blockquote>\n</blockquote>", with: "</blockquote>")
        return result
    }

    private func renderHorizontalRules(_ html: String) -> String {
        let pattern = "(?m)^(---|\\*\\*\\*|___)\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<hr>")
    }

    private func renderHeaders(_ html: String) -> String {
        var result = html
        for level in (1...6).reversed() {
            let hashes = String(repeating: "#", count: level)
            let pattern = "(?m)^" + NSRegularExpression.escapedPattern(for: hashes) + "\\s+(.+)$"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<h\(level)>$1</h\(level)>")
        }
        return result
    }

    private func renderUnorderedLists(_ html: String) -> String {
        let pattern = "(?m)^[*\\-+] (.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        var result = regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<li>$1</li>")
        // Wrap consecutive <li> blocks in <ul>
        result = wrapConsecutiveTags(result, tag: "li", wrapper: "ul")
        return result
    }

    private func renderOrderedLists(_ html: String) -> String {
        let pattern = "(?m)^\\d+\\. (.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        var result = regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<li>$1</li>")
        result = wrapConsecutiveTags(result, tag: "li", wrapper: "ol")
        return result
    }

    private func wrapConsecutiveTags(_ html: String, tag: String, wrapper: String) -> String {
        let pattern = "(<\(tag)>.*?</\(tag)>\\n?)+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<\(wrapper)>\n$0</\(wrapper)>")
    }

    private func renderImages(_ html: String) -> String {
        let pattern = "!\\[([^\\]]*)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let nsHTML = html as NSString
        let range = NSRange(location: 0, length: nsHTML.length)
        var result = html
        // Process matches in reverse to preserve ranges
        let matches = regex.matches(in: html, range: range)
        for match in matches.reversed() {
            let urlRange = match.range(at: 2)
            let url = nsHTML.substring(with: urlRange)
            if url.lowercased().trimmingCharacters(in: .whitespaces).hasPrefix("javascript:") {
                let altRange = match.range(at: 1)
                let alt = nsHTML.substring(with: altRange)
                guard let fullRange = Range(match.range, in: result) else { continue }
                result = result.replacingCharacters(in: fullRange, with: alt)
            }
        }
        // Re-run regex for safe URLs
        guard let regex2 = try? NSRegularExpression(pattern: pattern) else { return result }
        let range2 = NSRange(result.startIndex..., in: result)
        return regex2.stringByReplacingMatches(in: result, range: range2, withTemplate: "<img src=\"$2\" alt=\"$1\">")
    }

    private func renderLinks(_ html: String) -> String {
        let pattern = "\\[([^\\]]*)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let nsHTML = html as NSString
        let range = NSRange(location: 0, length: nsHTML.length)
        var result = html
        // Process matches in reverse to preserve ranges
        let matches = regex.matches(in: html, range: range)
        for match in matches.reversed() {
            let urlRange = match.range(at: 2)
            let url = nsHTML.substring(with: urlRange)
            if url.lowercased().trimmingCharacters(in: .whitespaces).hasPrefix("javascript:") {
                let textRange = match.range(at: 1)
                let text = nsHTML.substring(with: textRange)
                guard let fullRange = Range(match.range, in: result) else { continue }
                result = result.replacingCharacters(in: fullRange, with: text)
            }
        }
        // Re-run regex for safe URLs
        guard let regex2 = try? NSRegularExpression(pattern: pattern) else { return result }
        let range2 = NSRange(result.startIndex..., in: result)
        return regex2.stringByReplacingMatches(in: result, range: range2, withTemplate: "<a href=\"$2\">$1</a>")
    }

    private func renderBold(_ html: String) -> String {
        let pattern = "(\\*\\*|__)(.+?)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<strong>$2</strong>")
    }

    private func renderItalic(_ html: String) -> String {
        let pattern = "(?<![*_])([*_])(?![*_])(.+?)\\1(?![*_])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<em>$2</em>")
    }

    private func renderInlineCode(_ html: String) -> String {
        let pattern = "`([^`]+)`"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        return regex.stringByReplacingMatches(in: html, range: range, withTemplate: "<code>$1</code>")
    }

    private func renderParagraphs(_ html: String) -> String {
        let lines = html.components(separatedBy: "\n\n")
        let blockTags = ["<h", "<ul", "<ol", "<li", "<pre", "<blockquote", "<table", "<hr", "<img"]
        return lines.map { block in
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            let isBlock = blockTags.contains(where: { trimmed.hasPrefix($0) })
            return isBlock ? trimmed : "<p>\(trimmed)</p>"
        }.joined(separator: "\n")
    }
}

// MARK: - MarkdownPreviewController

/// Displays a live Markdown preview inside a WKWebView.
@available(macOS 13.0, *)
public final class MarkdownPreviewController: NSViewController {

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(false, forKey: "javaScriptEnabled")
        return WKWebView(frame: .zero, configuration: config)
    }()
    private let renderer = MarkdownRenderer()

    /// When `true`, the preview uses dark-mode styling.
    public var isDarkMode: Bool = false {
        didSet { refreshIfNeeded() }
    }

    /// The last Markdown source used to render the preview, cached to avoid redundant updates.
    private var lastMarkdown: String = ""

    // MARK: - View Lifecycle

    public override func loadView() {
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
    }

    // MARK: - Public API

    /// Renders the given Markdown string and loads it into the web view.
    public func updatePreview(markdown: String) {
        lastMarkdown = markdown
        let body = renderer.renderToHTML(markdown: markdown)
        let fullHTML = renderer.wrapInHTMLTemplate(body: body, darkMode: isDarkMode)
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    // MARK: - Helpers

    private func refreshIfNeeded() {
        guard !lastMarkdown.isEmpty else { return }
        updatePreview(markdown: lastMarkdown)
    }
}
