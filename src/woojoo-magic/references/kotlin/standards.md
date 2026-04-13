# Kotlin Standards (Silicon Valley 2026)

> 공통 원칙은 ../common/HIGH_QUALITY_CODE_STANDARDS.md 참조. 이 문서는 Kotlin 전용 규칙.

**Hard Limits:** 파일 400줄 / 함수 30줄 / `!!` 금지 / `Any` 금지 / `var` 최소화

---

## 1. 툴체인

| 도구 | 용도 | 설정 |
|------|------|------|
| **detekt** | 정적 분석 | `maxIssues: 0`, complexity threshold 10 |
| **ktlint** | 코드 포맷 | Kotlin official style, CI 필수 |
| **Kotlin compiler** | strict mode | `-Werror`, `-Xjsr305=strict`, `-Xexplicit-api=strict` |
| **kover** | 커버리지 | 80%+ line coverage, PR gate |

---

## 2. Null 안전성

`!!` 연산자 전면 금지. 대안 패턴만 허용.

```kotlin
val name = user?.name ?: "Unknown"                              // ?. + ?:
val id = requireNotNull(user?.id) { "User ID must exist" }     // requireNotNull
user?.let { sendEmail(it) }                                     // ?.let

// Platform types -> 즉시 nullable 명시
val javaResult: String? = JavaLib.getValue()  // String! -> String?
```

- `Any` 타입 파라미터 금지 -- 구체 타입 또는 제네릭 사용
- `as` 캐스트 최소화 -- `is` 스마트 캐스트 또는 sealed class 활용

---

## 3. 타입 설계

ADT를 적극 활용하여 상태를 컴파일 타임에 검증.

```kotlin
data class Order(val id: OrderId, val items: List<Item>, val status: OrderStatus) // 불변

sealed interface OrderStatus {                    // exhaustive when 강제
    data object Draft : OrderStatus
    data class Pending(val submittedAt: Instant) : OrderStatus
    data class Completed(val completedBy: UserId) : OrderStatus
}

@JvmInline value class UserId(val value: String)  // Branded Type, zero overhead
@JvmInline value class Money(val cents: Long) { init { require(cents >= 0) } }
enum class Role { ADMIN, MEMBER, GUEST }           // 유한 상태
```

- `when` + sealed class에 `else` 분기 금지 (exhaustive check 활용)

---

## 4. 에러 처리

예외 대신 `Result<T>` / sealed error로 명시적 에러 전파.

```kotlin
fun fetchUser(id: UserId): Result<User> = runCatching { api.getUser(id.value) }

sealed interface OrderError {
    data class NotFound(val id: OrderId) : OrderError
    data class InvalidTransition(val from: OrderStatus, val to: OrderStatus) : OrderError
}
fun processOrder(order: Order): Either<OrderError, Order> { /* ... */ }
```

- `catch {}` 빈 블록 금지 -- 최소 로깅 필수
- `Exception` 직접 throw 금지 -- 도메인 sealed error 또는 `Result` 사용

---

## 5. 함수 설계

| 제한 | 값 | 초과 시 |
|------|-----|---------|
| 함수 본문 | **30줄** | 하위 함수 추출 |
| 매개변수 | **5개** | data class로 묶기 |
| 중첩 깊이 | **3단** | 가드 클로즈 + 함수 분리 |

```kotlin
fun User.toDisplayName(): String = "$firstName ${lastName.first()}."  // extension
data class CreateOrderRequest(val userId: UserId, val items: List<Item>, val coupon: Coupon?)
fun createOrder(req: CreateOrderRequest): Result<Order> { /* ... */ }
```

- scope functions (`let`/`run`/`apply`) 남용 금지 -- 단일 목적, 체이닝 2단 이하
- 가드 클로즈 (early return) 우선

---

## 6. 동시성

Kotlin Coroutines + structured concurrency 필수. 스레드 직접 관리 금지.

```kotlin
suspend fun loadDashboard(): Dashboard = coroutineScope {
    val user = async { userRepo.get(userId) }
    val stats = async { statsRepo.get(userId) }
    Dashboard(user.await(), stats.await())
}
suspend fun saveFile(data: ByteArray) = withContext(Dispatchers.IO) { file.writeBytes(data) }
suspend fun batchProcess(items: List<Item>) = supervisorScope {
    items.map { launch { process(it) } }
}
```

- `GlobalScope` 금지 -- 항상 구조화된 스코프
- `Thread.sleep` 금지 -- `delay` 사용
- Flow 수집: `lifecycle.repeatOnLifecycle` (Android) 또는 구조화된 스코프

---

## 7. Android / Compose

Compose 함수는 UI 선언 전용 (100줄 이하). 로직은 ViewModel로 분리.

```kotlin
@Composable
fun OrderScreen(state: OrderUiState, onAction: (OrderAction) -> Unit) { /* UI only */ }
val filtered = remember(items, filter) { items.filter { it.matches(filter) } }
val total by remember { derivedStateOf { filtered.sumOf { it.price } } }
```

- ViewModel = UI 로직만. 도메인 로직은 UseCase/Repository 위임
- `LaunchedEffect` 키 관리 철저. `StateFlow` + `collectAsStateWithLifecycle` 권장

---

## 8. 테스트

JUnit5 + MockK + Turbine (Flow) + kotest (property-based) + kover (커버리지 80%+)

```kotlin
@Test fun `order not found returns error`() = runTest {
    coEvery { repo.findById(any()) } returns null
    useCase.execute(OrderId("x")).shouldBeInstanceOf<Either.Left<OrderError.NotFound>>()
}
@Test fun `flow emits loading then success`() = runTest {
    viewModel.state.test {
        awaitItem() shouldBe UiState.Loading
        awaitItem().shouldBeInstanceOf<UiState.Success>()
    }
}
```

---

## 9. 금지 목록

| 금지 항목 | 대안 |
|-----------|------|
| `!!` | `?.` / `?:` / `requireNotNull` |
| `Any` 파라미터 | 제네릭 `<T>` 또는 sealed interface |
| `var` (불필요 시) | `val` + 불변 업데이트 |
| `GlobalScope` | `coroutineScope` / `viewModelScope` |
| `Thread.sleep` | `delay` |
| `@Suppress` / `//noinspection` (사유 없음) | 사유 주석 필수 또는 근본 수정 |
| mutable collection (불필요 시) | `List` / `Set` / `Map` (immutable) |

---

## 10. 코드 리뷰 체크리스트

### Null / 타입 안전성
- [ ] `!!` 사용 0개
- [ ] Platform types 즉시 nullable 명시
- [ ] `Any` 타입 파라미터 0개
- [ ] 상태는 sealed class/interface 모델링
- [ ] 도메인 식별자는 value class
- [ ] `when` + sealed class에 `else` 없음

### 구조
- [ ] 파일 400줄 이하
- [ ] 함수 30줄 이하
- [ ] 매개변수 5개 이하
- [ ] 중첩 3단 이하

### 에러 / 동시성
- [ ] 빈 `catch {}` 0개
- [ ] 도메인 에러는 sealed class 또는 `Result`
- [ ] `GlobalScope` / `Thread.sleep` 0개
- [ ] structured concurrency 준수

### 불변성
- [ ] 불필요한 `var` 0개
- [ ] mutable collection 정당한 사유 있음

### 테스트 / 빌드
- [ ] 새 로직 -> 테스트 추가
- [ ] `./gradlew build` 통과
- [ ] `./gradlew detekt` 통과
- [ ] 커버리지 80%+
