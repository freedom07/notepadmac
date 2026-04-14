// FileIO.swift
// FileKit – NotepadNext
//
// High-level file reading and writing with encoding and line-ending awareness.

import Foundation
import CommonKit

// MARK: - FileInfo

/// Lightweight metadata snapshot for a file on disk.
public struct FileInfo {
    /// Size of the file in bytes.
    public let size: UInt64

    /// Last-modification date.
    public let modificationDate: Date

    /// `true` when the file is not writable by the current process.
    public let isReadOnly: Bool

    /// Detected text encoding.
    public let encoding: String.Encoding

    /// Detected line-ending style.
    public let lineEnding: LineEnding

    public init(
        size: UInt64,
        modificationDate: Date,
        isReadOnly: Bool,
        encoding: String.Encoding,
        lineEnding: LineEnding
    ) {
        self.size = size
        self.modificationDate = modificationDate
        self.isReadOnly = isReadOnly
        self.encoding = encoding
        self.lineEnding = lineEnding
    }
}

// MARK: - FileIO Errors

/// Errors thrown by ``FileIO`` operations.
public enum FileIOError: LocalizedError {
    case unableToReadFile(URL)
    case unableToDecode(URL, String.Encoding)
    case unableToEncode(String.Encoding)
    case fileNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case .unableToReadFile(let url):
            return "Unable to read file at \(url.path)."
        case .unableToDecode(let url, let encoding):
            return "Unable to decode file at \(url.path) using \(EncodingManager.encodingName(encoding))."
        case .unableToEncode(let encoding):
            return "Unable to encode text using \(EncodingManager.encodingName(encoding))."
        case .fileNotFound(let url):
            return "File not found at \(url.path)."
        }
    }
}

// MARK: - FileIO

/// Provides static helpers for reading and writing text files with correct
/// encoding and line-ending handling.
public final class FileIO {

    /// Threshold (in bytes) above which the file is memory-mapped for reading.
    private static let mmapThreshold: UInt64 = 10 * 1024 * 1024 // 10 MB

    // MARK: - Read

    /// Read the text file at `url`, detecting its encoding and line endings.
    ///
    /// Files larger than 10 MB are memory-mapped via
    /// `Data(contentsOf:options:.mappedIfSafe)`.
    ///
    /// - Parameter url: The file URL to read.
    /// - Returns: A tuple of the decoded string content, detected encoding, and
    ///   line-ending style.
    /// - Throws: ``FileIOError`` when the file cannot be read or decoded.
    public static func readFile(at url: URL) throws -> (content: String, encoding: String.Encoding, lineEnding: LineEnding) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileIOError.fileNotFound(url)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? UInt64) ?? 0

        let data: Data
        if fileSize > mmapThreshold {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } else {
            data = try Data(contentsOf: url)
        }

        let encoding = EncodingManager.detectEncoding(from: data)

        // Strip BOM before decoding so it doesn't appear in the text.
        let strippedData = Self.stripBOM(from: data, encoding: encoding)

        guard let content = String(data: strippedData, encoding: encoding) else {
            throw FileIOError.unableToDecode(url, encoding)
        }

        let lineEnding = Self.detectLineEnding(in: content)

        return (content, encoding, lineEnding)
    }

    // MARK: - Write

    /// Write `content` to `url` with the specified encoding and line-ending style.
    ///
    /// - Parameters:
    ///   - content: Text to write.
    ///   - url: Destination file URL.
    ///   - encoding: Target encoding.
    ///   - lineEnding: Target line-ending style (content will be normalised).
    ///   - atomic: Whether to write atomically (default `true`).
    /// - Throws: ``FileIOError`` when encoding fails; Foundation errors on I/O
    ///   failure.
    public static func writeFile(
        content: String,
        to url: URL,
        encoding: String.Encoding,
        lineEnding: LineEnding,
        atomic: Bool = true
    ) throws {
        // Normalise line endings in the content.
        let normalised = Self.normaliseLineEndings(in: content, to: lineEnding)

        guard var data = normalised.data(using: encoding, allowLossyConversion: false) else {
            throw FileIOError.unableToEncode(encoding)
        }

        // Prepend BOM when required by the encoding.
        data = Self.prependBOMIfNeeded(to: data, encoding: encoding)

        let options: Data.WritingOptions = atomic ? [.atomic] : []
        try data.write(to: url, options: options)
    }

    // MARK: - File Info

    /// Gather metadata about the file at `url`.
    ///
    /// - Parameter url: The file URL to inspect.
    /// - Returns: A ``FileInfo`` value.
    /// - Throws: ``FileIOError`` when the file cannot be found or read.
    public static func fileInfo(at url: URL) throws -> FileInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileIOError.fileNotFound(url)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? UInt64) ?? 0
        let modDate = (attributes[.modificationDate] as? Date) ?? Date.distantPast
        let isReadOnly = !FileManager.default.isWritableFile(atPath: url.path)

        // Read a small portion to detect encoding and line ending without
        // loading the entire file into memory.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let sampleData = handle.readData(ofLength: min(Int(size), 8192))

        let encoding = EncodingManager.detectEncoding(from: sampleData)
        let strippedSample = Self.stripBOM(from: sampleData, encoding: encoding)
        let sampleText = String(data: strippedSample, encoding: encoding) ?? ""
        let lineEnding = Self.detectLineEnding(in: sampleText)

        return FileInfo(
            size: size,
            modificationDate: modDate,
            isReadOnly: isReadOnly,
            encoding: encoding,
            lineEnding: lineEnding
        )
    }

    // MARK: - Private Helpers

    /// Detect the dominant line ending in `text`.
    private static func detectLineEnding(in text: String) -> LineEnding {
        var crlfCount = 0
        var lfCount = 0
        var crCount = 0

        let scalars = text.unicodeScalars
        var index = scalars.startIndex

        while index < scalars.endIndex {
            let scalar = scalars[index]
            if scalar == "\r" {
                let next = scalars.index(after: index)
                if next < scalars.endIndex, scalars[next] == "\n" {
                    crlfCount += 1
                    index = scalars.index(after: next)
                } else {
                    crCount += 1
                    index = scalars.index(after: index)
                }
            } else if scalar == "\n" {
                lfCount += 1
                index = scalars.index(after: index)
            } else {
                index = scalars.index(after: index)
            }
        }

        if crlfCount >= lfCount && crlfCount >= crCount && crlfCount > 0 {
            return .crlf
        } else if crCount >= lfCount && crCount > 0 {
            return .cr
        }
        return .lf
    }

    /// Normalise all line endings in `text` to the specified style.
    private static func normaliseLineEndings(in text: String, to lineEnding: LineEnding) -> String {
        let target: String
        switch lineEnding {
        case .lf:   target = "\n"
        case .cr:   target = "\r"
        case .crlf: target = "\r\n"
        }

        // First normalise everything to LF, then replace with target.
        let unified = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if target == "\n" {
            return unified
        }
        return unified.replacingOccurrences(of: "\n", with: target)
    }

    /// Strip the BOM from the beginning of `data` for the detected encoding.
    private static func stripBOM(from data: Data, encoding: String.Encoding) -> Data {
        switch encoding {
        case .utf8:
            if data.count >= 3, Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF] {
                return data.dropFirst(3)
            }
        case .utf16LittleEndian:
            if data.count >= 2, Array(data.prefix(2)) == [0xFF, 0xFE] {
                return data.dropFirst(2)
            }
        case .utf16BigEndian:
            if data.count >= 2, Array(data.prefix(2)) == [0xFE, 0xFF] {
                return data.dropFirst(2)
            }
        case .utf32LittleEndian:
            if data.count >= 4, Array(data.prefix(4)) == [0xFF, 0xFE, 0x00, 0x00] {
                return data.dropFirst(4)
            }
        case .utf32BigEndian:
            if data.count >= 4, Array(data.prefix(4)) == [0x00, 0x00, 0xFE, 0xFF] {
                return data.dropFirst(4)
            }
        default:
            break
        }
        return data
    }

    /// Prepend the appropriate BOM when writing certain encodings.
    private static func prependBOMIfNeeded(to data: Data, encoding: String.Encoding) -> Data {
        switch encoding {
        case .utf16LittleEndian:
            var out = Data([0xFF, 0xFE])
            out.append(data)
            return out
        case .utf16BigEndian:
            var out = Data([0xFE, 0xFF])
            out.append(data)
            return out
        case .utf32LittleEndian:
            var out = Data([0xFF, 0xFE, 0x00, 0x00])
            out.append(data)
            return out
        case .utf32BigEndian:
            var out = Data([0x00, 0x00, 0xFE, 0xFF])
            out.append(data)
            return out
        default:
            return data
        }
    }
}
