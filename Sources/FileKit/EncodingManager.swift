// EncodingManager.swift
// FileKit – NotepadNext
//
// Encoding detection, conversion, and metadata for text files.

import Foundation

/// Manages text encoding detection, conversion, and display metadata.
public final class EncodingManager {

    // MARK: - CFStringEncoding Helpers

    /// Create a `String.Encoding` from a `CFStringEncodings` constant.
    private static func encoding(from cfEncoding: CFStringEncodings) -> String.Encoding {
        let cf = CFStringEncoding(cfEncoding.rawValue)
        let ns = CFStringConvertEncodingToNSStringEncoding(cf)
        return String.Encoding(rawValue: ns)
    }

    // MARK: - Supported Encodings

    /// All encodings the editor can read/write, paired with human-readable names.
    public static let supportedEncodings: [(name: String, encoding: String.Encoding)] = {
        var list: [(name: String, encoding: String.Encoding)] = [
            // Unicode
            ("UTF-8",           .utf8),
            ("UTF-8 BOM",       .utf8),               // handled specially during write
            ("UTF-16 LE",       .utf16LittleEndian),
            ("UTF-16 BE",       .utf16BigEndian),
            ("UTF-32 LE",       .utf32LittleEndian),
            ("UTF-32 BE",       .utf32BigEndian),
            ("ASCII",           .ascii),

            // Western
            ("ISO 8859-1",      .isoLatin1),
            ("Windows-1252",    .windowsCP1252),
            ("Mac Roman",       .macOSRoman),

            // Windows codepages
            ("Windows-1250",    encoding(from: .windowsLatin2)),       // Central European
            ("Windows-1251",    encoding(from: .windowsCyrillic)),     // Cyrillic
            ("Windows-1253",    encoding(from: .windowsGreek)),        // Greek
            ("Windows-1254",    encoding(from: .windowsLatin5)),       // Turkish
            ("Windows-1255",    encoding(from: .windowsHebrew)),       // Hebrew
            ("Windows-1256",    encoding(from: .windowsArabic)),       // Arabic
            ("Windows-1257",    encoding(from: .windowsBalticRim)),    // Baltic
            ("Windows-1258",    encoding(from: .windowsVietnamese)),   // Vietnamese

            // ISO-8859 series
            ("ISO 8859-2",      encoding(from: .isoLatin2)),           // Central European
            ("ISO 8859-3",      encoding(from: .isoLatin3)),           // South European
            ("ISO 8859-4",      encoding(from: .isoLatin4)),           // North European
            ("ISO 8859-5",      encoding(from: .isoLatinCyrillic)),    // Cyrillic
            ("ISO 8859-6",      encoding(from: .isoLatinArabic)),      // Arabic
            ("ISO 8859-7",      encoding(from: .isoLatinGreek)),       // Greek
            ("ISO 8859-8",      encoding(from: .isoLatinHebrew)),      // Hebrew
            ("ISO 8859-9",      encoding(from: .isoLatin5)),           // Turkish
            ("ISO 8859-10",     encoding(from: .isoLatin6)),           // Nordic
            ("ISO 8859-13",     encoding(from: .isoLatin7)),           // Baltic
            ("ISO 8859-14",     encoding(from: .isoLatin8)),           // Celtic
            ("ISO 8859-15",     encoding(from: .isoLatin9)),           // Western revised
            ("ISO 8859-16",     encoding(from: .isoLatin10)),          // South-Eastern European

            // DOS codepages
            ("DOS 437",         encoding(from: .dosLatinUS)),          // US
            ("DOS 850",         encoding(from: .dosLatin1)),           // Multilingual Latin 1
            ("DOS 866",         encoding(from: .dosRussian)),          // Russian

            // CJK
            ("EUC-KR",          encoding(from: .EUC_KR)),
            ("Shift-JIS",       .shiftJIS),
            ("ISO-2022-JP",     .iso2022JP),
            ("GB18030",         encoding(from: .GB_18030_2000)),
            ("Big5",            encoding(from: .big5)),

            // Other
            ("KOI8-R",          encoding(from: .KOI8_R)),
        ]

        // Filter out any encodings that are not available on this macOS version
        // (kCFStringEncodingInvalidId manifests as rawValue 0xFFFFFFFF)
        list = list.filter { entry in
            entry.encoding.rawValue != UInt(kCFStringEncodingInvalidId)
        }

        return list
    }()

    // MARK: - Encoding Groups (for menu building)

    /// Encoding group definitions for structured menu presentation.
    public struct EncodingGroup {
        public let title: String
        public let encodingNames: [String]
    }

    /// Returns encoding names organized into logical groups for menu construction.
    public static let encodingGroups: [EncodingGroup] = [
        EncodingGroup(title: "Unicode", encodingNames: [
            "UTF-8", "UTF-8 BOM", "UTF-16 LE", "UTF-16 BE",
            "UTF-32 LE", "UTF-32 BE", "ASCII",
        ]),
        EncodingGroup(title: "Western", encodingNames: [
            "ISO 8859-1", "Windows-1252", "Mac Roman",
        ]),
        EncodingGroup(title: "Windows Codepages", encodingNames: [
            "Windows-1250", "Windows-1251", "Windows-1253", "Windows-1254",
            "Windows-1255", "Windows-1256", "Windows-1257", "Windows-1258",
        ]),
        EncodingGroup(title: "ISO 8859", encodingNames: [
            "ISO 8859-2", "ISO 8859-3", "ISO 8859-4", "ISO 8859-5",
            "ISO 8859-6", "ISO 8859-7", "ISO 8859-8", "ISO 8859-9",
            "ISO 8859-10", "ISO 8859-13", "ISO 8859-14", "ISO 8859-15",
            "ISO 8859-16",
        ]),
        EncodingGroup(title: "DOS Codepages", encodingNames: [
            "DOS 437", "DOS 850", "DOS 866",
        ]),
        EncodingGroup(title: "CJK", encodingNames: [
            "EUC-KR", "Shift-JIS", "ISO-2022-JP", "GB18030", "Big5",
        ]),
        EncodingGroup(title: "Other", encodingNames: [
            "KOI8-R",
        ]),
    ]

    /// All encoding display names, in the order they appear in `supportedEncodings`.
    public static var allEncodingNames: [String] {
        supportedEncodings.map(\.name)
    }

    // MARK: - BOM Constants

    private static let utf8BOM: [UInt8]    = [0xEF, 0xBB, 0xBF]
    private static let utf16LEBOM: [UInt8]  = [0xFF, 0xFE]
    private static let utf16BEBOM: [UInt8]  = [0xFE, 0xFF]
    private static let utf32LEBOM: [UInt8]  = [0xFF, 0xFE, 0x00, 0x00]
    private static let utf32BEBOM: [UInt8]  = [0x00, 0x00, 0xFE, 0xFF]

    // MARK: - Detection

    /// Detect the encoding of raw file data by inspecting BOM bytes first,
    /// then falling back to UTF-8 validation, then heuristic analysis.
    ///
    /// - Parameter data: The raw bytes of the file.
    /// - Returns: The detected `String.Encoding`.
    public static func detectEncoding(from data: Data) -> String.Encoding {
        let bytes = Array(data.prefix(4))

        // UTF-32 BOMs must be checked before UTF-16 because
        // UTF-32 LE BOM starts with the same two bytes as UTF-16 LE BOM.
        if bytes.count >= 4 {
            if bytes[0...3] == ArraySlice(utf32LEBOM) {
                return .utf32LittleEndian
            }
            if bytes[0...3] == ArraySlice(utf32BEBOM) {
                return .utf32BigEndian
            }
        }

        if bytes.count >= 3, bytes[0...2] == ArraySlice(utf8BOM) {
            return .utf8
        }

        if bytes.count >= 2 {
            if bytes[0...1] == ArraySlice(utf16LEBOM) {
                return .utf16LittleEndian
            }
            if bytes[0...1] == ArraySlice(utf16BEBOM) {
                return .utf16BigEndian
            }
        }

        // No BOM found – try to validate as UTF-8.
        if isValidUTF8(data) {
            return .utf8
        }

        // Apply heuristic detection for non-UTF-8 data.
        return detectEncodingHeuristic(from: data)
    }

    /// Returns `true` when the data passed the UTF-8 BOM check during detection.
    /// Useful to decide whether to preserve the BOM on write.
    public static func hasUTF8BOM(_ data: Data) -> Bool {
        data.count >= 3 && Array(data.prefix(3)) == utf8BOM
    }

    // MARK: - Heuristic Detection

    /// Analyze byte patterns to heuristically determine the encoding of non-UTF-8 data.
    ///
    /// The analysis examines a sample of bytes and uses frequency patterns:
    /// 1. High frequency of bytes in 0x80-0x9F range suggests Windows-1252
    ///    (these are control codes in ISO 8859-1 but printable in Windows-1252).
    /// 2. CJK byte patterns are delegated to existing CJK detection logic.
    /// 3. Default fallback is ISO 8859-1.
    ///
    /// - Parameter data: The raw bytes of the file.
    /// - Returns: The heuristically detected `String.Encoding`.
    public static func detectEncodingHeuristic(from data: Data) -> String.Encoding {
        guard !data.isEmpty else { return .utf8 }

        // Sample up to 8KB for analysis
        let sample = Array(data.prefix(8192))
        let sampleCount = sample.count

        // Count bytes in specific ranges
        var countC0C1Range = 0     // 0xC0-0xC1: invalid UTF-8 lead bytes
        var count80_9F = 0         // 0x80-0x9F: Windows-1252 printable area
        var countA0_FF = 0         // 0xA0-0xFF: common in Latin encodings
        var countHighBytes = 0     // 0x80-0xFF: any high byte
        var hasNullByte = false

        // CJK pattern detection
        var consecutiveHighPairs = 0

        for i in 0..<sampleCount {
            let b = sample[i]

            if b == 0x00 {
                hasNullByte = true
            }

            if b >= 0x80 {
                countHighBytes += 1

                if b >= 0x80 && b <= 0x9F {
                    count80_9F += 1
                }
                if b >= 0xA0 {
                    countA0_FF += 1
                }
                if b == 0xC0 || b == 0xC1 {
                    countC0C1Range += 1
                }

                // Check for consecutive high-byte pairs (common in CJK double-byte encodings)
                if i + 1 < sampleCount && sample[i + 1] >= 0x80 {
                    consecutiveHighPairs += 1
                }
            }
        }

        // If there are null bytes and we got here, it might be a binary file
        // or a non-standard encoding. Fall back to ISO Latin-1.
        if hasNullByte {
            return .isoLatin1
        }

        // If no high bytes at all, it's ASCII-compatible — default to ISO Latin-1
        guard countHighBytes > 0 else {
            return .isoLatin1
        }

        // High frequency of 0x80-0x9F bytes strongly suggests Windows-1252
        // (In ISO 8859-1, these are C1 control codes rarely used in text files)
        let highByteRatio = Double(count80_9F) / Double(countHighBytes)
        if count80_9F >= 3 && highByteRatio > 0.15 {
            return .windowsCP1252
        }

        // High frequency of consecutive high-byte pairs suggests CJK encoding.
        // Require a minimum sample size to avoid false positives on short data.
        let cjkRatio = Double(consecutiveHighPairs) / Double(countHighBytes)
        if sampleCount >= 20 && consecutiveHighPairs >= 5 && cjkRatio > 0.3 {
            // Try to detect specific CJK encoding
            return detectCJKEncoding(from: sample)
        }

        // Default fallback — ISO 8859-1 is the safest single-byte fallback
        // as it can represent all byte values 0x00-0xFF.
        return .isoLatin1
    }

    // MARK: - CJK Detection

    /// Attempt to detect a specific CJK encoding from byte patterns.
    private static func detectCJKEncoding(from sample: [UInt8]) -> String.Encoding {
        // Try Shift-JIS: lead bytes 0x81-0x9F and 0xE0-0xEF
        var shiftJISScore = 0
        // Try EUC-KR / EUC-JP: lead bytes 0xA1-0xFE, trail bytes 0xA1-0xFE
        var eucScore = 0
        // Try Big5: lead bytes 0xA1-0xF9, trail bytes 0x40-0x7E or 0xA1-0xFE
        var big5Score = 0

        var i = 0
        while i < sample.count {
            let b = sample[i]

            if b >= 0x80 && i + 1 < sample.count {
                let next = sample[i + 1]

                // Shift-JIS pattern
                if (b >= 0x81 && b <= 0x9F) || (b >= 0xE0 && b <= 0xEF) {
                    if (next >= 0x40 && next <= 0x7E) || (next >= 0x80 && next <= 0xFC) {
                        shiftJISScore += 1
                    }
                }

                // EUC pattern
                if b >= 0xA1 && b <= 0xFE && next >= 0xA1 && next <= 0xFE {
                    eucScore += 1
                }

                // Big5 pattern
                if b >= 0xA1 && b <= 0xF9 {
                    if (next >= 0x40 && next <= 0x7E) || (next >= 0xA1 && next <= 0xFE) {
                        big5Score += 1
                    }
                }

                i += 2
            } else {
                i += 1
            }
        }

        // Pick the highest scoring encoding
        if shiftJISScore > eucScore && shiftJISScore > big5Score && shiftJISScore >= 3 {
            return .shiftJIS
        }
        if eucScore > big5Score && eucScore >= 3 {
            // Could be EUC-KR or EUC-JP; default to EUC-KR
            return encoding(from: .EUC_KR)
        }
        if big5Score >= 3 {
            return encoding(from: .big5)
        }

        // If none scored high enough, try GB18030 as a catch-all for Chinese
        return encoding(from: .GB_18030_2000)
    }

    // MARK: - Lookup

    /// Look up a `String.Encoding` by its display name.
    ///
    /// - Parameter name: The human-readable encoding name (e.g. "UTF-8", "Windows-1252").
    /// - Returns: The corresponding `String.Encoding`, or `nil` if not found.
    public static func encoding(forName name: String) -> String.Encoding? {
        supportedEncodings.first(where: { $0.name == name })?.encoding
    }

    // MARK: - Name Helpers

    /// A human-readable name for the given encoding.
    ///
    /// Tries the `supportedEncodings` table first, then falls back to
    /// the Foundation localised description.
    public static func encodingName(_ encoding: String.Encoding) -> String {
        if let match = supportedEncodings.first(where: { $0.encoding == encoding }) {
            return match.name
        }
        return encoding.description
    }

    // MARK: - Conversion

    /// Convert a `String` to `Data` using the specified encoding.
    ///
    /// - Parameters:
    ///   - text: Source text.
    ///   - encoding: Target encoding.
    /// - Returns: Encoded data, or `nil` when the encoding cannot represent the text.
    public static func convert(text: String, to encoding: String.Encoding) -> Data? {
        text.data(using: encoding, allowLossyConversion: false)
    }

    /// Re-interpret raw data using a different encoding.
    ///
    /// This is used when the user manually selects an encoding to re-read the file.
    ///
    /// - Parameters:
    ///   - data: The raw file bytes.
    ///   - encoding: The encoding to use for interpretation.
    /// - Returns: The decoded string, or `nil` if the data cannot be decoded
    ///   with the specified encoding.
    public static func reinterpret(data: Data, as encoding: String.Encoding) -> String? {
        String(data: data, encoding: encoding)
    }

    // MARK: - Private Helpers

    /// Lightweight UTF-8 validation: attempt to construct a `String` from the
    /// data using strict UTF-8 decoding.  This avoids pulling in ICU.
    private static func isValidUTF8(_ data: Data) -> Bool {
        // Empty data is trivially valid.
        guard !data.isEmpty else { return true }

        // Attempt strict decode via the stdlib UTF-8 codec.
        var iterator = data.makeIterator()
        var codec = UTF8()
        while true {
            switch codec.decode(&iterator) {
            case .scalarValue:
                continue
            case .emptyInput:
                return true
            case .error:
                return false
            }
        }
    }
}
