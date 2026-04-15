import AppKit

@available(macOS 13.0, *)
public final class UpdateChecker {

    public static let shared = UpdateChecker()

    private let repoOwner = "freedom07"
    private let repoName = "notepadmac"
    private let checkIntervalKey = "NotepadMac.lastUpdateCheck"

    private init() {}

    // MARK: - Public API

    /// Check on launch — at most once per day, silently ignores if up-to-date.
    public func checkOnLaunch() {
        let defaults = UserDefaults.standard
        let lastCheck = defaults.double(forKey: checkIntervalKey)
        let now = Date().timeIntervalSince1970
        // Skip if checked within the last 24 hours
        guard now - lastCheck > 86400 else { return }
        defaults.set(now, forKey: checkIntervalKey)

        check(silent: true)
    }

    /// Manual check from menu — always shows result.
    public func checkNow() {
        check(silent: false)
    }

    // MARK: - Internal

    private func check(silent: Bool) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200
            else {
                if !silent { self.showUpToDate() }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String
            else {
                if !silent { self.showUpToDate() }
                return
            }

            let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

            if self.isNewer(latestVersion, than: appVersion) {
                self.showUpdateAvailable(version: latestVersion, url: htmlURL)
            } else if !silent {
                self.showUpToDate()
            }
        }.resume()
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    // MARK: - UI (must run on main thread)

    private func showUpdateAvailable(version: String, url: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "New Version Available"
            alert.informativeText = "NotepadMac \(version) is available. You are currently running \(appVersion)."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn, let downloadURL = URL(string: url) {
                NSWorkspace.shared.open(downloadURL)
            }
        }
    }

    private func showUpToDate() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "You're Up to Date"
            alert.informativeText = "NotepadMac \(appVersion) is the latest version."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
