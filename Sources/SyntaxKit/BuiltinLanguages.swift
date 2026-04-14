// BuiltinLanguages.swift
// SyntaxKit — NotepadNext
//
// Regex-based language definitions for 49 built-in languages.
// Each definition provides keyword, string, comment, and number patterns
// tailored to the target language.

import Foundation
import CommonKit

// MARK: - BuiltinLanguages

/// Factory that produces all built-in ``LanguageDefinition``s.
public enum BuiltinLanguages {

    /// All built-in language definitions.
    public static var all: [LanguageDefinition] {
        [
            swift, python, javascript, typescript,
            html, css, json, xml, markdown,
            c, cpp, java, ruby, go, rust,
            sql, shellBash, yaml, toml,
            php, kotlin, perl, lua, r,
            dart, objc, scala, diff, makefile,
            // Batch 2
            powershell, dockerfile, ini, properties, latex,
            haskell, elixir, groovy, pascal, assembly,
            // Batch 3
            fortran, erlang, clojure, fsharp, nim,
            zig, svelte, vue, graphql, protobuf,
        ]
    }

    /// Register all built-in languages in the given registry.
    static func registerAll(in registry: LanguageRegistry) {
        for lang in all {
            registry.register(lang)
        }
    }

    // MARK: - Helpers

    /// Builds a keyword pattern that matches any of the given words as whole words.
    private static func keywordPattern(_ words: [String]) -> String {
        let joined = words.joined(separator: "|")
        return "\\b(\(joined))\\b"
    }

    /// Builds a type-name pattern that matches any of the given words.
    private static func typePattern(_ words: [String]) -> String {
        let joined = words.joined(separator: "|")
        return "\\b(\(joined))\\b"
    }

    // MARK: - Common Patterns

    /// Double-quoted string including escape sequences.
    private static let doubleQuotedString = "\"(?:[^\"\\\\]|\\\\.)*\""
    /// Single-quoted string including escape sequences.
    private static let singleQuotedString = "'(?:[^'\\\\]|\\\\.)*'"
    /// Backtick template literal (JS/TS).
    private static let templateLiteral = "`(?:[^`\\\\]|\\\\.)*`"
    /// Integer and floating-point numbers, including hex.
    private static let numberLiteral = "\\b(?:0[xX][0-9a-fA-F_]+|0[oO][0-7_]+|0[bB][01_]+|[0-9][0-9_]*(?:\\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)\\b"
    /// C-style line comment.
    private static let cLineComment = "//.*"
    /// C-style block comment (non-greedy).
    private static let cBlockComment = "/\\*[\\s\\S]*?\\*/"
    /// Hash line comment.
    private static let hashComment = "#.*"
    /// Common operators.
    private static let operators = "[-+*/%=!<>&|^~?:]+"
    /// Punctuation.
    private static let punctuation = "[{}()\\[\\];,.]"
    /// Function call pattern: identifier followed by `(`.
    private static let functionCall = "\\b([a-zA-Z_]\\w*)\\s*(?=\\()"

    // MARK: - Swift

    public static let swift = LanguageDefinition(
        id: "swift",
        displayName: "Swift",
        fileExtensions: ["swift"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "actor", "associatedtype", "async", "await", "break", "case", "catch", "class",
                "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
                "fallthrough", "fileprivate", "final", "for", "func", "guard", "if", "import",
                "in", "init", "inout", "internal", "is", "lazy", "let", "mutating", "nil",
                "nonmutating", "open", "operator", "override", "private", "protocol", "public",
                "repeat", "required", "rethrows", "return", "self", "Self", "some", "static",
                "struct", "subscript", "super", "switch", "throw", "throws", "try", "typealias",
                "var", "weak", "where", "while", "true", "false",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "Any", "AnyObject", "Array", "Bool", "Character", "Dictionary", "Double",
                "Float", "Int", "Int8", "Int16", "Int32", "Int64", "Never", "Optional",
                "Result", "Set", "String", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
                "Void",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: "#\\w+", tokenType: .preprocessor),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Python

    public static let python = LanguageDefinition(
        id: "python",
        displayName: "Python",
        fileExtensions: ["py", "pyw", "pyi"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "[fFrRbBuU]?\(doubleQuotedString)", tokenType: .string),
            HighlightRule(pattern: "[fFrRbBuU]?\(singleQuotedString)", tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "False", "None", "True", "and", "as", "assert", "async", "await",
                "break", "class", "continue", "def", "del", "elif", "else", "except",
                "finally", "for", "from", "global", "if", "import", "in", "is",
                "lambda", "nonlocal", "not", "or", "pass", "raise", "return",
                "try", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "int", "float", "str", "bool", "list", "dict", "tuple", "set",
                "frozenset", "bytes", "bytearray", "memoryview", "complex",
                "range", "type", "object", "None",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - JavaScript

    public static let javascript = LanguageDefinition(
        id: "javascript",
        displayName: "JavaScript",
        fileExtensions: ["js", "mjs", "cjs", "jsx"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: templateLiteral, tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends",
                "false", "finally", "for", "from", "function", "if", "import", "in",
                "instanceof", "let", "new", "null", "of", "return", "static", "super",
                "switch", "this", "throw", "true", "try", "typeof", "undefined", "var",
                "void", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "Array", "Boolean", "Date", "Error", "Function", "JSON", "Map", "Math",
                "Number", "Object", "Promise", "Proxy", "RegExp", "Set", "String",
                "Symbol", "WeakMap", "WeakSet",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - TypeScript

    public static let typescript = LanguageDefinition(
        id: "typescript",
        displayName: "TypeScript",
        fileExtensions: ["ts", "tsx"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: templateLiteral, tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "as", "async", "await", "break", "case", "catch", "class",
                "const", "continue", "debugger", "declare", "default", "delete", "do",
                "else", "enum", "export", "extends", "false", "finally", "for", "from",
                "function", "if", "implements", "import", "in", "instanceof", "interface",
                "is", "keyof", "let", "module", "namespace", "new", "null", "of",
                "override", "private", "protected", "public", "readonly", "return",
                "static", "super", "switch", "this", "throw", "true", "try", "type",
                "typeof", "undefined", "var", "void", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "any", "bigint", "boolean", "never", "number", "object", "string",
                "symbol", "unknown", "void", "Array", "Map", "Set", "Promise",
                "Record", "Partial", "Required", "Readonly", "Pick", "Omit",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - HTML

    public static let html = LanguageDefinition(
        id: "html",
        displayName: "HTML",
        fileExtensions: ["html", "htm", "xhtml"],
        lineComment: nil,
        blockCommentStart: "<!--",
        blockCommentEnd: "-->",
        rules: [
            HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "</? *\\w+", tokenType: .tag),
            HighlightRule(pattern: "/?>", tokenType: .tag),
            HighlightRule(pattern: "\\b[a-zA-Z-]+=", tokenType: .attribute),
            HighlightRule(pattern: "&\\w+;", tokenType: .keyword),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - CSS

    public static let css = LanguageDefinition(
        id: "css",
        displayName: "CSS",
        fileExtensions: ["css", "scss", "sass", "less"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "important", "inherit", "initial", "unset", "revert", "none", "auto",
                "block", "flex", "grid", "inline", "relative", "absolute", "fixed",
                "sticky", "static", "hidden", "visible", "solid", "dashed", "dotted",
                "normal", "bold", "italic",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "@\\w+", tokenType: .preprocessor),
            HighlightRule(pattern: "#[0-9a-fA-F]{3,8}\\b", tokenType: .number),
            HighlightRule(pattern: "[.#]\\w[\\w-]*", tokenType: .variable),
            HighlightRule(pattern: "[a-zA-Z-]+(?=\\s*:)", tokenType: .attribute),
            HighlightRule(pattern: "\\$[\\w-]+", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: "\\b[0-9]+\\.?[0-9]*(?:px|em|rem|%|vh|vw|vmin|vmax|pt|cm|mm|in|ch|ex|deg|rad|turn|s|ms)?\\b", tokenType: .number),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - JSON

    public static let json = LanguageDefinition(
        id: "json",
        displayName: "JSON",
        fileExtensions: ["json", "jsonc", "jsonl"],
        lineComment: nil,
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "\"(?:[^\"\\\\]|\\\\.)*\"\\s*(?=:)", tokenType: .attribute),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?:true|false|null)\\b", tokenType: .keyword),
            HighlightRule(pattern: "-?\\b[0-9]+\\.?[0-9]*(?:[eE][+-]?[0-9]+)?\\b", tokenType: .number),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - XML

    public static let xml = LanguageDefinition(
        id: "xml",
        displayName: "XML",
        fileExtensions: ["xml", "xsd", "xsl", "xslt", "svg", "plist"],
        lineComment: nil,
        blockCommentStart: "<!--",
        blockCommentEnd: "-->",
        rules: [
            HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment),
            HighlightRule(pattern: "<\\?[\\s\\S]*?\\?>", tokenType: .preprocessor),
            HighlightRule(pattern: "<!\\w+[^>]*>", tokenType: .preprocessor),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "</? *[\\w:.-]+", tokenType: .tag),
            HighlightRule(pattern: "/?>", tokenType: .tag),
            HighlightRule(pattern: "\\b[\\w:.-]+=", tokenType: .attribute),
            HighlightRule(pattern: "&\\w+;", tokenType: .keyword),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Markdown

    public static let markdown = LanguageDefinition(
        id: "markdown",
        displayName: "Markdown",
        fileExtensions: ["md", "markdown", "mdown", "mkdn"],
        lineComment: nil,
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "```[\\s\\S]*?```", tokenType: .string),
            HighlightRule(pattern: "`[^`\\n]+`", tokenType: .string),
            HighlightRule(pattern: "^#{1,6}\\s+.*$", tokenType: .keyword),
            HighlightRule(pattern: "\\*\\*[^*]+\\*\\*", tokenType: .keyword),
            HighlightRule(pattern: "__[^_]+__", tokenType: .keyword),
            HighlightRule(pattern: "\\*[^*]+\\*", tokenType: .attribute),
            HighlightRule(pattern: "_[^_]+_", tokenType: .attribute),
            HighlightRule(pattern: "!?\\[[^\\]]*\\]\\([^)]*\\)", tokenType: .function),
            HighlightRule(pattern: "^\\s*[-*+]\\s", tokenType: .`operator`),
            HighlightRule(pattern: "^\\s*\\d+\\.\\s", tokenType: .`operator`),
            HighlightRule(pattern: "^>+\\s?", tokenType: .comment),
            HighlightRule(pattern: "^---+$", tokenType: .comment),
        ]
    )

    // MARK: - C

    public static let c = LanguageDefinition(
        id: "c",
        displayName: "C",
        fileExtensions: ["c", "h"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "#\\s*(?:include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma|error|warning|line)\\b.*", tokenType: .preprocessor),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "auto", "break", "case", "char", "const", "continue", "default", "do",
                "double", "else", "enum", "extern", "float", "for", "goto", "if",
                "inline", "int", "long", "register", "restrict", "return", "short",
                "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
                "unsigned", "void", "volatile", "while", "_Alignas", "_Alignof",
                "_Atomic", "_Bool", "_Complex", "_Generic", "_Imaginary",
                "_Noreturn", "_Static_assert", "_Thread_local", "NULL",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "int", "char", "float", "double", "void", "long", "short",
                "unsigned", "signed", "size_t", "ssize_t", "ptrdiff_t",
                "int8_t", "int16_t", "int32_t", "int64_t",
                "uint8_t", "uint16_t", "uint32_t", "uint64_t",
                "bool", "FILE",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - C++

    public static let cpp = LanguageDefinition(
        id: "cpp",
        displayName: "C++",
        fileExtensions: ["cpp", "cxx", "cc", "c++", "hpp", "hxx", "hh", "h++"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "#\\s*(?:include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma|error|warning|line)\\b.*", tokenType: .preprocessor),
            HighlightRule(pattern: "R\"\\.?\\([\\s\\S]*?\\)\\.?\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor",
                "bool", "break", "case", "catch", "char", "char8_t", "char16_t", "char32_t",
                "class", "compl", "concept", "const", "consteval", "constexpr", "constinit",
                "const_cast", "continue", "co_await", "co_return", "co_yield", "decltype",
                "default", "delete", "do", "double", "dynamic_cast", "else", "enum",
                "explicit", "export", "extern", "false", "float", "for", "friend", "goto",
                "if", "inline", "int", "long", "mutable", "namespace", "new", "noexcept",
                "not", "not_eq", "nullptr", "operator", "or", "or_eq", "private",
                "protected", "public", "register", "reinterpret_cast", "requires", "return",
                "short", "signed", "sizeof", "static", "static_assert", "static_cast",
                "struct", "switch", "template", "this", "thread_local", "throw", "true",
                "try", "typedef", "typeid", "typename", "union", "unsigned", "using",
                "virtual", "void", "volatile", "wchar_t", "while", "xor", "xor_eq",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "string", "vector", "map", "set", "unordered_map", "unordered_set",
                "list", "deque", "array", "pair", "tuple", "optional", "variant",
                "shared_ptr", "unique_ptr", "weak_ptr", "size_t",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Java

    public static let java = LanguageDefinition(
        id: "java",
        displayName: "Java",
        fileExtensions: ["java"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
                "class", "const", "continue", "default", "do", "double", "else", "enum",
                "extends", "false", "final", "finally", "float", "for", "goto", "if",
                "implements", "import", "instanceof", "int", "interface", "long", "native",
                "new", "null", "package", "private", "protected", "public", "return",
                "short", "static", "strictfp", "super", "switch", "synchronized", "this",
                "throw", "throws", "transient", "true", "try", "var", "void", "volatile",
                "while", "yield", "sealed", "permits", "record", "non-sealed",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "String", "Integer", "Long", "Double", "Float", "Boolean", "Character",
                "Byte", "Short", "Object", "Class", "System", "List", "ArrayList",
                "Map", "HashMap", "Set", "HashSet", "Optional", "Stream",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Ruby

    public static let ruby = LanguageDefinition(
        id: "ruby",
        displayName: "Ruby",
        fileExtensions: ["rb", "rake", "gemspec", "ru"],
        lineComment: "#",
        blockCommentStart: "=begin",
        blockCommentEnd: "=end",
        rules: [
            HighlightRule(pattern: "=begin[\\s\\S]*?=end", tokenType: .comment),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "%[qQwWiIrxs]?[{(<\\[].*?[})>\\]]", tokenType: .string),
            HighlightRule(pattern: "/(?:[^/\\\\]|\\\\.)+/[imxo]*", tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "alias", "and", "begin", "break", "case", "class", "def", "defined?",
                "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in",
                "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
                "return", "self", "super", "then", "true", "undef", "unless", "until",
                "when", "while", "yield", "__FILE__", "__LINE__", "__ENCODING__",
                "BEGIN", "END", "attr_accessor", "attr_reader", "attr_writer",
                "include", "extend", "prepend", "require", "require_relative",
                "raise", "puts", "print", "p",
            ]), tokenType: .keyword),
            HighlightRule(pattern: ":[a-zA-Z_]\\w*", tokenType: .attribute),
            HighlightRule(pattern: "@{1,2}\\w+", tokenType: .variable),
            HighlightRule(pattern: "\\$\\w+", tokenType: .variable),
            HighlightRule(pattern: "\\b[A-Z]\\w*\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Go

    public static let go = LanguageDefinition(
        id: "go",
        displayName: "Go",
        fileExtensions: ["go"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "`[^`]*`", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "break", "case", "chan", "const", "continue", "default", "defer",
                "else", "fallthrough", "for", "func", "go", "goto", "if", "import",
                "interface", "map", "package", "range", "return", "select", "struct",
                "switch", "type", "var", "true", "false", "nil", "iota",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "bool", "byte", "complex64", "complex128", "error", "float32", "float64",
                "int", "int8", "int16", "int32", "int64", "rune", "string",
                "uint", "uint8", "uint16", "uint32", "uint64", "uintptr",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Rust

    public static let rust = LanguageDefinition(
        id: "rust",
        displayName: "Rust",
        fileExtensions: ["rs"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: "///.*", tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "r#*\"[\\s\\S]*?\"#*", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "as", "async", "await", "break", "const", "continue", "crate", "dyn",
                "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
                "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
                "self", "Self", "static", "struct", "super", "trait", "true", "type",
                "unsafe", "use", "where", "while", "yield", "abstract", "become",
                "box", "do", "final", "macro", "override", "priv", "try", "typeof",
                "unsized", "virtual",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "bool", "char", "f32", "f64", "i8", "i16", "i32", "i64", "i128",
                "isize", "str", "u8", "u16", "u32", "u64", "u128", "usize",
                "String", "Vec", "Box", "Rc", "Arc", "Cell", "RefCell",
                "Option", "Result", "HashMap", "HashSet", "BTreeMap", "BTreeSet",
            ]), tokenType: .type),
            HighlightRule(pattern: "#!?\\[.*?\\]", tokenType: .attribute),
            HighlightRule(pattern: "\\w+!", tokenType: .preprocessor),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - SQL

    public static let sql = LanguageDefinition(
        id: "sql",
        displayName: "SQL",
        fileExtensions: ["sql", "ddl", "dml"],
        lineComment: "--",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: "--.*", tokenType: .comment),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?i:SELECT|FROM|WHERE|INSERT|INTO|UPDATE|SET|DELETE|CREATE|ALTER|DROP|TABLE|INDEX|VIEW|DATABASE|SCHEMA|JOIN|INNER|LEFT|RIGHT|OUTER|FULL|CROSS|ON|AS|AND|OR|NOT|IN|EXISTS|BETWEEN|LIKE|IS|NULL|TRUE|FALSE|ORDER|BY|GROUP|HAVING|LIMIT|OFFSET|UNION|ALL|DISTINCT|CASE|WHEN|THEN|ELSE|END|BEGIN|COMMIT|ROLLBACK|TRANSACTION|PRIMARY|KEY|FOREIGN|REFERENCES|UNIQUE|CHECK|DEFAULT|CONSTRAINT|CASCADE|GRANT|REVOKE|WITH|VALUES|COUNT|SUM|AVG|MIN|MAX|DECLARE|CURSOR|FETCH|IF|WHILE|RETURN|TRIGGER|PROCEDURE|FUNCTION|ASC|DESC)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\b(?i:INT|INTEGER|BIGINT|SMALLINT|TINYINT|FLOAT|DOUBLE|DECIMAL|NUMERIC|REAL|CHAR|VARCHAR|TEXT|BLOB|DATE|TIME|TIMESTAMP|DATETIME|BOOLEAN|SERIAL|UUID|JSON|JSONB|XML|BINARY|VARBINARY|CLOB|NCHAR|NVARCHAR|BIT)\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Shell / Bash

    public static let shellBash = LanguageDefinition(
        id: "shell",
        displayName: "Shell",
        fileExtensions: ["sh", "bash", "zsh", "fish", "ksh"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\$\\{[^}]*\\}", tokenType: .variable),
            HighlightRule(pattern: "\\$\\([^)]*\\)", tokenType: .variable),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "\\$[0-9#?!@*$-]", tokenType: .variable),
            HighlightRule(pattern: keywordPattern([
                "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done",
                "case", "esac", "in", "function", "select", "time", "coproc",
                "break", "continue", "return", "exit",
                "echo", "printf", "read", "declare", "local", "export", "unset",
                "set", "shift", "trap", "eval", "exec", "source", "alias", "unalias",
                "test", "true", "false",
                "cd", "pwd", "pushd", "popd", "dirs",
                "let", "readonly", "typeset", "getopts",
            ]), tokenType: .keyword),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - YAML

    public static let yaml = LanguageDefinition(
        id: "yaml",
        displayName: "YAML",
        fileExtensions: ["yml", "yaml"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?:true|false|yes|no|on|off|null|~)\\b", tokenType: .keyword),
            HighlightRule(pattern: "---", tokenType: .keyword),
            HighlightRule(pattern: "\\.\\.\\.", tokenType: .keyword),
            HighlightRule(pattern: "[\\w.-]+(?=\\s*:)", tokenType: .attribute),
            HighlightRule(pattern: "&\\w+", tokenType: .variable),
            HighlightRule(pattern: "\\*\\w+", tokenType: .variable),
            HighlightRule(pattern: "<<", tokenType: .variable),
            HighlightRule(pattern: "!\\S+", tokenType: .type),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "[|>][+-]?", tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - TOML

    public static let toml = LanguageDefinition(
        id: "toml",
        displayName: "TOML",
        fileExtensions: ["toml"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?:true|false)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\[\\[?[\\w.\"'-]+\\]\\]?", tokenType: .tag),
            HighlightRule(pattern: "[\\w.-]+(?=\\s*=)", tokenType: .attribute),
            HighlightRule(pattern: "\\d{4}-\\d{2}-\\d{2}(?:[T ]\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?(?:Z|[+-]\\d{2}:\\d{2})?)?", tokenType: .number),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - PHP

    public static let php = LanguageDefinition(
        id: "php",
        displayName: "PHP",
        fileExtensions: ["php", "phtml"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "<<<'?\\w+'?[\\s\\S]*?^\\w+;?$", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "and", "array", "as", "break", "callable", "case", "catch",
                "class", "clone", "const", "continue", "declare", "default", "do", "echo",
                "else", "elseif", "empty", "enddeclare", "endfor", "endforeach", "endif",
                "endswitch", "endwhile", "enum", "extends", "false", "final", "finally",
                "fn", "for", "foreach", "function", "global", "goto", "if", "implements",
                "include", "include_once", "instanceof", "insteadof", "interface", "isset",
                "list", "match", "namespace", "new", "null", "or", "print", "private",
                "protected", "public", "readonly", "require", "require_once", "return",
                "static", "switch", "throw", "trait", "true", "try", "unset", "use",
                "var", "while", "xor", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "string", "int", "float", "bool", "array", "object", "null", "void",
                "mixed", "never", "iterable", "self", "parent",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Kotlin

    public static let kotlin = LanguageDefinition(
        id: "kotlin",
        displayName: "Kotlin",
        fileExtensions: ["kt", "kts"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "actual", "annotation", "as", "break", "by", "catch", "class",
                "companion", "const", "constructor", "continue", "crossinline", "data",
                "delegate", "do", "else", "enum", "expect", "external", "false", "final",
                "finally", "for", "fun", "get", "if", "import", "in", "infix", "init",
                "inline", "inner", "interface", "internal", "is", "it", "lateinit", "noinline",
                "null", "object", "open", "operator", "out", "override", "package", "private",
                "protected", "public", "reified", "return", "sealed", "set", "super",
                "suspend", "tailrec", "this", "throw", "true", "try", "typealias", "val",
                "var", "vararg", "when", "where", "while",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "Any", "Boolean", "Byte", "Char", "Double", "Float", "Int", "List", "Long",
                "Map", "Nothing", "Number", "Pair", "Set", "Short", "String", "Triple",
                "Unit",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Perl

    public static let perl = LanguageDefinition(
        id: "perl",
        displayName: "Perl",
        fileExtensions: ["pl", "pm", "t"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "^=\\w+[\\s\\S]*?^=cut\\b", tokenType: .comment),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "/(?:[^/\\\\]|\\\\.)+/[imxsgce]*", tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "chomp", "chop", "die", "do", "dump", "else", "elsif", "eval", "for",
                "foreach", "goto", "if", "import", "last", "local", "my", "next", "no",
                "our", "package", "print", "redo", "require", "return", "say", "sub",
                "undef", "unless", "until", "use", "while",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "@[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "%[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Lua

    public static let lua = LanguageDefinition(
        id: "lua",
        displayName: "Lua",
        fileExtensions: ["lua"],
        lineComment: "--",
        blockCommentStart: "--[[",
        blockCommentEnd: "]]",
        rules: [
            HighlightRule(pattern: "--\\[\\[[\\s\\S]*?\\]\\]", tokenType: .comment),
            HighlightRule(pattern: "--.*", tokenType: .comment),
            HighlightRule(pattern: "\\[\\[[\\s\\S]*?\\]\\]", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "and", "break", "do", "else", "elseif", "end", "false", "for",
                "function", "goto", "if", "in", "local", "nil", "not", "or",
                "repeat", "return", "then", "true", "until", "while",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "table", "string", "number", "boolean", "thread", "userdata",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - R

    public static let r = LanguageDefinition(
        id: "r",
        displayName: "R",
        fileExtensions: ["r", "R", "rmd"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "break", "else", "for", "function", "if", "in", "next", "repeat",
                "return", "while", "TRUE", "FALSE", "NULL", "NA", "NA_integer_",
                "NA_real_", "NA_complex_", "NA_character_", "Inf", "NaN", "library",
                "require", "source", "switch",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "character", "complex", "double", "integer", "list", "logical",
                "numeric", "raw", "vector", "data\\.frame", "matrix", "factor",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "<-|->|<<-|->>", tokenType: .`operator`),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Dart

    public static let dart = LanguageDefinition(
        id: "dart",
        displayName: "Dart",
        fileExtensions: ["dart"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: "///.*", tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "as", "assert", "async", "await", "break", "case", "catch",
                "class", "const", "continue", "covariant", "default", "deferred", "do",
                "dynamic", "else", "enum", "export", "extends", "extension", "external",
                "factory", "false", "final", "finally", "for", "get", "if", "implements",
                "import", "in", "is", "late", "library", "mixin", "new", "null", "on",
                "operator", "part", "required", "return", "sealed", "set", "show", "static",
                "super", "switch", "sync", "this", "throw", "true", "try", "typedef",
                "var", "void", "when", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "bool", "double", "dynamic", "int", "num", "String", "List", "Map",
                "Set", "Future", "Stream", "Iterable", "Object", "void",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Objective-C

    public static let objc = LanguageDefinition(
        id: "objc",
        displayName: "Objective-C",
        fileExtensions: ["m", "mm"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "#\\s*(?:import|include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma|error|warning|line)\\b.*", tokenType: .preprocessor),
            HighlightRule(pattern: "@\(doubleQuotedString)", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "@interface", "@implementation", "@end", "@protocol", "@property",
                "@synthesize", "@dynamic", "@selector", "@class", "@public", "@private",
                "@protected", "@optional", "@required", "@autoreleasepool", "@try",
                "@catch", "@finally", "@throw", "@synchronized",
                "break", "case", "continue", "default", "do", "else", "enum", "extern",
                "for", "goto", "if", "return", "self", "sizeof", "static", "struct",
                "super", "switch", "typedef", "union", "volatile", "while",
                "nil", "Nil", "YES", "NO", "true", "false", "NULL",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "BOOL", "CGFloat", "CGPoint", "CGRect", "CGSize", "Class", "IBAction",
                "IBOutlet", "NSArray", "NSDictionary", "NSInteger", "NSNumber",
                "NSObject", "NSString", "NSUInteger", "SEL", "id", "instancetype",
                "int", "long", "short", "unsigned", "void",
            ]), tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Scala

    public static let scala = LanguageDefinition(
        id: "scala",
        displayName: "Scala",
        fileExtensions: ["scala", "sc"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "case", "catch", "class", "def", "do", "else", "extends",
                "false", "final", "finally", "for", "forSome", "if", "implicit",
                "import", "lazy", "match", "new", "null", "object", "override",
                "package", "private", "protected", "return", "sealed", "super", "this",
                "throw", "trait", "true", "try", "type", "val", "var", "while", "with",
                "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "Any", "AnyRef", "AnyVal", "Boolean", "Byte", "Char", "Double", "Float",
                "Int", "List", "Long", "Map", "Nothing", "Null", "Option", "Seq", "Set",
                "Short", "String", "Unit", "Vector",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Diff

    public static let diff = LanguageDefinition(
        id: "diff",
        displayName: "Diff",
        fileExtensions: ["diff", "patch"],
        lineComment: nil,
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "^---\\s.*$", tokenType: .type),
            HighlightRule(pattern: "^\\+\\+\\+\\s.*$", tokenType: .type),
            HighlightRule(pattern: "^@@[^@]*@@.*$", tokenType: .keyword),
            HighlightRule(pattern: "^\\+.*$", tokenType: .string),
            HighlightRule(pattern: "^-.*$", tokenType: .comment),
            HighlightRule(pattern: "^diff\\s.*$", tokenType: .keyword),
            HighlightRule(pattern: "^index\\s.*$", tokenType: .attribute),
        ]
    )

    // MARK: - Makefile

    public static let makefile = LanguageDefinition(
        id: "makefile",
        displayName: "Makefile",
        fileExtensions: ["makefile", "mk", "Makefile"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\$\\([^)]*\\)", tokenType: .variable),
            HighlightRule(pattern: "\\$\\{[^}]*\\}", tokenType: .variable),
            HighlightRule(pattern: "\\$[@<^+?*%]", tokenType: .variable),
            HighlightRule(pattern: keywordPattern([
                "define", "endef", "ifdef", "ifndef", "ifeq", "ifneq", "else", "endif",
                "include", "override", "export", "unexport", "vpath",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "^\\.(?:PHONY|DEFAULT|PRECIOUS|INTERMEDIATE|SECONDARY|SUFFIXES|DELETE_ON_ERROR|IGNORE|SILENT|EXPORT_ALL_VARIABLES|NOTPARALLEL|ONESHELL|POSIX)\\b", tokenType: .keyword),
            HighlightRule(pattern: "^[a-zA-Z_][\\w.-]*\\s*:", tokenType: .function),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // =========================================================================
    // MARK: - Batch 2
    // =========================================================================

    // MARK: - PowerShell

    public static let powershell = LanguageDefinition(
        id: "powershell",
        displayName: "PowerShell",
        fileExtensions: ["ps1", "psm1", "psd1"],
        lineComment: "#",
        blockCommentStart: "<#",
        blockCommentEnd: "#>",
        rules: [
            HighlightRule(pattern: "<#[\\s\\S]*?#>", tokenType: .comment),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "@\(doubleQuotedString)", tokenType: .string),
            HighlightRule(pattern: "@\(singleQuotedString)", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "function", "param", "if", "else", "elseif", "foreach", "for", "while",
                "do", "switch", "try", "catch", "finally", "throw", "return", "break",
                "continue", "begin", "process", "end", "class", "enum", "using",
                "namespace", "import", "export", "filter", "in", "trap", "exit",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "\\$(?:true|false|null)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "@[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "-[a-zA-Z]+\\b", tokenType: .attribute),
            HighlightRule(pattern: "\\[\\w+(?:\\.\\w+)*\\]", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Dockerfile

    public static let dockerfile = LanguageDefinition(
        id: "dockerfile",
        displayName: "Dockerfile",
        fileExtensions: ["dockerfile", "Dockerfile"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "^(?:FROM|RUN|CMD|EXPOSE|ENV|ADD|COPY|ENTRYPOINT|VOLUME|USER|WORKDIR|ARG|LABEL|MAINTAINER|ONBUILD|STOPSIGNAL|HEALTHCHECK|SHELL)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\$\\{[^}]*\\}", tokenType: .variable),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: "--[a-zA-Z][\\w-]*", tokenType: .attribute),
            HighlightRule(pattern: "\\b[a-zA-Z_][\\w.-]*/[a-zA-Z_][\\w.-]*(?::[\\w.-]+)?\\b", tokenType: .type),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - INI

    public static let ini = LanguageDefinition(
        id: "ini",
        displayName: "INI",
        fileExtensions: ["ini", "cfg", "conf"],
        lineComment: ";",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "[;#].*", tokenType: .comment),
            HighlightRule(pattern: "^\\s*\\[[^\\]]*\\]", tokenType: .keyword),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "^\\s*[\\w.-]+(?=\\s*=)", tokenType: .variable),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "\\b(?:true|false|yes|no|on|off)\\b", tokenType: .keyword),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Properties

    public static let properties = LanguageDefinition(
        id: "properties",
        displayName: "Properties",
        fileExtensions: ["properties"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "[#!].*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "^\\s*[\\w.-]+(?=\\s*[=:])", tokenType: .variable),
            HighlightRule(pattern: "\\\\$", tokenType: .`operator`),
            HighlightRule(pattern: "\\\\[tnru\\\\]", tokenType: .keyword),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - LaTeX

    public static let latex = LanguageDefinition(
        id: "latex",
        displayName: "LaTeX",
        fileExtensions: ["tex", "latex", "sty", "cls"],
        lineComment: "%",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "%.*", tokenType: .comment),
            HighlightRule(pattern: "\\$\\$[\\s\\S]*?\\$\\$", tokenType: .string),
            HighlightRule(pattern: "\\$[^$]*?\\$", tokenType: .string),
            HighlightRule(pattern: "\\\\(?:begin|end|section|subsection|subsubsection|paragraph|chapter|part|title|author|date|maketitle|tableofcontents|usepackage|documentclass|newcommand|renewcommand|include|input|bibliography|bibliographystyle|label|ref|cite|footnote|caption|textbf|textit|emph|underline|item)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\\\[a-zA-Z@]+\\*?", tokenType: .function),
            HighlightRule(pattern: "\\{[^}]*\\}", tokenType: .string),
            HighlightRule(pattern: "\\[[^\\]]*\\]", tokenType: .attribute),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "[&~^_]", tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Haskell

    public static let haskell = LanguageDefinition(
        id: "haskell",
        displayName: "Haskell",
        fileExtensions: ["hs", "lhs"],
        lineComment: "--",
        blockCommentStart: "{-",
        blockCommentEnd: "-}",
        rules: [
            HighlightRule(pattern: "\\{-[\\s\\S]*?-\\}", tokenType: .comment),
            HighlightRule(pattern: "--.*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "module", "where", "import", "qualified", "as", "hiding", "data", "type",
                "newtype", "class", "instance", "deriving", "if", "then", "else", "case",
                "of", "let", "in", "do", "where", "infixl", "infixr", "infix", "forall",
                "foreign", "default", "pattern",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "Int", "Integer", "Float", "Double", "Char", "String", "Bool", "IO",
                "Maybe", "Either", "Ordering", "Show", "Eq", "Ord", "Num", "Functor",
                "Applicative", "Monad", "Monoid", "Semigroup",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\b[A-Z][a-zA-Z0-9_']*\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "[-+*/<>=!&|.:\\\\@~?$%^]+", tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Elixir

    public static let elixir = LanguageDefinition(
        id: "elixir",
        displayName: "Elixir",
        fileExtensions: ["ex", "exs"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            HighlightRule(pattern: "~[rRsSwWcC](?:\"[^\"]*\"|'[^']*'|\\([^)]*\\)|\\[[^\\]]*\\]|\\{[^}]*\\}|<[^>]*>|/[^/]*/|\\|[^|]*\\|)", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "def", "defp", "defmodule", "defmacro", "defmacrop", "defprotocol",
                "defimpl", "defstruct", "defguard", "defdelegate", "defoverridable",
                "defexception", "do", "end", "if", "else", "unless", "case", "cond",
                "fn", "with", "for", "raise", "rescue", "try", "catch", "after",
                "receive", "send", "spawn", "import", "use", "alias", "require",
                "when", "and", "or", "not", "in", "true", "false", "nil",
            ]), tokenType: .keyword),
            HighlightRule(pattern: ":[a-zA-Z_]\\w*[!?]?", tokenType: .attribute),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: "&\\d+", tokenType: .variable),
            HighlightRule(pattern: "\\b[A-Z][a-zA-Z0-9_.]*\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "\\|>|<>|<~>|~>|<~|\\+\\+|--|\\.\\.|\\.\\.\\.|\\\\\\\\/", tokenType: .`operator`),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Groovy

    public static let groovy = LanguageDefinition(
        id: "groovy",
        displayName: "Groovy",
        fileExtensions: ["groovy", "gradle", "gvy"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "'''[\\s\\S]*?'''", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "/(?:[^/\\\\]|\\\\.)+/", tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "as", "assert", "boolean", "break", "byte", "case", "catch",
                "char", "class", "continue", "def", "default", "do", "double", "else",
                "enum", "extends", "false", "final", "finally", "float", "for", "goto",
                "if", "implements", "import", "in", "instanceof", "int", "interface",
                "long", "native", "new", "null", "package", "private", "protected",
                "public", "return", "short", "static", "strictfp", "super", "switch",
                "synchronized", "this", "throw", "throws", "trait", "transient", "true",
                "try", "void", "volatile", "while",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "String", "Integer", "Long", "Double", "Float", "Boolean", "List",
                "Map", "Set", "Object", "BigDecimal", "BigInteger", "Closure",
            ]), tokenType: .type),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: "\\$\\{[^}]*\\}", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Pascal

    public static let pascal = LanguageDefinition(
        id: "pascal",
        displayName: "Pascal",
        fileExtensions: ["pas", "pp", "dpr"],
        lineComment: "//",
        blockCommentStart: "{",
        blockCommentEnd: "}",
        rules: [
            HighlightRule(pattern: "\\{[\\s\\S]*?\\}", tokenType: .comment),
            HighlightRule(pattern: "\\(\\*[\\s\\S]*?\\*\\)", tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "#\\d+", tokenType: .string),
            HighlightRule(pattern: "\\b(?i:program|unit|uses|var|const|type|begin|end|procedure|function|if|then|else|for|to|downto|while|repeat|until|do|case|of|with|record|class|interface|implementation|initialization|finalization|try|except|finally|raise|inherited|constructor|destructor|property|set|array|file|string|nil|true|false|and|or|not|xor|div|mod|shl|shr|in|is|as)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\b(?i:Integer|LongInt|ShortInt|SmallInt|Int64|Byte|Word|Cardinal|Boolean|Char|String|Real|Single|Double|Extended|Currency|Variant|Pointer|TObject|TComponent|TForm)\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "\\$[0-9a-fA-F]+", tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Assembly

    public static let assembly = LanguageDefinition(
        id: "assembly",
        displayName: "Assembly",
        fileExtensions: ["asm", "s", "S"],
        lineComment: ";",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: ";.*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?i:mov|movzx|movsx|lea|push|pop|call|ret|jmp|je|jne|jz|jnz|jg|jge|jl|jle|ja|jae|jb|jbe|cmp|test|add|sub|mul|imul|div|idiv|inc|dec|and|or|xor|not|shl|shr|sar|sal|rol|ror|neg|nop|int|syscall|sysenter|loop|rep|repe|repne|enter|leave|hlt|clc|stc|cld|std|cbw|cwd|cdq)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\b(?i:section|segment|global|extern|bits|org|align|default|equ|db|dw|dd|dq|dt|do|dy|dz|resb|resw|resd|resq|rest|reso|resy|resz|incbin|times|macro|endmacro|struc|endstruc)\\b", tokenType: .preprocessor),
            HighlightRule(pattern: "\\b(?i:eax|ebx|ecx|edx|esi|edi|ebp|esp|rax|rbx|rcx|rdx|rsi|rdi|rbp|rsp|r8|r9|r10|r11|r12|r13|r14|r15|al|bl|cl|dl|ah|bh|ch|dh|ax|bx|cx|dx|si|di|bp|sp|cs|ds|es|fs|gs|ss|xmm[0-9]|ymm[0-9]|zmm[0-9])\\b", tokenType: .variable),
            HighlightRule(pattern: "^\\s*[a-zA-Z_.][a-zA-Z0-9_]*:", tokenType: .function),
            HighlightRule(pattern: "\\b0[xX][0-9a-fA-F]+\\b", tokenType: .number),
            HighlightRule(pattern: "\\b0[bB][01]+\\b", tokenType: .number),
            HighlightRule(pattern: "\\b[0-9]+\\b", tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // =========================================================================
    // MARK: - Batch 3
    // =========================================================================

    // MARK: - Fortran

    public static let fortran = LanguageDefinition(
        id: "fortran",
        displayName: "Fortran",
        fileExtensions: ["f90", "f95", "f03", "f08", "f"],
        lineComment: "!",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "!.*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\b(?i:program|end|subroutine|function|module|use|implicit|none|integer|real|double|precision|complex|character|logical|if|then|else|elseif|endif|do|while|enddo|call|return|write|read|print|format|open|close|allocate|deallocate|allocatable|dimension|parameter|intent|in|out|inout|interface|contains|type|class|select|case|default|exit|cycle|stop|go|to|where|elsewhere|endwhere|forall|associate|block|data|common|equivalence|save|external|intrinsic|recursive|pure|elemental|result|only|operator|assignment|pointer|target|optional|value|protected|abstract|extends|generic|non_overridable|deferred|final|enum|enumerator|procedure|pass|nopass)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\b(?i:INTEGER|REAL|DOUBLE|COMPLEX|CHARACTER|LOGICAL|TYPE)\\b", tokenType: .type),
            HighlightRule(pattern: "\\.(?:eq|ne|lt|gt|le|ge|and|or|not|eqv|neqv|true|false)\\.", tokenType: .keyword),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Erlang

    public static let erlang = LanguageDefinition(
        id: "erlang",
        displayName: "Erlang",
        fileExtensions: ["erl", "hrl"],
        lineComment: "%",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "%.*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "-(?:module|export|import|record|define|include|include_lib|ifdef|ifndef|else|endif|undef|type|spec|callback|behaviour|behavior|opaque|export_type)\\b", tokenType: .preprocessor),
            HighlightRule(pattern: keywordPattern([
                "after", "begin", "case", "catch", "cond", "end", "fun", "if", "let",
                "of", "receive", "try", "when", "query", "not", "and", "or", "xor",
                "band", "bor", "bxor", "bsl", "bsr", "bnot", "div", "rem",
                "true", "false", "undefined",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "\\?[a-zA-Z_]\\w*", tokenType: .preprocessor),
            HighlightRule(pattern: "\\b[a-z][a-zA-Z0-9_]*(?=\\s*\\()", tokenType: .function),
            HighlightRule(pattern: "\\b[A-Z_][a-zA-Z0-9_]*\\b", tokenType: .variable),
            HighlightRule(pattern: "\\b[a-z][a-zA-Z0-9_]*\\b", tokenType: .attribute),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "->|<-|=>|:=|\\|\\||!!|\\+\\+|--", tokenType: .`operator`),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Clojure

    public static let clojure = LanguageDefinition(
        id: "clojure",
        displayName: "Clojure",
        fileExtensions: ["clj", "cljs", "cljc", "edn"],
        lineComment: ";",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: ";.*", tokenType: .comment),
            HighlightRule(pattern: "#!.*", tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: "#\(doubleQuotedString)", tokenType: .string),
            HighlightRule(pattern: "\\b(?:def|defn|defn-|defmacro|defmethod|defmulti|defonce|defprotocol|defrecord|defstruct|deftype|let|fn|if|do|when|cond|case|loop|recur|for|doseq|dotimes|ns|require|use|import|refer|in-ns|try|catch|finally|throw|monitor-enter|monitor-exit|new|set!|quote|var|binding|with-local-vars|with-open|with-redefs|delay|force|lazy-seq|reify|proxy|extend-type|extend-protocol)\\b", tokenType: .keyword),
            HighlightRule(pattern: "\\b(?:nil|true|false)\\b", tokenType: .keyword),
            HighlightRule(pattern: ":[a-zA-Z_][a-zA-Z0-9_.*+!-?/]*", tokenType: .attribute),
            HighlightRule(pattern: "#'[a-zA-Z_][a-zA-Z0-9_.*+!-?/]*", tokenType: .variable),
            HighlightRule(pattern: "\\^[a-zA-Z_]\\w*", tokenType: .type),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "\\b\\d+/\\d+\\b", tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - F#

    public static let fsharp = LanguageDefinition(
        id: "fsharp",
        displayName: "F#",
        fileExtensions: ["fs", "fsx", "fsi"],
        lineComment: "//",
        blockCommentStart: "(*",
        blockCommentEnd: "*)",
        rules: [
            HighlightRule(pattern: "\\(\\*[\\s\\S]*?\\*\\)", tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: "@\(doubleQuotedString)", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "abstract", "and", "as", "assert", "base", "begin", "class", "default",
                "delegate", "do", "done", "downcast", "downto", "elif", "else", "end",
                "exception", "extern", "false", "finally", "for", "fun", "function",
                "global", "if", "in", "inherit", "inline", "interface", "internal",
                "lazy", "let", "match", "member", "module", "mutable", "namespace",
                "new", "not", "null", "of", "open", "or", "override", "private",
                "public", "rec", "return", "sig", "static", "struct", "then", "to",
                "true", "try", "type", "upcast", "use", "val", "void", "when",
                "while", "with", "yield", "async", "do!", "let!", "match!", "return!",
                "use!", "yield!",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "int", "float", "double", "string", "bool", "char", "byte", "unit",
                "decimal", "int64", "uint64", "int16", "uint16", "sbyte", "single",
                "nativeint", "unativeint", "bigint", "obj", "exn",
                "seq", "list", "array", "option", "Result", "Map", "Set",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\[<[^>]*>\\]", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: "\\|>|<\\||>>|<<|:>|:\\?>|::", tokenType: .`operator`),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Nim

    public static let nim = LanguageDefinition(
        id: "nim",
        displayName: "Nim",
        fileExtensions: ["nim", "nims", "nimble"],
        lineComment: "#",
        blockCommentStart: "#[",
        blockCommentEnd: "]#",
        rules: [
            HighlightRule(pattern: "#\\[[\\s\\S]*?\\]#", tokenType: .comment),
            HighlightRule(pattern: "##.*", tokenType: .comment),
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "addr", "and", "as", "asm", "bind", "block", "break", "case", "cast",
                "concept", "const", "continue", "converter", "defer", "discard", "distinct",
                "div", "do", "elif", "else", "end", "enum", "except", "export", "finally",
                "for", "from", "func", "if", "import", "in", "include", "interface",
                "is", "isnot", "iterator", "let", "macro", "method", "mixin", "mod",
                "nil", "not", "notin", "object", "of", "or", "out", "proc", "ptr",
                "raise", "ref", "return", "shl", "shr", "static", "template", "try",
                "tuple", "type", "using", "var", "when", "while", "xor", "yield",
                "true", "false",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16",
                "uint32", "uint64", "float", "float32", "float64", "bool", "char",
                "string", "cstring", "pointer", "typedesc", "void", "auto", "any",
                "seq", "array", "openArray", "set", "Table", "OrderedTable",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\{\\.[^}]*\\.?\\}", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Zig

    public static let zig = LanguageDefinition(
        id: "zig",
        displayName: "Zig",
        fileExtensions: ["zig"],
        lineComment: "//",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: "///.*", tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\\\\\\\[^\\n]*", tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "addrspace", "align", "allowzero", "and", "anyframe", "anytype", "asm",
                "async", "await", "break", "catch", "comptime", "const", "continue",
                "defer", "else", "enum", "errdefer", "error", "export", "extern",
                "fn", "for", "if", "inline", "linksection", "noalias", "nosuspend",
                "opaque", "or", "orelse", "packed", "pub", "resume", "return",
                "struct", "suspend", "switch", "test", "threadlocal", "try",
                "undefined", "union", "unreachable", "var", "volatile", "while",
                "true", "false", "null",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "bool", "f16", "f32", "f64", "f80", "f128", "c_char", "c_short",
                "c_ushort", "c_int", "c_uint", "c_long", "c_ulong", "c_longlong",
                "c_ulonglong", "c_longdouble", "isize", "usize", "comptime_int",
                "comptime_float", "void", "noreturn", "type", "anyerror", "anyopaque",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\b[iu]\\d+\\b", tokenType: .type),
            HighlightRule(pattern: "@[a-zA-Z_]\\w*", tokenType: .attribute),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Svelte

    public static let svelte = LanguageDefinition(
        id: "svelte",
        displayName: "Svelte",
        fileExtensions: ["svelte"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment),
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: templateLiteral, tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: "\\{[#/:](?:if|each|await|then|catch|else|key|html|debug|const|snippet|render)\\b", tokenType: .keyword),
            HighlightRule(pattern: keywordPattern([
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends",
                "false", "finally", "for", "from", "function", "if", "import", "in",
                "instanceof", "let", "new", "null", "of", "return", "static", "super",
                "switch", "this", "throw", "true", "try", "typeof", "undefined", "var",
                "void", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "</? *\\w+", tokenType: .tag),
            HighlightRule(pattern: "/?>", tokenType: .tag),
            HighlightRule(pattern: "\\b(?:on|bind|class|use|transition|animate|in|out|style):[\\w|]+", tokenType: .attribute),
            HighlightRule(pattern: "\\b[a-zA-Z-]+=", tokenType: .attribute),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Vue

    public static let vue = LanguageDefinition(
        id: "vue",
        displayName: "Vue",
        fileExtensions: ["vue"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: "<!--[\\s\\S]*?-->", tokenType: .comment),
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: templateLiteral, tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "async", "await", "break", "case", "catch", "class", "const", "continue",
                "debugger", "default", "delete", "do", "else", "export", "extends",
                "false", "finally", "for", "from", "function", "if", "import", "in",
                "instanceof", "let", "new", "null", "of", "return", "static", "super",
                "switch", "this", "throw", "true", "try", "typeof", "undefined", "var",
                "void", "while", "with", "yield",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "</? *\\w+", tokenType: .tag),
            HighlightRule(pattern: "/?>", tokenType: .tag),
            HighlightRule(pattern: "(?:v-|@|:|#)[\\w.-]+", tokenType: .attribute),
            HighlightRule(pattern: "\\b[a-zA-Z-]+=", tokenType: .attribute),
            HighlightRule(pattern: "\\$[a-zA-Z_]\\w*", tokenType: .variable),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - GraphQL

    public static let graphql = LanguageDefinition(
        id: "graphql",
        displayName: "GraphQL",
        fileExtensions: ["graphql", "gql"],
        lineComment: "#",
        blockCommentStart: nil,
        blockCommentEnd: nil,
        rules: [
            HighlightRule(pattern: hashComment, tokenType: .comment),
            HighlightRule(pattern: "\"\"\"[\\s\\S]*?\"\"\"", tokenType: .string),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "query", "mutation", "subscription", "fragment", "on", "type", "input",
                "enum", "scalar", "interface", "union", "schema", "extend", "directive",
                "implements", "repeatable",
            ]), tokenType: .keyword),
            HighlightRule(pattern: "\\b(?:true|false|null)\\b", tokenType: .keyword),
            HighlightRule(pattern: "@\\w+", tokenType: .attribute),
            HighlightRule(pattern: "\\$\\w+", tokenType: .variable),
            HighlightRule(pattern: typePattern([
                "Int", "Float", "String", "Boolean", "ID",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )

    // MARK: - Protobuf

    public static let protobuf = LanguageDefinition(
        id: "protobuf",
        displayName: "Protobuf",
        fileExtensions: ["proto"],
        lineComment: "//",
        blockCommentStart: "/*",
        blockCommentEnd: "*/",
        rules: [
            HighlightRule(pattern: cBlockComment, tokenType: .comment),
            HighlightRule(pattern: cLineComment, tokenType: .comment),
            HighlightRule(pattern: doubleQuotedString, tokenType: .string),
            HighlightRule(pattern: singleQuotedString, tokenType: .string),
            HighlightRule(pattern: keywordPattern([
                "syntax", "import", "weak", "public", "package", "option", "message",
                "enum", "service", "rpc", "returns", "stream", "repeated", "optional",
                "required", "map", "oneof", "reserved", "extensions", "extend", "to",
                "max", "group", "true", "false",
            ]), tokenType: .keyword),
            HighlightRule(pattern: typePattern([
                "double", "float", "int32", "int64", "uint32", "uint64", "sint32",
                "sint64", "fixed32", "fixed64", "sfixed32", "sfixed64", "bool",
                "string", "bytes", "any", "empty",
            ]), tokenType: .type),
            HighlightRule(pattern: "\\b[A-Z][a-zA-Z0-9_]*\\b", tokenType: .type),
            HighlightRule(pattern: functionCall, tokenType: .function),
            HighlightRule(pattern: numberLiteral, tokenType: .number),
            HighlightRule(pattern: operators, tokenType: .`operator`),
            HighlightRule(pattern: punctuation, tokenType: .punctuation),
        ]
    )
}
