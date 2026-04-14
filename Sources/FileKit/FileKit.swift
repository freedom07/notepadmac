import Foundation
import TextCore
import CommonKit

/// Convenience facade that bridges ``FileIO`` with ``TextDocument``.
public enum FileKit {

    /// Read a text file from disk, returning content, detected encoding, and
    /// line ending. Delegates to ``FileIO/readFile(at:)``.
    public static func readFile(at url: URL) throws -> (content: String, encoding: String.Encoding) {
        let result = try FileIO.readFile(at: url)
        return (result.content, result.encoding)
    }

    /// Write text content to a file. Delegates to ``FileIO/writeFile(...)``.
    public static func writeFile(
        content: String,
        to url: URL,
        encoding: String.Encoding = .utf8,
        lineEnding: LineEnding = .lf
    ) throws {
        try FileIO.writeFile(content: content, to: url, encoding: encoding, lineEnding: lineEnding)
    }

    /// Create a ``TextDocument`` from a file URL.
    public static func loadDocument(from url: URL) throws -> TextDocument {
        let result = try FileIO.readFile(at: url)
        return TextDocument(
            content: result.content,
            encoding: result.encoding,
            lineEnding: result.lineEnding
        )
    }
}

/// Errors originating from the top-level ``FileKit`` facade.
public enum FileKitError: LocalizedError {
    case encodingFailed
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode file content."
        case .fileNotFound: return "The specified file was not found."
        }
    }
}
