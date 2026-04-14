import AppKit
import CommonKit

public class ThemeManager {
    public static let shared = ThemeManager()
    public private(set) var currentTheme: Theme
    public private(set) var availableThemes: [Theme] = []
    public var onThemeChanged: ((Theme) -> Void)?

    private init() {
        self.currentTheme = BuiltinThemes.oneDark
        loadBuiltinThemes()
    }

    public func loadBuiltinThemes() {
        availableThemes = BuiltinThemes.allBuiltinThemes
    }

    public func setTheme(_ theme: Theme) {
        currentTheme = theme
        onThemeChanged?(theme)
    }

    public func theme(named name: String) -> Theme? {
        availableThemes.first { $0.name == name }
    }

    // MARK: - Dark Mode System Integration

    /// Observes system appearance changes and automatically switches between
    /// dark and light themes.
    public func observeSystemAppearance() {
        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleAppearanceChange()
        }
    }

    private func handleAppearanceChange() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if let theme = theme(named: isDark ? "One Dark" : "Default Light") {
            setTheme(theme)
        }
    }
}
