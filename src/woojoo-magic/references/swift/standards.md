# Swift Standards (Silicon Valley 2026)

> 공통 원칙은 ../common/HIGH_QUALITY_CODE_STANDARDS.md 참조. 이 문서는 Swift 전용 규칙.

**Hard Limits:** 파일 400줄 / 함수 30줄 / force unwrap `!` 금지 / `Any` 금지

---

## 1. 툴체인

| 도구 | 용도 |
|------|------|
| **SwiftLint** | 스타일 + 린트 규칙 강제 |
| **SwiftFormat** | 자동 포매팅 (CI 필수) |
| **Xcode Strict Concurrency** | `SWIFT_STRICT_CONCURRENCY=complete` |
| **swift-testing** | 표준 테스트 프레임워크 (`@Test`, `#expect`) |

Swift 6+ language mode 활성화. SwiftLint + SwiftFormat pre-commit hook 필수.

---

## 2. Optional 안전성
```swift
// ❌ let name = user.name!
// ✅ guard let name = user.name else { return }
// ✅ let city = user.address?.city ?? "Unknown"

// ❌ func process(_ item: Any) -> Any
// ✅ func process<T: Processable>(_ item: T) -> T.Output
```

- force unwrap `!` 절대 금지. `guard let` / `if let` 필수.
- Optional chaining + nil coalescing 활용.
- `Any` / `AnyObject` 금지 — 제네릭 또는 프로토콜 사용.

---

## 3. 타입 설계

- **struct 우선.** class는 참조 의미론이 필요한 경우만.
- **enum + associated values** 로 상태 모델링 (ADT).
- **Protocol-oriented design.** 기본 구현은 extension.
- **Sendable** conformance 필수 — 모든 공유 타입.

```swift
enum LoadState<T: Sendable>: Sendable {
    case idle, loading, loaded(T), failed(Error)
}

protocol Repository {
    associatedtype Entity: Identifiable & Sendable
    func fetch(id: Entity.ID) async throws -> Entity
}
```

---

## 4. 에러 처리

- **typed throws** (Swift 6+) 우선. `try?` 남용 금지 (에러 삼킴).
- 모든 도메인에 **custom Error** 타입 정의. `Result<T, E>` 는 async 불가 경계에서만.
```swift
// ✅ typed throws
func parse(_ input: String) throws(ParseError) -> AST {
    guard !input.isEmpty else { throw .emptyInput }
    return try tokenize(input)
}

// ✅ custom Error
enum OrderError: Error, LocalizedError {
    case invalidQuantity(Int)
    case paymentDeclined(reason: String)
    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let q): "Invalid quantity: \(q)"
        case .paymentDeclined(let r): "Payment declined: \(r)"
        }
    }
}
```

---

## 5. 동시성

- **async/await** 기본. completion handler 금지 (신규 코드).
- **actor** 로 mutable shared state 격리. **`@Sendable`** closure 준수.
- **`@MainActor`** for UI — UIKit/SwiftUI 모두.
```swift
actor CartStore {
    private var items: [CartItem] = []
    func add(_ item: CartItem) { items.append(item) }
    func total() -> Decimal { items.reduce(0) { $0 + $1.price } }
}

// structured concurrency
func loadDashboard() async throws -> Dashboard {
    async let profile = fetchProfile()
    async let orders = fetchOrders()
    return try await Dashboard(profile: profile, orders: orders)
}
```

---

## 6. SwiftUI

| 규칙 | 제한 |
|------|------|
| View body | **100줄 이하** |
| 반복 modifier | **ViewModifier 추출** |
| 상태 관리 | **@Observable** (Swift 5.9+) |
| 환경 객체 | 남용 금지 — 명시적 주입 우선 |
| Preview | **모든 View에 필수** |

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding().background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@Observable final class ProfileViewModel {
    var name = ""
    var isLoading = false
}
```

---

## 7. 테스트

- **swift-testing** (`@Test`, `#expect`) — 단위/통합 테스트.
- **XCTest** — UI 테스트만. Mock = protocol. **커버리지 80%+.**

```swift
@Test("유효하지 않은 수량은 에러를 던진다")
func invalidQuantityThrows() async throws {
    let sut = OrderService(repo: MockOrderRepo())
    #expect(throws: OrderError.invalidQuantity(-1)) {
        try sut.place(quantity: -1)
    }
}
```

---

## 8. 금지 목록

| 항목 | 이유 |
|------|------|
| `!` force unwrap | 런타임 크래시 |
| `Any` / `AnyObject` | 타입 안전성 파괴 |
| Implicitly unwrapped optionals | `@IBOutlet` 제외 전면 금지 |
| `try!` / `as!` | 복구 불가 크래시 |
| Global mutable state | data race + 테스트 불가 |
| `//swiftlint:disable` (사유 없이) | 반드시 사유 주석 필수 |

---

## 9. 검증 명령어

```bash
swift build
swift test
swiftlint --strict
```

---

## 10. 코드 리뷰 체크리스트

### 타입 안전성
- [ ] force unwrap `!` 0개
- [ ] `Any` / `AnyObject` 0개
- [ ] `try!` / `as!` 0개
- [ ] 도메인 타입은 struct + Sendable

### 구조
- [ ] 파일 400줄 이하
- [ ] 함수 30줄 이하
- [ ] View body 100줄 이하
- [ ] Protocol-oriented (구체 타입 의존 최소화)

### 동시성
- [ ] strict concurrency 경고 0개
- [ ] actor 로 mutable shared state 격리
- [ ] `@MainActor` for UI 코드

### 에러 처리
- [ ] silent catch 0개
- [ ] typed throws 사용 (Swift 6+)
- [ ] custom Error 타입 정의

### 빌드
- [ ] `swift build` 통과
- [ ] `swift test` 통과
- [ ] `swiftlint --strict` 통과
