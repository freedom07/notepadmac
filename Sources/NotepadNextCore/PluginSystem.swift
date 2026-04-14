import AppKit
import CommonKit

// MARK: - PluginCapability

public enum PluginCapability: String, Sendable {
    case documentRead
    case documentWrite
    case uiPanels
    case commands
    case settings
}

// MARK: - PluginManifest

public struct PluginManifest: Codable, Sendable {
    public let identifier: String
    public let displayName: String
    public let version: String
    public let description_: String
    public let capabilities: [String]

    enum CodingKeys: String, CodingKey {
        case identifier
        case displayName
        case version
        case description_ = "description"
        case capabilities
    }

    public init(
        identifier: String,
        displayName: String,
        version: String,
        description_: String,
        capabilities: [String]
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.version = version
        self.description_ = description_
        self.capabilities = capabilities
    }
}

// MARK: - EditorPluginProtocol

public protocol EditorPluginProtocol {
    static var identifier: String { get }
    static var displayName: String { get }
    func activate(context: any PluginContextProtocol)
    func deactivate()
}

// MARK: - PluginContextProtocol

public protocol PluginContextProtocol {
    var activeDocumentText: String? { get }
    func replaceActiveDocumentText(_ text: String)
    func showNotification(message: String)
}

// MARK: - PluginManager

public class PluginManager {

    public static let shared = PluginManager()

    private var plugins: [String: any EditorPluginProtocol] = [:]

    private init() {}

    /// Removes all registered plugins. Intended for testing.
    public func removeAllPlugins() {
        plugins.removeAll()
    }

    public func registerPlugin(_ plugin: any EditorPluginProtocol) {
        let id = type(of: plugin).identifier
        plugins[id] = plugin
    }

    public func activateAll(context: any PluginContextProtocol) {
        for plugin in plugins.values {
            plugin.activate(context: context)
        }
    }

    public func deactivateAll() {
        for plugin in plugins.values {
            plugin.deactivate()
        }
    }

    public var loadedPluginIDs: [String] {
        Array(plugins.keys)
    }
}
