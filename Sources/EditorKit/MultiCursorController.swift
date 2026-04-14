import AppKit
import CommonKit

// MARK: - MultiCursor

/// Represents a single cursor (caret) within the text document.
///
/// Each cursor tracks a character offset and an optional selection range.
/// Multiple ``MultiCursor`` instances are managed by ``MultiCursorController``
/// to support multi-caret editing and column (rectangular) selection.
@available(macOS 13.0, *)
public struct MultiCursor: Equatable, Hashable {

    /// Character offset in the document where this cursor is positioned.
    public var position: Int

    /// Optional selection range associated with this cursor.
    /// When `nil`, the cursor is a simple caret with no selection.
    public var selection: NSRange?

    /// Creates a cursor at the given character offset.
    /// - Parameters:
    ///   - position: Character offset in the document.
    ///   - selection: Optional selection range tied to this cursor.
    public init(position: Int, selection: NSRange? = nil) {
        self.position = position
        self.selection = selection
    }
}

// MARK: - MultiCursorController

/// Manages multiple cursors and column (rectangular) selections for a text view.
///
/// ``MultiCursorController`` enables Sublime Text / VS Code-style multi-caret
/// editing in an `NSTextView`. It supports:
///
/// - Adding cursors via Option-Click.
/// - Column (block) selection via Option-Drag.
/// - Simultaneous text insertion and deletion across all active cursors.
///
/// Cursor positions are kept sorted and automatically merged when they overlap
/// after movement or editing operations.
///
/// ```swift
/// let controller = MultiCursorController()
/// controller.textView = myTextView
/// controller.addCursor(at: 42)
/// controller.insertTextAtAllCursors("Hello", in: myTextView)
/// ```
@available(macOS 13.0, *)
public class MultiCursorController {

    // MARK: - Properties

    /// All active cursors, sorted by position in ascending order.
    public private(set) var cursors: [MultiCursor] = []

    /// Whether multi-cursor editing is currently active.
    ///
    /// Returns `true` when more than one cursor exists, indicating that
    /// editing operations will be applied at multiple positions simultaneously.
    public var isMultiCursorActive: Bool {
        cursors.count > 1
    }

    /// The text view that this controller manages cursors for.
    public weak var textView: NSTextView?

    // MARK: - Initialisation

    /// Creates a new multi-cursor controller.
    ///
    /// - Parameter textView: The text view to manage. Can also be set later
    ///   via the ``textView`` property.
    public init(textView: NSTextView? = nil) {
        self.textView = textView
    }

    // MARK: - Cursor Management (Testing Support)

    /// Replaces the entire cursor list. Intended for testing or
    /// programmatic setup where the public add/remove API is insufficient.
    ///
    /// - Parameter newCursors: The cursors to set. They will be sorted and
    ///   merged automatically.
    public func setCursors(_ newCursors: [MultiCursor]) {
        cursors = newCursors
        mergeCursors()
    }

    // MARK: - Cursor Management

    /// Adds a new cursor at the specified character position.
    ///
    /// The cursor list is kept sorted by position. If the new cursor overlaps
    /// with an existing one (same position or overlapping selection), the
    /// cursors are merged automatically.
    ///
    /// - Parameter position: Character offset in the document where the new
    ///   cursor should be placed.
    public func addCursor(at position: Int) {
        let cursor = MultiCursor(position: position)
        cursors.append(cursor)
        mergeCursors()
    }

    /// Removes the cursor at the given index.
    ///
    /// - Parameter index: Zero-based index into the ``cursors`` array.
    ///   Must be within bounds; out-of-range indices are silently ignored.
    public func removeCursor(at index: Int) {
        guard cursors.indices.contains(index) else { return }
        cursors.remove(at: index)
    }

    /// Removes all additional cursors, keeping only the primary (first) cursor.
    ///
    /// After this call, ``isMultiCursorActive`` will return `false`.
    /// If no cursors exist, this method does nothing.
    public func clearAdditionalCursors() {
        guard let primary = cursors.first else { return }
        cursors = [primary]
    }

    // MARK: - Column (Block) Selection

    /// Creates a rectangular (column) selection spanning multiple lines.
    ///
    /// One cursor is created per line within the specified range, each
    /// selecting from `fromColumn` to `toColumn` on that line. Lines shorter
    /// than `fromColumn` are skipped; selections are clamped to the actual
    /// line length.
    ///
    /// This is the backing operation for Option-Drag column selection.
    ///
    /// - Parameters:
    ///   - fromLine: Zero-based starting line number (inclusive).
    ///   - toLine: Zero-based ending line number (inclusive).
    ///   - fromColumn: Zero-based starting column within each line.
    ///   - toColumn: Zero-based ending column within each line.
    ///   - text: The full document text used to resolve line offsets.
    public func selectColumnBlock(
        fromLine: Int,
        toLine: Int,
        fromColumn: Int,
        toColumn: Int,
        in text: String
    ) {
        let lines = text.components(separatedBy: "\n")
        let startLine = max(min(fromLine, toLine), 0)
        let endLine = min(max(fromLine, toLine), lines.count - 1)
        let startCol = min(fromColumn, toColumn)
        let endCol = max(fromColumn, toColumn)

        var newCursors: [MultiCursor] = []
        var lineOffset = 0

        for lineIndex in 0..<lines.count {
            let lineLength = (lines[lineIndex] as NSString).length // UTF-16 length for NSRange compatibility

            if lineIndex >= startLine && lineIndex <= endLine {
                // Skip lines that are shorter than the start column.
                if startCol <= lineLength {
                    let clampedEnd = min(endCol, lineLength)
                    let selectionStart = lineOffset + startCol
                    let selectionLength = clampedEnd - startCol

                    let selectionRange: NSRange? = selectionLength > 0
                        ? NSRange(location: selectionStart, length: selectionLength)
                        : nil

                    let cursor = MultiCursor(
                        position: lineOffset + clampedEnd,
                        selection: selectionRange
                    )
                    newCursors.append(cursor)
                }
            }

            lineOffset += lineLength + 1 // +1 for the newline character
        }

        cursors = newCursors
        mergeCursors()
    }

    // MARK: - Editing Operations

    /// Inserts the same text at every active cursor position.
    ///
    /// Insertions are applied from the last cursor to the first so that
    /// earlier character offsets remain valid throughout the operation.
    /// All cursor positions are adjusted after insertion to sit at the end
    /// of the newly inserted text.
    ///
    /// - Parameters:
    ///   - text: The string to insert at each cursor.
    ///   - textView: The text view whose text storage will be mutated.
    public func insertTextAtAllCursors(_ text: String, in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let insertLength = (text as NSString).length

        // Apply from last to first to keep earlier offsets stable.
        let sortedDescending = cursors.sorted { $0.position > $1.position }

        textStorage.beginEditing()

        for cursor in sortedDescending {
            let insertionPoint = min(cursor.position, textStorage.length)

            if let selection = cursor.selection,
               selection.location >= 0,
               selection.location + selection.length <= textStorage.length {
                // Replace the selected text.
                textStorage.replaceCharacters(in: selection, with: text)
            } else {
                // Insert at the cursor position.
                textStorage.replaceCharacters(
                    in: NSRange(location: insertionPoint, length: 0),
                    with: text
                )
            }
        }

        textStorage.endEditing()

        // Recompute cursor positions after all insertions.
        recalculatePositionsAfterInsert(insertLength: insertLength)
    }

    /// Deletes one character before each active cursor (backspace operation).
    ///
    /// If a cursor has a selection, the entire selection is deleted instead.
    /// Deletions are applied from the last cursor to the first so that
    /// earlier character offsets remain valid. Cursors at position 0 with
    /// no selection are left unchanged.
    ///
    /// - Parameter textView: The text view whose text storage will be mutated.
    public func deleteAtAllCursors(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        // Apply from last to first to keep earlier offsets stable.
        let sortedDescending = cursors.sorted { $0.position > $1.position }

        textStorage.beginEditing()

        for cursor in sortedDescending {
            if let selection = cursor.selection,
               selection.length > 0,
               selection.location >= 0,
               selection.location + selection.length <= textStorage.length {
                // Delete the entire selection.
                textStorage.replaceCharacters(in: selection, with: "")
            } else if cursor.position > 0 && cursor.position <= textStorage.length {
                // Delete one character before the cursor.
                let deleteRange = NSRange(location: cursor.position - 1, length: 1)
                textStorage.replaceCharacters(in: deleteRange, with: "")
            }
        }

        textStorage.endEditing()

        // Recompute cursor positions after deletions.
        recalculatePositionsAfterDelete()
    }

    // MARK: - Cursor Movement

    /// Moves all cursors by the given character offset.
    ///
    /// Positive values move cursors forward; negative values move them
    /// backward. Positions are clamped to zero at the lower bound.
    /// Selections are cleared and overlapping cursors are merged after
    /// movement.
    ///
    /// - Parameter offset: Number of characters to shift each cursor by.
    public func moveCursorsBy(_ offset: Int) {
        for index in cursors.indices {
            cursors[index].position = max(0, cursors[index].position + offset)
            cursors[index].selection = nil
        }
        mergeCursors()
    }

    // MARK: - Event Handling

    /// Processes a mouse event to add cursors or create a column selection.
    ///
    /// - **Option-Click** (`leftMouseDown` with Option modifier): Adds a new
    ///   cursor at the clicked character position. If a cursor already exists
    ///   at that position and multiple cursors are active, the existing cursor
    ///   is removed instead (toggle behavior).
    /// - **Option-Drag** (`leftMouseDragged` with Option modifier): Creates a
    ///   column (rectangular) selection from the primary cursor's position to
    ///   the current drag point.
    ///
    /// Call this from your text view's `mouseDown(with:)` override when the
    /// Option key modifier is detected.
    ///
    /// - Parameters:
    ///   - event: The mouse event (typically from `mouseDown(with:)`).
    ///   - textView: The text view where the event occurred.
    public func updateCursorsFromEvent(_ event: NSEvent, in textView: NSTextView) {
        let point = textView.convert(event.locationInWindow, from: nil)

        // Adjust for text container inset.
        var adjustedPoint = point
        adjustedPoint.x -= textView.textContainerInset.width
        adjustedPoint.y -= textView.textContainerInset.height

        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager
        else { return }

        let characterIndex = layoutManager.characterIndex(
            for: adjustedPoint,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let hasOption = event.modifierFlags.contains(.option)
        guard hasOption else { return }

        if event.type == .leftMouseDown {
            // Option-Click: toggle a cursor at the click location.
            if let existing = cursors.firstIndex(where: { $0.position == characterIndex }),
               cursors.count > 1 {
                cursors.remove(at: existing)
            } else {
                addCursor(at: characterIndex)
            }
            applyCursorsToTextView(textView)

        } else if event.type == .leftMouseDragged {
            // Option-Drag: column (block) selection.
            handleColumnDrag(at: adjustedPoint, in: textView)
        }
    }

    // MARK: - Occurrence Selection

    /// The last search term used by ``selectNextOccurrence``, stored so that
    /// repeated invocations continue selecting occurrences of the same term.
    private var currentSearchTerm: String?

    /// Selects all occurrences of the word under cursor or the current selection.
    ///
    /// If the text view has a non-empty selection, the selected text is used as
    /// the search term. Otherwise, the word under the cursor is inferred. Each
    /// match becomes a new cursor with its selection set to the match range.
    ///
    /// - Parameters:
    ///   - textView: The text view to operate on.
    ///   - caseSensitive: Whether the search should be case-sensitive.
    ///   - wholeWord: Whether matches must align with word boundaries.
    public func selectAllOccurrences(
        in textView: NSTextView,
        caseSensitive: Bool = false,
        wholeWord: Bool = true
    ) {
        guard let term = resolveSearchTerm(in: textView), !term.isEmpty else { return }

        currentSearchTerm = term

        let nsText = textView.string as NSString
        guard let regex = buildOccurrenceRegex(for: term, caseSensitive: caseSensitive, wholeWord: wholeWord) else { return }

        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: textView.string, range: fullRange)

        guard !matches.isEmpty else { return }

        var newCursors: [MultiCursor] = []
        for match in matches {
            let range = match.range
            newCursors.append(MultiCursor(
                position: range.location + range.length,
                selection: range
            ))
        }

        cursors = newCursors
        mergeCursors()
        applyCursorsToTextView(textView)
    }

    /// Adds a cursor at the next occurrence of the current word or selection.
    ///
    /// The first call captures the search term from the current selection or
    /// word under cursor. Subsequent calls reuse the same term and search
    /// forward from the last cursor position.
    ///
    /// - Parameters:
    ///   - textView: The text view to operate on.
    ///   - caseSensitive: Whether the search should be case-sensitive.
    ///   - wholeWord: Whether matches must align with word boundaries.
    public func selectNextOccurrence(
        in textView: NSTextView,
        caseSensitive: Bool = false,
        wholeWord: Bool = true
    ) {
        let term: String
        if let existing = currentSearchTerm {
            term = existing
        } else if let resolved = resolveSearchTerm(in: textView), !resolved.isEmpty {
            term = resolved
            currentSearchTerm = term

            // If the cursor has no selection, select the current word first.
            if cursors.isEmpty || (cursors.count == 1 && cursors[0].selection == nil) {
                let sel = textView.selectedRange()
                if sel.length == 0, let wordRange = wordRange(at: sel.location, in: textView.string) {
                    cursors = [MultiCursor(position: wordRange.location + wordRange.length, selection: wordRange)]
                    applyCursorsToTextView(textView)
                    return
                }
            }
        } else {
            return
        }

        guard let regex = buildOccurrenceRegex(for: term, caseSensitive: caseSensitive, wholeWord: wholeWord) else { return }

        let nsText = textView.string as NSString
        let lastPosition = cursors.last.map { cursor -> Int in
            if let sel = cursor.selection {
                return sel.location + sel.length
            }
            return cursor.position
        } ?? 0

        // Search forward from the last cursor position.
        let forwardRange = NSRange(location: lastPosition, length: nsText.length - lastPosition)
        if let match = regex.firstMatch(in: textView.string, range: forwardRange) {
            let range = match.range
            cursors.append(MultiCursor(position: range.location + range.length, selection: range))
            mergeCursors()
            applyCursorsToTextView(textView)
            return
        }

        // Wrap around: search from beginning to the first cursor position.
        let firstPosition = cursors.first.map { cursor -> Int in
            cursor.selection?.location ?? cursor.position
        } ?? 0
        if firstPosition > 0 {
            let wrapRange = NSRange(location: 0, length: firstPosition)
            if let match = regex.firstMatch(in: textView.string, range: wrapRange) {
                let range = match.range
                cursors.append(MultiCursor(position: range.location + range.length, selection: range))
                mergeCursors()
                applyCursorsToTextView(textView)
            }
        }
    }

    /// Removes the most recently added cursor and selects the next occurrence.
    ///
    /// This is equivalent to "skip": the user wants to ignore the last match
    /// but continue selecting the next one. The search continues from the
    /// position of the removed cursor, not from the new last cursor.
    ///
    /// - Parameter textView: The text view to operate on.
    public func skipAndSelectNext(in textView: NSTextView) {
        guard cursors.count > 1 else {
            // If only one cursor, just move to the next occurrence.
            selectNextOccurrence(in: textView)
            return
        }

        let removed = cursors.removeLast()

        // Search from where the removed cursor ended, not the new last cursor.
        guard let term = currentSearchTerm,
              let regex = buildOccurrenceRegex(for: term, caseSensitive: false, wholeWord: true)
        else { return }

        let nsText = textView.string as NSString
        let searchStart: Int
        if let sel = removed.selection {
            searchStart = sel.location + sel.length
        } else {
            searchStart = removed.position
        }

        // Search forward from the removed cursor's end position.
        let forwardRange = NSRange(location: searchStart, length: nsText.length - searchStart)
        if let match = regex.firstMatch(in: textView.string, range: forwardRange) {
            let range = match.range
            cursors.append(MultiCursor(position: range.location + range.length, selection: range))
            mergeCursors()
            applyCursorsToTextView(textView)
            return
        }

        // Wrap around: search from beginning up to the first cursor.
        let firstPosition = cursors.first.map { cursor -> Int in
            cursor.selection?.location ?? cursor.position
        } ?? 0
        if firstPosition > 0 {
            let wrapRange = NSRange(location: 0, length: firstPosition)
            if let match = regex.firstMatch(in: textView.string, range: wrapRange) {
                let range = match.range
                cursors.append(MultiCursor(position: range.location + range.length, selection: range))
                mergeCursors()
                applyCursorsToTextView(textView)
            }
        }
    }

    /// Removes the most recently added cursor, keeping at least one cursor.
    ///
    /// If only a single cursor exists the method does nothing.
    public func undoLastSelection() {
        guard cursors.count > 1 else { return }
        cursors.removeLast()
        if let textView = self.textView {
            applyCursorsToTextView(textView)
        }
    }

    // MARK: - Private Helpers (Occurrence)

    /// Resolves the search term from the current selection or the word under cursor.
    private func resolveSearchTerm(in textView: NSTextView) -> String? {
        let selectedRange = textView.selectedRange()
        let nsText = textView.string as NSString

        if selectedRange.length > 0,
           selectedRange.location + selectedRange.length <= nsText.length {
            return nsText.substring(with: selectedRange)
        }

        // No selection — find the word under cursor.
        return wordRange(at: selectedRange.location, in: textView.string)
            .map { nsText.substring(with: $0) }
    }

    /// Returns the NSRange of the word at the given character offset,
    /// or `nil` if the position is not within a word.
    private func wordRange(at position: Int, in text: String) -> NSRange? {
        let nsText = text as NSString
        guard position >= 0, position <= nsText.length else { return nil }

        // Use NSString's word-detection via enumerateSubstrings.
        var result: NSRange?
        let searchPos = min(position, max(nsText.length - 1, 0))
        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: .byWords
        ) { _, substringRange, _, stop in
            if substringRange.location <= searchPos
                && substringRange.location + substringRange.length > searchPos {
                result = substringRange
                stop.pointee = true
            } else if substringRange.location > searchPos {
                stop.pointee = true
            }
        }
        return result
    }

    /// Builds a regular expression for occurrence matching.
    private func buildOccurrenceRegex(
        for term: String,
        caseSensitive: Bool,
        wholeWord: Bool
    ) -> NSRegularExpression? {
        var pattern = NSRegularExpression.escapedPattern(for: term)
        if wholeWord {
            pattern = "\\b\(pattern)\\b"
        }
        var options: NSRegularExpression.Options = []
        if !caseSensitive {
            options.insert(.caseInsensitive)
        }
        return try? NSRegularExpression(pattern: pattern, options: options)
    }

    // MARK: - Private Helpers

    /// Sorts cursors by position and merges any that overlap or occupy the
    /// same location.
    ///
    /// Two cursors are considered overlapping when the effective range of one
    /// (its selection, or its bare position) touches or intersects the other.
    private func mergeCursors() {
        guard cursors.count > 1 else { return }

        cursors.sort { $0.position < $1.position }

        var merged: [MultiCursor] = [cursors[0]]

        for i in 1..<cursors.count {
            let current = cursors[i]
            let last = merged[merged.count - 1]

            let lastEnd = last.selection.map { $0.location + $0.length } ?? last.position
            let currentStart = current.selection?.location ?? current.position

            if currentStart <= lastEnd {
                // Ranges overlap or are adjacent — merge into one cursor.
                let mergedStart = min(
                    last.selection?.location ?? last.position,
                    current.selection?.location ?? current.position
                )
                let mergedEnd = max(
                    lastEnd,
                    current.selection.map { $0.location + $0.length } ?? current.position
                )

                var mergedSelection: NSRange?
                if mergedEnd - mergedStart > 0 {
                    mergedSelection = NSRange(location: mergedStart, length: mergedEnd - mergedStart)
                }

                merged[merged.count - 1] = MultiCursor(
                    position: mergedEnd,
                    selection: mergedSelection
                )
            } else {
                merged.append(current)
            }
        }

        cursors = merged
    }

    /// Shifts all cursor positions that come after a given offset by a delta.
    ///
    /// Used internally to keep cursor positions consistent after a text edit
    /// modifies the document at a single point.
    ///
    /// - Parameters:
    ///   - offset: Character position at which the edit occurred.
    ///   - delta: Number of characters inserted (positive) or deleted (negative).
    private func adjustPositions(after offset: Int, by delta: Int) {
        for index in cursors.indices {
            if cursors[index].position > offset {
                cursors[index].position = max(0, cursors[index].position + delta)
            }

            if let sel = cursors[index].selection {
                if sel.location >= offset {
                    let newLocation = max(0, sel.location + delta)
                    cursors[index].selection = NSRange(
                        location: newLocation,
                        length: sel.length
                    )
                } else if sel.location + sel.length > offset {
                    let newLength = max(0, sel.length + delta)
                    cursors[index].selection = NSRange(
                        location: sel.location,
                        length: newLength
                    )
                }
            }
        }
    }

    /// Recalculates cursor positions after inserting text at all cursors.
    private func recalculatePositionsAfterInsert(insertLength: Int) {
        cursors.sort { $0.position < $1.position }

        var cumulativeDelta = 0
        for index in cursors.indices {
            let selectionLength = cursors[index].selection?.length ?? 0
            let delta = insertLength - selectionLength

            cursors[index].position = cursors[index].position + cumulativeDelta + delta
            cursors[index].selection = nil
            cumulativeDelta += delta
        }

        mergeCursors()
    }

    /// Recalculates cursor positions after deleting at all cursors.
    private func recalculatePositionsAfterDelete() {
        cursors.sort { $0.position < $1.position }

        var cumulativeDelta = 0
        for index in cursors.indices {
            let deleteLength: Int
            if let selection = cursors[index].selection, selection.length > 0 {
                deleteLength = selection.length
            } else if cursors[index].position > 0 {
                deleteLength = 1
            } else {
                deleteLength = 0
            }

            cursors[index].position = max(0, cursors[index].position + cumulativeDelta - deleteLength)
            cursors[index].selection = nil
            cumulativeDelta -= deleteLength
        }

        mergeCursors()
    }

    /// Handles an Option-Drag event to produce a column selection by
    /// converting the drag point into line/column coordinates and delegating
    /// to ``selectColumnBlock(fromLine:toLine:fromColumn:toColumn:in:)``.
    private func handleColumnDrag(at point: NSPoint, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else { return }

        let charIndex = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        let text = textView.string
        let nsText = text as NSString
        let clampedIndex = min(charIndex, nsText.length)

        let dragPosition = text.textPosition(
            at: text.stringIndex(fromUTF16Offset: clampedIndex) ?? text.endIndex
        )

        // Use the primary cursor as the anchor point for the block selection.
        let anchor: TextPosition
        if let primary = cursors.first {
            let anchorIndex = min(primary.position, nsText.length)
            anchor = text.textPosition(
                at: text.stringIndex(fromUTF16Offset: anchorIndex) ?? text.startIndex
            )
        } else {
            anchor = TextPosition(line: 0, column: 0)
        }

        selectColumnBlock(
            fromLine: anchor.line,
            toLine: dragPosition.line,
            fromColumn: anchor.column,
            toColumn: dragPosition.column,
            in: text
        )

        applyCursorsToTextView(textView)
    }

    /// Applies the current cursor state to the text view by setting its
    /// selected ranges to match all active cursors.
    private func applyCursorsToTextView(_ textView: NSTextView) {
        guard !cursors.isEmpty else { return }

        let ranges: [NSValue] = cursors.map { cursor in
            if let selection = cursor.selection {
                return NSValue(range: selection)
            }
            return NSValue(range: NSRange(location: cursor.position, length: 0))
        }

        textView.setSelectedRanges(ranges, affinity: .downstream, stillSelecting: false)
    }
}
