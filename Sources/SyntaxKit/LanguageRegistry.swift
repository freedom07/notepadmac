// LanguageRegistry.swift
// SyntaxKit — NotepadNext
//
// Central registry that maps language IDs and file extensions
// to their LanguageDefinition. Singleton; auto-registers built-in languages.

import Foundation
import CommonKit

// MARK: - LanguageRegistry

/// Central store for all known ``LanguageDefinition``s.
public final class LanguageRegistry: @unchecked Sendable {

    // MARK: Singleton

    public static let shared = LanguageRegistry()

    // MARK: Storage

    private var languages: [String: LanguageDefinition] = [:]
    private var extensionMap: [String: String] = [:]
    private let lock = NSLock()

    // MARK: Init

    init() {
        registerBuiltinLanguages()
    }

    // MARK: Registration

    /// Register a language definition.
    public func register(_ lang: LanguageDefinition) {
        lock.lock()
        defer { lock.unlock() }

        languages[lang.id] = lang
        for ext in lang.fileExtensions {
            extensionMap[ext.lowercased()] = lang.id
        }
    }

    // MARK: Lookup

    /// Returns the language definition for the given file extension.
    public func language(forExtension ext: String) -> LanguageDefinition? {
        lock.lock()
        defer { lock.unlock() }

        guard let id = extensionMap[ext.lowercased()] else { return nil }
        return languages[id]
    }

    /// Returns the language definition with the given identifier.
    public func language(forID id: String) -> LanguageDefinition? {
        lock.lock()
        defer { lock.unlock() }

        return languages[id]
    }

    /// All currently registered language definitions, sorted by display name.
    public var allLanguages: [LanguageDefinition] {
        lock.lock()
        defer { lock.unlock() }

        return languages.values.sorted { $0.displayName < $1.displayName }
    }

    // MARK: Built-in Languages

    /// Registers all built-in language definitions shipped with SyntaxKit.
    func registerBuiltinLanguages() {
        BuiltinLanguages.registerAll(in: self)
    }
}
