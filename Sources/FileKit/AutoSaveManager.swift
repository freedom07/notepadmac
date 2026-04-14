import Foundation
import CommonKit

public class AutoSaveManager {
    public var interval: TimeInterval = 30 {
        didSet {
            if timer != nil { start() }
        }
    }
    public var isEnabled: Bool = true {
        didSet { if isEnabled { start() } else { stop() } }
    }
    private var timer: Timer?; public var onAutoSave: (() -> Void)?
    public init() {}
    public func start() {
        stop()
        guard isEnabled else { return }
        let createTimer = { [weak self] in
            guard let self = self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: self.interval, repeats: true) { [weak self] _ in
                self?.triggerSave()
            }
        }
        if Thread.isMainThread {
            createTimer()
        } else {
            DispatchQueue.main.async(execute: createTimer)
        }
    }
    public func stop() { timer?.invalidate(); timer = nil }
    public func triggerSave() { onAutoSave?() }
    deinit { stop() }
}
