import Foundation

func waitUntil(
    timeout: TimeInterval = 2.0,
    interval: UInt64 = 50_000_000,
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if await condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: interval)
    }
    return false
}
