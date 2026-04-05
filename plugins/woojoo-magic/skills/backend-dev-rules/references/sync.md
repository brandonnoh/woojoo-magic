# Sync Rules

## Rule 4-1: Double-Counting Prevention — Single Implementation

Formula: `total = max(local, thisDeviceCloud) + otherDevices`

```swift
// Shared/Sync/AggregationPolicy.swift
enum AggregationPolicy {
    /// Merge local + cloud stats without double-counting
    /// - isTracking: true = skip thisDeviceCloud (local is more current)
    static func mergedTotal(
        local: Int,
        thisDeviceCloud: Int,
        otherDevices: Int,
        isTracking: Bool
    ) -> Int {
        let thisDevice = isTracking ? local : max(local, thisDeviceCloud)
        return thisDevice + otherDevices
    }
}
```

Every statistics calculation must call this function. Never inline the formula.

## Rule 4-2: Read-Only Clients — Explicit Protocol Declaration

```swift
protocol CloudReader {
    func fetchDailyStats() async throws -> [String: DailyStat]
    func fetchMonthlyStats() async throws -> [String: SummaryStat]
    func fetchLifetime() async throws -> SummaryStat
}

protocol CloudWriter: CloudReader {
    func uploadSnapshot(_ params: SnapshotParams) async throws
    func syncAchievements(_ params: [AchievementParam]) async throws
}

// macOS: CloudWriter (read + write)
// iOS: CloudReader only (read-only)
```

Never leave write methods unused in a read-only client. Use protocol separation.

## Rule 4-3: Unified Retry Logic

```swift
// Shared/Sync/RetryPolicy.swift
struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let multiplier: Double

    static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: 2.0, multiplier: 2.0)

    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do { return try await operation() }
            catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = baseDelay * pow(multiplier, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError!
    }
}
```

All platforms must use the same RetryPolicy. No platform should have "no retry at all" while another has exponential backoff.

## Rule 4-4: Realtime Self-Loop Prevention

When client uploads data, Realtime sends the event back to itself. Must be ignored.

```swift
class RealtimeCoordinator {
    private var isUploading = false
    private var lastUploadAt: Date = .distantPast
    private let cooldown: TimeInterval = 3.0  // must exceed max RTT

    var shouldIgnoreEvent: Bool {
        isUploading || Date().timeIntervalSince(lastUploadAt) < cooldown
    }

    func markUploadStarted() { isUploading = true }
    func markUploadCompleted() {
        isUploading = false
        lastUploadAt = Date()
    }
}
```

Cooldown must be: expected max network RTT + margin. If network latency > cooldown, self-events leak through.

## Rule 4-5: Debounce Realtime Events

Multiple row changes from one upload → multiple Realtime events. Debounce to single fetch.

```swift
// On Realtime event received:
realtimeDebounceTask?.cancel()
realtimeDebounceTask = Task {
    try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
    await fetchCloudData()
}
```
