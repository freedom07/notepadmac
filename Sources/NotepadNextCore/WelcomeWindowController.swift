import AppKit
import CommonKit

/// Displays a welcome screen when no files are open.
/// Shows recent files, "New File", and "Open File" buttons.
@available(macOS 13.0, *)
public class WelcomeWindowController: NSWindowController {

    private let recentFileURLs: [URL]
    public var onNewFile: (() -> Void)?
    public var onOpenFile: (() -> Void)?
    public var onOpenRecentFile: ((URL) -> Void)?

    public init(recentFiles: [URL] = []) {
        self.recentFileURLs = recentFiles

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to \(CommonKit.appName)"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setupContent() {
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        window?.contentView = contentView

        // App icon
        let iconView = NSImageView(frame: NSRect(x: 200, y: 320, width: 64, height: 64))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: CommonKit.appName)
        titleLabel.frame = NSRect(x: 0, y: 290, width: 500, height: 24)
        titleLabel.alignment = .center
        titleLabel.font = NSFont.boldSystemFont(ofSize: 18)
        contentView.addSubview(titleLabel)

        // Version
        let versionLabel = NSTextField(labelWithString: "Version \(appVersion)")
        versionLabel.frame = NSRect(x: 0, y: 268, width: 500, height: 18)
        versionLabel.alignment = .center
        versionLabel.font = NSFont.systemFont(ofSize: 12)
        versionLabel.textColor = .secondaryLabelColor
        contentView.addSubview(versionLabel)

        // Buttons
        let newButton = NSButton(title: "New File", target: self, action: #selector(newFileClicked))
        newButton.frame = NSRect(x: 120, y: 230, width: 120, height: 30)
        newButton.bezelStyle = .rounded
        contentView.addSubview(newButton)

        let openButton = NSButton(title: "Open File", target: self, action: #selector(openFileClicked))
        openButton.frame = NSRect(x: 260, y: 230, width: 120, height: 30)
        openButton.bezelStyle = .rounded
        contentView.addSubview(openButton)

        // Recent files header
        if !recentFileURLs.isEmpty {
            let recentLabel = NSTextField(labelWithString: "Recent Files")
            recentLabel.frame = NSRect(x: 30, y: 200, width: 440, height: 18)
            recentLabel.font = NSFont.boldSystemFont(ofSize: 13)
            contentView.addSubview(recentLabel)

            var y = 175
            for (index, url) in recentFileURLs.prefix(8).enumerated() {
                let button = NSButton(title: url.lastPathComponent, target: self, action: #selector(recentFileClicked(_:)))
                button.frame = NSRect(x: 30, y: y, width: 440, height: 22)
                button.alignment = .left
                button.isBordered = false
                button.tag = index
                button.contentTintColor = .linkColor
                contentView.addSubview(button)
                y -= 24
            }
        }
    }

    @objc private func newFileClicked() {
        onNewFile?()
        close()
    }

    @objc private func openFileClicked() {
        onOpenFile?()
        close()
    }

    @objc private func recentFileClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0, index < recentFileURLs.count else { return }
        onOpenRecentFile?(recentFileURLs[index])
        close()
    }
}
