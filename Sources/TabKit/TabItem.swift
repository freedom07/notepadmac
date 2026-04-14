import AppKit
import CommonKit

// MARK: - TabItem

/// Represents a single tab in the tab bar.
///
/// `TabItem` is an `NSObject` subclass to support KVO observation on its mutable properties.
/// Each tab tracks its file path, modification state, and pinned status.
public final class TabItem: NSObject {

    /// Stable identifier for the tab, persists across renames and moves.
    public let id: UUID

    /// Display title shown on the tab (typically the filename).
    @objc public dynamic var title: String

    /// File URL on disk, or `nil` for unsaved documents.
    @objc public dynamic var filePath: URL?

    /// Whether the document has unsaved changes.
    @objc public dynamic var isModified: Bool

    /// Whether the tab is pinned to the leading edge of the tab bar.
    @objc public dynamic var isPinned: Bool

    /// Color tag index for visual color coding.
    /// 0 = no color, 1 = red, 2 = blue, 3 = green, 4 = orange, 5 = purple.
    @objc public dynamic var colorTag: Int = 0

    /// Tooltip text: full file path when saved, "Untitled" otherwise.
    public var tooltip: String {
        filePath?.path ?? "Untitled"
    }

    // MARK: - Initializer

    /// Creates a new tab item.
    ///
    /// - Parameters:
    ///   - title: Display title for the tab.
    ///   - filePath: File URL on disk, or `nil` for a new unsaved document.
    ///   - isModified: Initial modification state. Defaults to `false`.
    ///   - isPinned: Initial pinned state. Defaults to `false`.
    public init(
        title: String,
        filePath: URL? = nil,
        isModified: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.filePath = filePath
        self.isModified = isModified
        self.isPinned = isPinned
        super.init()
    }

    // MARK: - Equality

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? TabItem else { return false }
        return id == other.id
    }

    public override var hash: Int {
        id.hashValue
    }
}
