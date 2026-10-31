struct CameraLifecycleGeneration {
    private(set) var value: UInt64 = 0

    mutating func begin() -> UInt64 {
        value &+= 1
        return value
    }

    mutating func invalidate() -> UInt64 {
        value &+= 1
        return value
    }

    func isCurrent(_ generation: UInt64) -> Bool {
        value == generation
    }
}
