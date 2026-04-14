// FileWatcher.swift
// FileKit – NotepadNext
//
// Watches a single file for filesystem changes using GCD dispatch sources.

import Foundation

// MARK: - FileChangeType

/// The kind of change observed on a watched file.
public enum FileChangeType: Sendable {
    /// The file's content was modified (write, extend, or attribute change).
    case modified
    /// The file was deleted or its link was removed.
    case deleted
    /// The file was renamed (moved).
    case renamed
}

// MARK: - FileWatcher

/// Observes a single file for changes using `DispatchSource.makeFileSystemObjectSource`.
///
/// Usage:
/// ```swift
/// let watcher = FileWatcher(url: fileURL) { change in
///     print("File changed:", change)
/// }
/// watcher.start()
/// ```
///
/// The watcher automatically stops and cleans up on `deinit`.
public final class FileWatcher {

    // MARK: - Properties

    /// The URL of the file being watched.
    public let url: URL

    /// The callback invoked on every observed change.
    /// Always dispatched on the internal monitoring queue.
    private let onChange: (FileChangeType) -> Void

    /// GCD dispatch source for vnode events.
    private var source: DispatchSourceFileSystemObject?

    /// File descriptor for the watched file.
    private var fileDescriptor: Int32 = -1

    /// Dedicated serial queue for monitoring callbacks.
    private let queue = DispatchQueue(label: "com.notepadnext.FileWatcher", qos: .utility)

    /// Guards start/stop from concurrent access.
    private let lock = NSLock()

    /// Whether the watcher is currently active.
    public private(set) var isRunning: Bool = false

    // MARK: - Initialisation

    /// Create a new file watcher.
    ///
    /// - Parameters:
    ///   - url: The file URL to watch. Must be a file URL.
    ///   - onChange: Callback invoked when the file changes. Delivered on an
    ///     internal serial queue — dispatch to main if UI updates are needed.
    public init(url: URL, onChange: @escaping (FileChangeType) -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Begin watching the file for changes.
    ///
    /// Does nothing if the watcher is already running.
    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isRunning else { return }

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let events: DispatchSource.FileSystemEvent = [.write, .delete, .rename, .extend, .attrib]
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: events,
            queue: queue
        )

        newSource.setEventHandler { [weak self] in
            self?.handleEvent()
        }

        newSource.setCancelHandler { [weak self] in
            self?.closeDescriptor()
        }

        source = newSource
        isRunning = true
        newSource.resume()
    }

    /// Stop watching the file and release system resources.
    ///
    /// Safe to call multiple times or when the watcher is not running.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }
        isRunning = false

        source?.cancel()
        source = nil
    }

    // MARK: - Private Helpers

    /// Translate dispatch source events into ``FileChangeType`` and invoke the
    /// callback.
    private func handleEvent() {
        guard let source = source else { return }

        let flags = source.data

        if flags.contains(.delete) {
            onChange(.deleted)
            // The file descriptor is stale after deletion; stop watching.
            stop()
            return
        }

        if flags.contains(.rename) {
            onChange(.renamed)
            return
        }

        if flags.contains(.write) || flags.contains(.extend) || flags.contains(.attrib) {
            onChange(.modified)
            return
        }
    }

    /// Close the file descriptor if it is still open.
    private func closeDescriptor() {
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }
}
