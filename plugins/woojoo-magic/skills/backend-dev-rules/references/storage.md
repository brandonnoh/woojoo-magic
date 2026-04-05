# Storage Rules

## Rule 5-1: Atomic Storage for Related Data

```swift
// ❌ Multiple keys — partial save on crash
defaults.set(focusedMinutes, forKey: "today_focused")
defaults.set(sessionCount, forKey: "today_sessions")
defaults.set(streakDays, forKey: "streak")
// App crashes here → streak saved, isPro not saved

// ✅ Single struct, single key — all or nothing
let data = WidgetData(focused: ..., sessions: ..., streak: ..., isPro: ...)
defaults.set(try JSONConfig.encoder.encode(data), forKey: "widgetData")
```

## Rule 5-2: App-Widget Data Sharing Pattern

| Item | Rule |
|------|------|
| Storage | App Groups UserDefaults (all platforms) |
| Format | JSON-encoded single struct |
| Key naming | `"{platform}WidgetData"` |
| Write access | App only. Widget is read-only. |
| Refresh signal | `WidgetCenter.shared.reloadAllTimelines()` |

```swift
// Shared/Widget/WidgetBridge.swift
protocol WidgetBridge {
    associatedtype Data: Codable
    var storageKey: String { get }
    func save(_ data: Data)
    func load() -> Data?
}
```

Both platforms must use the same storage pattern. No asymmetric storage (JSON on one platform, scattered keys on another).

## Rule 5-3: Widget Refresh Intervals

| State | Interval | Trigger |
|-------|----------|---------|
| Active tracking | 15 seconds | Timer + pushWidgetData |
| App active (idle) | 15 minutes | Timeline fallback |
| App inactive | 60 minutes | Timeline fallback |
| Event occurred | Immediate | reloadAllTimelines() |

Excessive refresh wastes battery and WidgetKit budget.

## Rule 5-4: Migration Code Lifecycle

```swift
// ❌ Permanent migration code
func load() -> [Session] {
    if let data = loadFromFile() { return data }        // v3 current
    if let data = loadFromGroupContainer() { return data } // v2 (2024)
    if let data = loadFromUserDefaults() { return data }   // v1 (2023)
    return []
}

// ✅ One-time migration with version tracking
func load() -> [Session] {
    migrateIfNeeded()  // runs once, sets completion flag
    return loadFromFile() ?? []
}

/// @deprecated Remove in v3.0 (after 2024-06, v1 users at 0%)
private func migrateFromV1() { ... }
```

Tag migration code with target removal version. Track version adoption via analytics to know when safe to remove.
