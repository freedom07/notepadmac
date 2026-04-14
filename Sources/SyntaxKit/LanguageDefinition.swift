// LanguageDefinition.swift
// SyntaxKit — NotepadNext
//
// Core types for regex-based syntax highlighting:
// token classification, highlight rules, and language definitions.

import Foundation
import CommonKit

// MARK: - TokenType

/// Classification of a lexical token for syntax highlighting.
public enum TokenType: String, CaseIterable, Sendable {
    case keyword, string, comment, number, type, function
    case variable, `operator`, punctuation, preprocessor, attribute, tag, plain
}

// MARK: - HighlightRule

/// A single regex-based highlighting rule that maps matched text to a token type.
public struct HighlightRule: Sendable {
    public let pattern: String
    public let tokenType: TokenType
    public init(pattern: String, tokenType: TokenType) {
        self.pattern = pattern; self.tokenType = tokenType
    }
}

// MARK: - LanguageDefinition

/// Describes a programming language for syntax highlighting purposes.
public struct LanguageDefinition: Sendable {
    public let id: String
    public let displayName: String
    public let fileExtensions: [String]
    public let lineComment: String?
    public let blockCommentStart: String?
    public let blockCommentEnd: String?
    public let rules: [HighlightRule]

    public init(id: String, displayName: String, fileExtensions: [String],
                lineComment: String? = nil, blockCommentStart: String? = nil,
                blockCommentEnd: String? = nil, rules: [HighlightRule]) {
        self.id = id; self.displayName = displayName; self.fileExtensions = fileExtensions
        self.lineComment = lineComment; self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd; self.rules = rules
    }
}
