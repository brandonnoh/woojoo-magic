# Model Definition Rules

## Rule 1-1: Shared Models — Single Definition Only

Same DB table/API endpoint = same struct. No platform prefixes.

```swift
// Shared/DTOs/Rows/DailyStatsRow.swift
struct DailyStatsRow: Codable, Sendable {
    let userId: String?
    let deviceId: String
    let dateKey: String
    let focused: Int
    let duration: Int
    let sessions: Int
    let hourly: [String: Int]

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case deviceId = "device_id"
        case dateKey = "date_key"
        case focused, duration, sessions, hourly
    }
}

// Platform-specific logic via extension
// iOS/Extensions/DailyStatsRow+iOS.swift
extension DailyStatsRow {
    var isFromThisDevice: Bool {
        deviceId == UIDevice.current.identifierForVendor?.uuidString
    }
}
```

## Rule 1-2: DTO vs Domain Model Separation

```
Shared/
├── Models/          ← Domain models (app internal logic)
│   ├── DailyStat.swift
│   └── SummaryStat.swift
├── DTOs/            ← Serialization models (API/DB only)
│   ├── Rows/        ← SELECT results (Decodable)
│   │   ├── DailyStatsRow.swift
│   │   └── MonthlyStatsRow.swift
│   └── Params/      ← RPC/POST params (Encodable)
│       ├── DailyStatParam.swift
│       └── SnapshotUploadParams.swift
└── Converters/      ← Row ↔ Model conversion
    └── CloudDataConverter.swift
```

DTO changes should never propagate to UI. Domain model changes should never break serialization.

## Rule 1-3: Dead Models — Delete Immediately

After migration (e.g., Firestore → Supabase), unused models must be deleted on discovery.

- Search: `grep -rn "ModelName" --include="*.swift"` → 0 results = delete
- `// TODO: delete` comments survive forever — don't use them
- Git history preserves everything — deletion is safe

## Recommended Directory Template

```
Shared/
├── Models/
├── DTOs/
│   ├── Rows/
│   └── Params/
├── Converters/
├── Sync/
│   ├── AggregationPolicy.swift
│   └── RetryPolicy.swift
├── Network/
│   └── JSONConfig.swift
├── Widget/
│   └── WidgetData.swift
├── Constants/
│   └── SharedConstants.swift
└── Logger/
    └── AppLogger.swift
```
