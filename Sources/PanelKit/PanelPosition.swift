import Foundation

/// Where a panel can be docked within the editor window.
public enum PanelPosition: String, Sendable, CaseIterable {
    case left
    case right
    case bottom
}

/// Metadata for a panel that can be shown in the dock areas.
public struct PanelDescriptor: Sendable {
    public let id: String
    public let title: String
    public let position: PanelPosition
    public let iconSystemName: String

    public init(id: String, title: String, position: PanelPosition, iconSystemName: String) {
        self.id = id
        self.title = title
        self.position = position
        self.iconSystemName = iconSystemName
    }
}
