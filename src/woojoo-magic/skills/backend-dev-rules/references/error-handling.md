# Error Handling Rules

## Rule 6-1: Three-Tier Network Error Strategy

```
Tier 1: Retry (transient errors)
  → Timeouts, 5xx, network disconnection
  → RetryPolicy with exponential backoff
  → No user notification

Tier 2: Fallback (persistent errors)
  → Use cached data, switch to offline mode
  → Show "Displaying offline data" indicator

Tier 3: Display error (unrecoverable)
  → Auth expired, forbidden, bad request
  → Clear user action prompt (re-login, contact support)
```

## Rule 6-2: Unified Logging

```swift
// ❌ Inconsistent logging across platforms
// Platform A: print("[Sync] ❌ error") — leaks to production
// Platform B: #if DEBUG print(...) — debug only

// ✅ Unified os.Logger
import os

enum AppLogger {
    static let sync = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "sync")
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "auth")
    static let widget = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "widget")
}

// Usage
AppLogger.sync.error("Upload failed: \(error.localizedDescription)")
AppLogger.sync.debug("Snapshot uploaded: \(dateKey)")
```

os.Logger benefits:
- `.debug` auto-filtered in release builds
- Category-based filtering in Console.app
- Structured logging with privacy controls
- Zero overhead when disabled
