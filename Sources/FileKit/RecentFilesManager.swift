import AppKit
import CommonKit

public class RecentFilesManager: NSObject {
    public static let shared = RecentFilesManager()
    private let maxCount = 20; private let key = "NotepadMac.recentFiles"
    private override init() { super.init() }

    /// Callback invoked when a recent file is selected from the menu.
    public var onFileSelected: ((URL) -> Void)?

    /// Callback invoked when the recent files list is cleared.
    public var onClearAll: (() -> Void)?

    public var recentFiles: [URL] { (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap { URL(fileURLWithPath: $0) } }
    public func addFile(_ url: URL) { var f = recentFiles.map { $0.path }; f.removeAll { $0 == url.path }; f.insert(url.path, at: 0); UserDefaults.standard.set(Array(f.prefix(maxCount)), forKey: key) }
    public func removeFile(_ url: URL) { var f = recentFiles.map { $0.path }; f.removeAll { $0 == url.path }; UserDefaults.standard.set(f, forKey: key) }
    @objc public func clearAll() { UserDefaults.standard.removeObject(forKey: key); onClearAll?() }

    @objc private func recentFileClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        onFileSelected?(url)
    }

    public func buildMenu() -> NSMenu {
        let m = NSMenu(title: "Recent Files")
        for u in recentFiles {
            let item = NSMenuItem(title: u.lastPathComponent, action: #selector(recentFileClicked(_:)), keyEquivalent: "")
            item.target = self
            item.toolTip = u.path
            item.representedObject = u
            m.addItem(item)
        }
        if !recentFiles.isEmpty {
            m.addItem(.separator())
            let clearItem = NSMenuItem(title: "Clear", action: #selector(clearAll), keyEquivalent: "")
            clearItem.target = self
            m.addItem(clearItem)
        }
        return m
    }
}
