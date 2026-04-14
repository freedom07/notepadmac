// Extensions.swift
// CommonKit — Shared utilities for NotepadNext
// Target: macOS 13+

import Foundation
import AppKit

// MARK: - LineEnding

/// Represents the line ending style of a text document.
public enum LineEnding: String, CaseIterable, Sendable {
    case lf   = "\n"
    case crlf = "\r\n"
    case cr   = "\r"

    /// Human-readable label for UI display.
    public var displayName: String {
        switch self {
        case .lf:   return "LF (Unix)"
        case .crlf: return "CRLF (Windows)"
        case .cr:   return "CR (Classic Mac)"
        }
    }

    /// Detects the dominant line ending in raw file data.
    /// Returns `.lf` when no line endings are found.
    public static func detect(from data: Data) -> LineEnding {
        var lfCount = 0
        var crlfCount = 0
        var crCount = 0

        let bytes = [UInt8](data)
        var i = 0
        while i < bytes.count {
            if bytes[i] == 0x0D { // CR
                if i + 1 < bytes.count, bytes[i + 1] == 0x0A {
                    crlfCount += 1
                    i += 2
                } else {
                    crCount += 1
                    i += 1
                }
            } else if bytes[i] == 0x0A { // LF
                lfCount += 1
                i += 1
            } else {
                i += 1
            }
        }

        if crlfCount >= lfCount && crlfCount >= crCount && crlfCount > 0 {
            return .crlf
        } else if crCount >= lfCount && crCount > 0 {
            return .cr
        }
        return .lf
    }
}

// MARK: - TextPosition

/// A zero-indexed position within a text document.
public struct TextPosition: Equatable, Comparable, Hashable, Sendable {
    /// Zero-based line number.
    public let line: Int
    /// Zero-based column offset (in UTF-16 code units for NSTextView compatibility).
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (lhs: TextPosition, rhs: TextPosition) -> Bool {
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        return lhs.column < rhs.column
    }
}

// MARK: - TextRange

/// A range within a text document defined by start and end positions.
public struct TextRange: Equatable, Hashable, Sendable {
    public let start: TextPosition
    public let end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        self.start = start
        self.end = end
    }

    /// True when start equals end.
    public var isEmpty: Bool { start == end }

    /// Number of lines spanned (inclusive).
    public var lineSpan: Int { end.line - start.line + 1 }
}

// MARK: - String Extensions

public extension String {

    /// Returns the number of lines in the string.
    /// An empty string has 1 line. A trailing newline adds an extra empty line.
    var lineCount: Int {
        var count = 1
        var idx = startIndex
        while idx < endIndex {
            let c = self[idx]
            if c == "\r\n" {
                count += 1
                idx = self.index(after: idx) // \r\n is one Character in Swift
            } else if c == "\n" || c == "\r" {
                count += 1
                idx = self.index(after: idx)
            } else {
                idx = self.index(after: idx)
            }
        }
        return count
    }

    /// Converts a `String.Index` to a UTF-16 offset, suitable for `NSRange`.
    func utf16Offset(of index: String.Index) -> Int {
        utf16.distance(from: utf16.startIndex, to: index)
    }

    /// Converts a UTF-16 offset back to a `String.Index`, or nil if out of range.
    func stringIndex(fromUTF16Offset offset: Int) -> String.Index? {
        guard let idx = utf16.index(utf16.startIndex, offsetBy: offset, limitedBy: utf16.endIndex) else {
            return nil
        }
        return idx.samePosition(in: self)
    }

    /// Safe subscript returning a substring for the given range.
    subscript(range: Range<Int>) -> Substring? {
        let lower = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex)
        let upper = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex)
        guard let lo = lower, let up = upper, lo <= up else { return nil }
        return self[lo..<up]
    }

    /// Computes a `TextPosition` for the given `String.Index`.
    func textPosition(at target: String.Index) -> TextPosition {
        var line = 0
        var columnStart = startIndex
        var idx = startIndex

        while idx < target && idx < endIndex {
            let c = self[idx]
            if c == "\r\n" {
                line += 1
                idx = self.index(after: idx) // \r\n is one Character in Swift
                columnStart = idx
            } else if c == "\n" || c == "\r" {
                line += 1
                idx = self.index(after: idx)
                columnStart = idx
            } else {
                idx = self.index(after: idx)
            }
        }

        let column = utf16.distance(from: columnStart, to: target)
        return TextPosition(line: line, column: column)
    }
}

// MARK: - NSRange / Range<String.Index> Conversion

public extension String {

    /// Creates an `NSRange` covering the entire string in UTF-16 code units.
    var fullNSRange: NSRange {
        NSRange(startIndex..<endIndex, in: self)
    }

    /// Converts a `Range<String.Index>` to `NSRange`.
    func nsRange(from range: Range<String.Index>) -> NSRange {
        NSRange(range, in: self)
    }

    /// Converts an `NSRange` back to `Range<String.Index>`, or nil if invalid.
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        Range(nsRange, in: self)
    }
}

public extension NSRange {

    /// Convenience initializer from two UTF-16 offsets.
    init(utf16Start: Int, utf16End: Int) {
        self.init(location: utf16Start, length: utf16End - utf16Start)
    }

    /// True when the range has zero length.
    var isEmpty: Bool { length == 0 }

    /// The end location (`location + length`).
    var end: Int { location + length }
}

// MARK: - Data Extension: Encoding Detection

public extension Data {

    /// Supported text encodings with their BOM signatures.
    enum DetectedEncoding {
        case utf8
        case utf16BigEndian
        case utf16LittleEndian
        case utf32BigEndian
        case utf32LittleEndian
        case unknown

        /// The corresponding `String.Encoding`, if deterministic.
        public var stringEncoding: String.Encoding {
            switch self {
            case .utf8:              return .utf8
            case .utf16BigEndian:    return .utf16BigEndian
            case .utf16LittleEndian: return .utf16LittleEndian
            case .utf32BigEndian:    return .utf32BigEndian
            case .utf32LittleEndian: return .utf32LittleEndian
            case .unknown:           return .utf8 // sensible default
            }
        }
    }

    /// Detects text encoding by examining the byte-order mark.
    /// Falls back to `.unknown` when no BOM is present.
    func detectEncoding() -> DetectedEncoding {
        let bytes = [UInt8](prefix(4))
        guard bytes.count >= 2 else { return .unknown }

        // UTF-32 BOMs (check before UTF-16 since they share prefix bytes)
        if bytes.count >= 4 {
            if bytes[0] == 0x00 && bytes[1] == 0x00 && bytes[2] == 0xFE && bytes[3] == 0xFF {
                return .utf32BigEndian
            }
            if bytes[0] == 0xFF && bytes[1] == 0xFE && bytes[2] == 0x00 && bytes[3] == 0x00 {
                return .utf32LittleEndian
            }
        }

        // UTF-8 BOM
        if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
            return .utf8
        }

        // UTF-16 BOMs
        if bytes[0] == 0xFE && bytes[1] == 0xFF { return .utf16BigEndian }
        if bytes[0] == 0xFF && bytes[1] == 0xFE { return .utf16LittleEndian }

        return .unknown
    }

    /// Byte length of the detected BOM, or 0 if none.
    var bomLength: Int {
        let enc = detectEncoding()
        switch enc {
        case .utf32BigEndian, .utf32LittleEndian: return 4
        case .utf8:              return 3
        case .utf16BigEndian, .utf16LittleEndian: return 2
        case .unknown:           return 0
        }
    }

    /// Returns a copy of the data with the BOM stripped, if any.
    func strippingBOM() -> Data {
        let len = bomLength
        return len > 0 ? dropFirst(len) : self
    }
}

// MARK: - Debouncer

/// Coalesces rapid calls, executing the action only after a quiet period.
/// Thread-safe. Typically used for search-as-you-type and syntax highlighting.
public final class Debouncer: @unchecked Sendable {

    private let delay: TimeInterval
    private let queue: DispatchQueue
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()

    /// Creates a debouncer.
    /// - Parameters:
    ///   - delay: Quiet period in seconds before the action fires.
    ///   - queue: Dispatch queue for the action. Defaults to main.
    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }

    /// Schedules (or reschedules) the action. Previous pending action is cancelled.
    public func debounce(action: @escaping () -> Void) {
        lock.lock()
        workItem?.cancel()
        let item = DispatchWorkItem(block: action)
        workItem = item
        lock.unlock()

        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Cancels any pending action.
    public func cancel() {
        lock.lock()
        workItem?.cancel()
        workItem = nil
        lock.unlock()
    }
}

// MARK: - Disposable

/// A handle for cancelling a subscription or observation.
/// Call `dispose()` or let the object deinit to clean up.
public protocol Disposable: AnyObject {
    func dispose()
}

/// Concrete disposable backed by a closure.
public final class ActionDisposable: Disposable {
    private var action: (() -> Void)?
    private let lock = NSLock()

    public init(_ action: @escaping () -> Void) {
        self.action = action
    }

    public func dispose() {
        lock.lock()
        let a = action
        action = nil
        lock.unlock()
        a?()
    }

    deinit { dispose() }
}

/// Collects multiple disposables and disposes them together.
public final class DisposeBag {
    private var disposables: [Disposable] = []
    private let lock = NSLock()

    public init() {}

    /// Adds a disposable to the bag.
    public func add(_ disposable: Disposable) {
        lock.lock()
        disposables.append(disposable)
        lock.unlock()
    }

    /// Disposes and removes all collected disposables.
    public func disposeAll() {
        lock.lock()
        let items = disposables
        disposables.removeAll()
        lock.unlock()
        items.forEach { $0.dispose() }
    }

    deinit { disposeAll() }
}

/// Syntactic sugar: `disposable.disposed(by: bag)`.
public extension Disposable {
    func disposed(by bag: DisposeBag) {
        bag.add(self)
    }
}
