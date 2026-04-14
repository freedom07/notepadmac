import XCTest
@testable import MarkdownKit
import CommonKit

// MARK: - MarkdownRenderer Tests

@available(macOS 13.0, *)
final class MarkdownRendererTests: XCTestCase {

    private var renderer: MarkdownRenderer!

    override func setUp() {
        super.setUp()
        renderer = MarkdownRenderer()
    }

    override func tearDown() {
        renderer = nil
        super.tearDown()
    }

    // MARK: - Headers

    func testRenderHeader1() {
        let result = renderer.renderToHTML(markdown: "# Hello")
        XCTAssertTrue(result.contains("<h1>Hello</h1>"),
                       "Expected <h1>Hello</h1> but got: \(result)")
    }

    func testRenderHeader2() {
        let result = renderer.renderToHTML(markdown: "## Hello")
        XCTAssertTrue(result.contains("<h2>Hello</h2>"),
                       "Expected <h2>Hello</h2> but got: \(result)")
    }

    // MARK: - Inline Formatting

    func testRenderBold() {
        let result = renderer.renderToHTML(markdown: "**bold**")
        XCTAssertTrue(result.contains("<strong>bold</strong>"),
                       "Expected <strong>bold</strong> but got: \(result)")
    }

    func testRenderItalic() {
        let result = renderer.renderToHTML(markdown: "*italic*")
        XCTAssertTrue(result.contains("<em>italic</em>"),
                       "Expected <em>italic</em> but got: \(result)")
    }

    func testRenderInlineCode() {
        let result = renderer.renderToHTML(markdown: "`code`")
        XCTAssertTrue(result.contains("<code>code</code>"),
                       "Expected <code>code</code> but got: \(result)")
    }

    // MARK: - Links

    func testRenderLink() {
        let result = renderer.renderToHTML(markdown: "[text](url)")
        XCTAssertTrue(result.contains("<a href=\"url\">text</a>"),
                       "Expected anchor tag with href=\"url\" but got: \(result)")
    }

    // MARK: - Lists

    func testRenderUnorderedList() {
        let result = renderer.renderToHTML(markdown: "- item")
        XCTAssertTrue(result.contains("<ul>"),
                       "Expected <ul> tag but got: \(result)")
        XCTAssertTrue(result.contains("<li>item</li>"),
                       "Expected <li>item</li> but got: \(result)")
    }

    // MARK: - Blockquote

    func testRenderBlockquote() {
        let result = renderer.renderToHTML(markdown: "> quote")
        XCTAssertTrue(result.contains("<blockquote>"),
                       "Expected <blockquote> tag but got: \(result)")
        XCTAssertTrue(result.contains("quote"),
                       "Expected quote content but got: \(result)")
    }

    // MARK: - Horizontal Rule

    func testRenderHorizontalRule() {
        let result = renderer.renderToHTML(markdown: "---")
        XCTAssertTrue(result.contains("<hr"),
                       "Expected <hr tag but got: \(result)")
    }

    // MARK: - Edge Cases

    func testRenderEmptyInput() {
        let result = renderer.renderToHTML(markdown: "")
        // Should not crash; result can be empty or whitespace
        XCTAssertNotNil(result, "renderToHTML should not return nil for empty input")
    }

    // MARK: - HTML Template

    func testWrapInHTMLTemplate() {
        let body = "<p>Hello</p>"
        let result = renderer.wrapInHTMLTemplate(body: body, darkMode: false)
        XCTAssertTrue(result.contains("<html>"),
                       "Expected <html> tag but got: \(result)")
        XCTAssertTrue(result.contains("<head>"),
                       "Expected <head> tag but got: \(result)")
        XCTAssertTrue(result.contains("<body>"),
                       "Expected <body> tag but got: \(result)")
        XCTAssertTrue(result.contains(body),
                       "Expected body content in template but got: \(result)")
    }

    func testWrapInHTMLTemplateDarkMode() {
        let body = "<p>Hello</p>"
        let lightResult = renderer.wrapInHTMLTemplate(body: body, darkMode: false)
        let darkResult = renderer.wrapInHTMLTemplate(body: body, darkMode: true)
        // Dark mode uses different background color (#1e1e1e vs #ffffff)
        XCTAssertTrue(lightResult.contains("#ffffff"),
                       "Light mode should contain #ffffff")
        XCTAssertTrue(darkResult.contains("#1e1e1e"),
                       "Dark mode should contain #1e1e1e")
        XCTAssertNotEqual(lightResult, darkResult,
                           "Dark mode CSS should differ from light mode CSS")
    }

    // MARK: - Ordered Lists

    func testRenderOrderedList() {
        let result = renderer.renderToHTML(markdown: "1. first\n2. second\n3. third")
        XCTAssertTrue(result.contains("<ol>"),
                       "Expected <ol> tag but got: \(result)")
        XCTAssertTrue(result.contains("<li>first</li>"),
                       "Expected <li>first</li> but got: \(result)")
        XCTAssertTrue(result.contains("<li>second</li>"),
                       "Expected <li>second</li> but got: \(result)")
        XCTAssertTrue(result.contains("<li>third</li>"),
                       "Expected <li>third</li> but got: \(result)")
    }

    // MARK: - Code Blocks

    func testRenderCodeBlock() {
        let markdown = "```\nlet x = 1\nprint(x)\n```"
        let result = renderer.renderToHTML(markdown: markdown)
        XCTAssertTrue(result.contains("<pre><code"),
                       "Expected <pre><code> tag but got: \(result)")
        XCTAssertTrue(result.contains("let x = 1"),
                       "Expected code content but got: \(result)")
    }

    func testRenderCodeBlockWithLanguage() {
        let markdown = "```swift\nlet x = 1\n```"
        let result = renderer.renderToHTML(markdown: markdown)
        XCTAssertTrue(result.contains("language-swift"),
                       "Expected language-swift class but got: \(result)")
        XCTAssertTrue(result.contains("let x = 1"),
                       "Expected code content but got: \(result)")
    }

    // MARK: - Tables

    func testRenderTable() {
        let markdown = "| Name | Age |\n| --- | --- |\n| Alice | 30 |\n| Bob | 25 |"
        let result = renderer.renderToHTML(markdown: markdown)
        XCTAssertTrue(result.contains("<table>"),
                       "Expected <table> tag but got: \(result)")
        XCTAssertTrue(result.contains("<th>"),
                       "Expected <th> tag but got: \(result)")
        XCTAssertTrue(result.contains("<td>"),
                       "Expected <td> tag but got: \(result)")
        XCTAssertTrue(result.contains("Alice"),
                       "Expected 'Alice' in table but got: \(result)")
        XCTAssertTrue(result.contains("Bob"),
                       "Expected 'Bob' in table but got: \(result)")
    }

    // MARK: - Images

    func testRenderImage() {
        let result = renderer.renderToHTML(markdown: "![alt text](https://example.com/img.png)")
        XCTAssertTrue(result.contains("<img"),
                       "Expected <img tag but got: \(result)")
        XCTAssertTrue(result.contains("alt=\"alt text\""),
                       "Expected alt attribute but got: \(result)")
        XCTAssertTrue(result.contains("src=\"https://example.com/img.png\""),
                       "Expected src attribute but got: \(result)")
    }

    // MARK: - Headers h3-h6

    func testRenderHeader3Through6() {
        let h3 = renderer.renderToHTML(markdown: "### H3")
        XCTAssertTrue(h3.contains("<h3>H3</h3>"),
                       "Expected <h3>H3</h3> but got: \(h3)")

        let h4 = renderer.renderToHTML(markdown: "#### H4")
        XCTAssertTrue(h4.contains("<h4>H4</h4>"),
                       "Expected <h4>H4</h4> but got: \(h4)")

        let h5 = renderer.renderToHTML(markdown: "##### H5")
        XCTAssertTrue(h5.contains("<h5>H5</h5>"),
                       "Expected <h5>H5</h5> but got: \(h5)")

        let h6 = renderer.renderToHTML(markdown: "###### H6")
        XCTAssertTrue(h6.contains("<h6>H6</h6>"),
                       "Expected <h6>H6</h6> but got: \(h6)")
    }

    // MARK: - Nested Formatting

    func testRenderNestedBoldItalic() {
        let result = renderer.renderToHTML(markdown: "***text***")
        // ***text*** should produce both <strong> and <em> tags
        XCTAssertTrue(result.contains("<strong>"),
                       "Expected <strong> tag for bold but got: \(result)")
        XCTAssertTrue(result.contains("<em>"),
                       "Expected <em> tag for italic but got: \(result)")
        XCTAssertTrue(result.contains("text"),
                       "Expected 'text' content but got: \(result)")
    }

    // MARK: - HTML Escaping

    func testEscapeHTMLQuotes() {
        let result = renderer.renderToHTML(markdown: "She said \"hello\"")
        XCTAssertTrue(result.contains("&quot;"),
                       "Expected &quot; escaping but got: \(result)")
        XCTAssertFalse(result.contains("\"hello\""),
                        "Raw quotes should be escaped but got: \(result)")
    }

    // MARK: - XSS Prevention

    func testXSSJavascriptURL() {
        // Links with javascript: should be stripped
        let linkResult = renderer.renderToHTML(markdown: "[click](javascript:alert(1))")
        XCTAssertFalse(linkResult.contains("javascript:"),
                        "javascript: URL should be blocked in links but got: \(linkResult)")

        // Images with javascript: should be stripped
        let imgResult = renderer.renderToHTML(markdown: "![img](javascript:alert(1))")
        XCTAssertFalse(imgResult.contains("javascript:"),
                        "javascript: URL should be blocked in images but got: \(imgResult)")
    }

    // MARK: - Code Block Preservation

    func testCodeBlockPreservesMarkdown() {
        let markdown = "```\n**not bold**\n*not italic*\n```"
        let result = renderer.renderToHTML(markdown: markdown)
        // Inside code blocks, markdown syntax should NOT be converted
        XCTAssertFalse(result.contains("<strong>not bold</strong>"),
                        "Code block should not render bold but got: \(result)")
        XCTAssertFalse(result.contains("<em>not italic</em>"),
                        "Code block should not render italic but got: \(result)")
    }

    // MARK: - Consecutive Blockquotes

    func testConsecutiveBlockquotesMerged() {
        let markdown = "> line1\n> line2\n> line3"
        let result = renderer.renderToHTML(markdown: markdown)
        // Consecutive blockquotes should be wrapped in a single outer <blockquote>
        // The renderer wraps consecutive blockquotes and then cleans inner tags
        XCTAssertTrue(result.contains("line1"),
                       "Expected line1 content but got: \(result)")
        XCTAssertTrue(result.contains("line2"),
                       "Expected line2 content but got: \(result)")
        XCTAssertTrue(result.contains("line3"),
                       "Expected line3 content but got: \(result)")
        XCTAssertTrue(result.contains("<blockquote>"),
                       "Expected <blockquote> wrapper but got: \(result)")
        // All lines should be within blockquote context, not as separate <p> tags outside
        XCTAssertTrue(result.contains("</blockquote>"),
                       "Expected closing </blockquote> but got: \(result)")
    }
}
