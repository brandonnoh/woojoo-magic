# Serialization Rules

## Rule 2-1: snake_case via CodingKeys Only

Never use snake_case in Swift property names.

```swift
// ❌
struct DailyStatParam: Encodable {
    let date_key: String
    let p_device_id: String
}

// ✅
struct DailyStatParam: Encodable {
    let dateKey: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case dateKey = "date_key"
        case deviceId = "p_device_id"
    }
}
```

Alternative: project-wide `JSONEncoder().keyEncodingStrategy = .convertToSnakeCase`.

## Rule 2-2: Optional Types Must Match DB Schema

```swift
// ❌ Same column, different nullability across platforms
// Platform A
struct ProfileRow: Decodable { let isPro: Bool? }  // Optional
// Platform B
struct ProfileRow: Decodable { let isPro: Bool }    // Non-null

// ✅ Match DB constraint
// DB column: is_pro BOOLEAN NOT NULL DEFAULT false → Bool
// DB column: is_pro BOOLEAN → Bool?
```

Non-null decoding of a NULL column = runtime crash.

## Rule 2-3: Centralized Encoder/Decoder Configuration

```swift
// ❌ Creating new encoder per call with inconsistent settings
func save() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
}

// ✅ Singleton configuration
enum JSONConfig {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
```

Benefits: consistent date format, consistent key strategy, single place to update.
