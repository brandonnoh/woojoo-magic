# Rust Standards (Silicon Valley 2026)

> 공통 원칙은 ../common/HIGH_QUALITY_CODE_STANDARDS.md 참조. 이 문서는 Rust 전용 규칙.

---

## 1. 툴체인

| 도구 | 설정 | 용도 |
|------|------|------|
| `cargo clippy` | `-D warnings` | 린트 — 경고 0 정책 |
| `cargo fmt` | 기본 설정 | 포맷 통일 |
| `cargo audit` | CI 필수 | 취약점 탐지 |
| `cargo deny` | `advisories + licenses` | 라이선스/보안 게이트 |
| `miri` | unsafe 코드 존재 시 | 정의되지 않은 동작 탐지 |

```bash
cargo clippy -- -D warnings && cargo fmt --check && cargo audit && cargo deny check
```

---

## 2. 에러 처리

- 모든 실패 가능 함수는 `Result<T, E>` 반환 필수.
- `unwrap()` / 메시지 없는 `expect()` 금지 (테스트 모듈 제외).
- `?` 연산자로 전파. 중첩 `match` 금지.
- **라이브러리** → `thiserror` (구조화된 에러 enum). **애플리케이션** → `anyhow`.

```rust
#[derive(Debug, thiserror::Error)]
pub enum OrderError {
    #[error("invalid quantity: {0}")]
    InvalidQuantity(u32),
    #[error("payment failed")]
    PaymentFailed(#[from] PaymentError),
}

fn process_order(input: &OrderInput) -> Result<Order, OrderError> {
    validate(input)?;
    charge_payment(input)?;
    Ok(build_order(input))
}
```

---

## 3. Ownership & Lifetimes

- borrow checker를 우회하지 말고 설계를 수정한다.
- `clone()` 남용 금지 — 성능 병목. 필요 시 주석으로 사유 명시.
- lifetime 명시는 최소화 — elision 규칙이 커버하면 생략.
- `Arc<Mutex<T>>` 최소화 — channel 또는 설계 변경 우선.

```rust
// ❌ let data = expensive_data.clone(); process(&data);
// ✅ process(&expensive_data);
```

---

## 4. 타입 설계

- **newtype pattern** — 원시 타입 직접 사용 금지. 도메인 의미 부여.
- **enum (ADT)** — 상태 머신, 분기 로직에 적극 활용.
- `impl From/Into` — 타입 간 변환 명시.
- **builder pattern** — 필드 4개 이상 struct에 적용.

```rust
struct UserId(String);   // newtype — 컴파일 타임 도메인 구분
struct OrderId(uuid::Uuid);

enum OrderStatus {       // ADT — 상태 모델링
    Draft,
    Pending { submitted_at: Instant },
    Completed { completed_by: UserId },
}
```

---

## 5. 함수 설계

- **40줄 제한**. 초과 시 하위 함수 추출.
- generic bounds가 길면 `where` 절 사용.
- 반환 타입이 하나의 호출자 → `impl Trait`. 여러 곳 → 명시적 generic.

```rust
// ❌ 인라인 bounds — 가독성 저하
fn send<T: Serialize + Send + Sync + 'static>(msg: T) -> Result<()> { ... }

// ✅ where 절
fn send<T>(msg: T) -> Result<()>
where
    T: Serialize + Send + Sync + 'static,
{ ... }
```

---

## 6. unsafe

- **최소화** — 안전한 대안이 존재하면 사용 금지.
- 모든 `unsafe` 블록에 `// SAFETY:` 사유 주석 필수.
- unsafe 범위는 최소 — 필요한 연산만 포함.
- FFI 경계에서만 허용. 순수 Rust 로직에서는 금지.

```rust
// SAFETY: C 라이브러리가 null-terminated string을 보장.
let name = unsafe { CStr::from_ptr(ffi_get_name()) };
```

---

## 7. 동시성

- `tokio` + `async/await` 표준 사용.
- `Send + Sync` trait bound 이해 필수 — async 반환값은 자동 요구.
- `Arc<Mutex>` 보다 channel (`mpsc`, `broadcast`) 우선.
- async 함수 크기 주의 — Future가 stack 할당. 큰 로컬 변수는 `Box::pin`.

```rust
let (tx, mut rx) = tokio::sync::mpsc::channel(32);
tokio::spawn(async move {
    while let Some(msg) = rx.recv().await {
        handle(msg).await?;
    }
    Ok::<_, anyhow::Error>(())
});
```

---

## 8. 테스트

- 단위 테스트: `#[cfg(test)] mod tests` — 동일 파일 하단.
- 통합 테스트: `tests/` 디렉토리.
- 속성 기반 테스트: `proptest` — 경계값 자동 탐색.
- 벤치마크: `criterion` — 성능 회귀 감지.
- 커버리지 80%+ (`cargo llvm-cov`).

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_zero_quantity() {
        let input = OrderInput { quantity: 0, .. };
        assert!(matches!(
            process_order(&input),
            Err(OrderError::InvalidQuantity(0))
        ));
    }
}
```

---

## 9. 금지 목록

| 금지 항목 | 사유 | 대안 |
|-----------|------|------|
| `unwrap()` | 런타임 패닉 | `?` 또는 `unwrap_or` |
| 메시지 없는 `expect()` | 디버깅 불가 | `expect("context msg")` |
| 주석 없는 `unsafe` | 안전성 검증 불가 | `// SAFETY:` 필수 |
| 성능 회피용 `clone()` | 숨겨진 비용 | 참조/lifetime 재설계 |
| 사유 없는 `#[allow(clippy::...)]` | 린트 무력화 | `// Reason:` 주석 필수 |
| 무분별한 `pub` | 캡슐화 파괴 | `pub(crate)` 또는 private |

---

## 10. 코드 리뷰 체크리스트

### 안전성
- [ ] `unwrap()` 0개 (테스트 제외)
- [ ] `unsafe` 블록마다 `// SAFETY:` 주석 존재
- [ ] `clone()` 사용처마다 사유 명시 또는 참조로 대체

### 타입 설계
- [ ] 원시 타입 직접 사용 없음 — newtype 적용
- [ ] 상태 분기는 enum ADT로 모델링
- [ ] 에러는 `Result<T, E>` 반환 — custom error enum 또는 anyhow

### 구조
- [ ] 파일 500줄 이하
- [ ] 함수 40줄 이하
- [ ] `pub` 최소화 — 외부 API만 공개

### 동시성
- [ ] `Arc<Mutex>` 사용 시 channel 대안 검토 완료
- [ ] async 함수 Future 크기 확인

### 빌드
- [ ] `cargo clippy -- -D warnings` 통과
- [ ] `cargo fmt --check` 통과
- [ ] `cargo test` 통과
- [ ] `cargo audit` 경고 0개
