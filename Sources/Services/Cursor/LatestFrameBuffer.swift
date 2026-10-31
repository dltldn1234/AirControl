import Foundation

final class LatestFrameBuffer<Value> {
    private let lock = NSLock()
    private var latestValue: Value?
    private var isDrainScheduled = false

    func offer(_ value: Value) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        latestValue = value
        guard !isDrainScheduled else { return false }
        isDrainScheduled = true
        return true
    }

    func take() -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let value = latestValue else {
            isDrainScheduled = false
            return nil
        }
        latestValue = nil
        return value
    }
}
