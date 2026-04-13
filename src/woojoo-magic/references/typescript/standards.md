#  TypeScript / JavaScript Standards

> 공통 원칙은 `HIGH_QUALITY_CODE_STANDARDS.md` 참조. 이 문서는 TS/JS 전용 규칙.

---

## 1. 파일/함수 크기 (Hard Limit)

| 대상 | 최대 | 초과 시 |
|------|------|---------|
| 소스 파일 | **300줄** | 무조건 분할 (SRP 기준) |
| 함수/메서드 | **20줄** | 하위 함수 추출 |
| 클래스 | **300줄** | 위임 객체 분리 |
| React JSX | **100줄** | 서브 컴포넌트 추출 |
| Props | **5개** | 객체 그룹핑 또는 Context |

---

## 2. 타입 시스템

### any 금지
```typescript
// ❌ const data: any = response.json();
// ✅ const data: unknown = await response.json();
```

### as 최소화 — 타입 가드 사용
```typescript
// ❌ const result = value as SpecificType;
// ✅ if (isSpecificType(value)) { ... }
```

### Non-null assertion (!) 금지
→ `../NON_NULL_ELIMINATION.md` 참조

### Branded Types
```typescript
type UserId = string & { readonly __brand: 'UserId' };
type Money = number & { readonly __brand: 'Money' };

export const asUserId = (value: string): UserId => value as UserId;
export const asMoney = (value: number): Money => {
  if (value < 0) throw new Error('Money cannot be negative');
  return value as Money;
};

// ✅ function transfer(from: UserId, to: UserId, amount: Money)
//    → 인자 순서 오류 컴파일 타임에 감지
```
→ `../BRANDED_TYPES_PATTERN.md` 참조

### Discriminated Union
```typescript
type OrderPhase =
  | { kind: 'draft' }
  | { kind: 'pending'; submittedAt: number }
  | { kind: 'processing'; assignee: UserId }
  | { kind: 'completed'; completedBy: UserId[] };
```
→ `../DISCRIMINATED_UNION.md` 참조

---

## 3. 함수 설계

- 순수 함수 우선. 외부 상태 의존 금지.
- 매개변수 3개 이하 (초과 시 config 객체)
- 가드 클로즈 (얼리 리턴)
- 불변 업데이트 (`{ ...obj, field: newValue }`)

---

## 4. React

- God Component 금지. 100줄 이상 JSX → 서브 컴포넌트
- 훅 = 단일 책임. 반환값 5개 이하
- `useEffect` = 외부 시스템 동기화만. 파생 상태 → `useMemo`
- "use" 접두사는 React 훅만 (`useFormattedPrice` ❌ → `formatPrice` ✅)
- 리스트 아이템/자주 리렌더 → `memo()`
- CSS 매직 값 → `LAYOUT` 상수

---

## 5. 상태 관리 (Zustand)

- 10개 이상 필드 → 도메인별 슬라이스 분리
- 셀렉터로 구독 범위 제한
- 대형 액션 → `actions/` 디렉토리
- `wrapSetWithPhase` 패턴 (무침습 DU)
→ `../ZUSTAND_SLICE_PATTERN.md`, `../DISCRIMINATED_UNION.md` 참조

---

## 6. 서버/클래스

- 클래스 = 얇은 facade (300줄 이하, private 필드 10개 이하)
- Guard Clause + 로컬 변수 (non-null assertion 제거)
- Silent catch 금지

---

## 7. 에러 처리 — Result<T, E>

```typescript
type Result<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

function processOrder(order: Order, input: OrderInput): Result<Order, OrderError> {
  if (!isValidInput(order, input)) return Err('INVALID_INPUT');
  return Ok(computeNextState(order, input));
}

const result = await tryAsync(() => api.createOrder(input));
if (!result.ok) {
  showToast(result.error);
  return;
}
```
→ `../RESULT_PATTERN.md` 참조

---

## 8. 성능

- CSS animation > JS animation (무한 반복은 `@keyframes`)
- `backdrop-blur` 동시 3개 이하
- `filter` 애니메이션 금지 (매 프레임 리페인트)

---

## 9. 검증 명령어

```bash
pnpm turbo build
pnpm turbo test
pnpm turbo typecheck
```

---

## 10. 코드 리뷰 체크리스트

### 타입 안전성
- [ ] `any` 0개
- [ ] `as` 최소화 (타입 가드 우선)
- [ ] `!` non-null assertion 0개
- [ ] 도메인 식별자는 Branded Type
- [ ] 상태는 DU로 모델링

### 구조
- [ ] 파일 300줄 이하
- [ ] 함수 20줄 이하
- [ ] Props 5개 이하
- [ ] 훅 반환값 5개 이하

### 에러 처리
- [ ] Silent catch 0개
- [ ] 검증 실패 → Result 사용
- [ ] 사용자 피드백 존재

### 빌드
- [ ] `pnpm turbo build` 통과
- [ ] `pnpm turbo test` 통과
- [ ] `pnpm turbo typecheck` 통과
