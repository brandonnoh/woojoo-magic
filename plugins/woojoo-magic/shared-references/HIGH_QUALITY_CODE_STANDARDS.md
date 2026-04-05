# High-Quality Code Standards (v2)

## 용도
- 모든 woojoo-magic 스킬/에이전트가 참조하는 **최상위 품질 기준**
- 코드 작성 전, 리뷰 전, PR 제출 전 체크
- "리팩토링이 필요 없도록 처음부터 고품질로" — 실리콘밸리 수준

---

## 1. 파일 크기

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
// ❌ const hand = result.hand as EvaluatedHand;
// ✅ if (isEvaluatedHand(result.hand)) { ... }
```

### Non-null assertion (!) 금지
→ `NON_NULL_ELIMINATION.md` 참조

### Branded Types — 실전 사례
```typescript
// crypto-holdem에서 검증된 패턴
type PlayerId = string & { readonly __brand: 'PlayerId' };
type SessionId = string & { readonly __brand: 'SessionId' };
type ChipAmount = number & { readonly __brand: 'ChipAmount' };

// 팩토리 함수 — 경계점에서만 캐스트
export const asPlayerId = (value: string): PlayerId => value as PlayerId;
export const asChipAmount = (value: number): ChipAmount => {
  if (value < 0) throw new Error('ChipAmount cannot be negative');
  return value as ChipAmount;
};

// ❌ function transfer(from: string, to: string, amount: number)
// ✅ function transfer(from: PlayerId, to: PlayerId, amount: ChipAmount)
//    → 인자 순서 오류 컴파일 타임에 감지
```
→ `BRANDED_TYPES_PATTERN.md` 참조

### Discriminated Union
```typescript
type GamePhase =
  | { kind: 'idle' }
  | { kind: 'dealing'; startedAt: number }
  | { kind: 'betting'; currentPlayer: PlayerId }
  | { kind: 'showdown'; winners: PlayerId[] };
```
→ `DISCRIMINATED_UNION.md` 참조

---

## 3. 함수 설계

### 순수 함수 우선
- 입력 → 출력. 외부 상태 의존 금지.

### 매개변수 3개 이하
```typescript
// ❌ function create(a, b, c, d, e, f) {}
// ✅ function create(config: Config) {}
```

### 가드 클로즈 (얼리 리턴)
```typescript
function process(data: Data | null) {
  if (!data) return;
  if (!data.isValid) return;
  // 플랫한 로직
}
```

### 불변 업데이트
```typescript
// ❌ player.chips -= amount;
// ✅ const updated = { ...player, chips: player.chips - amount };
```

---

## 4. React

### 컴포넌트 = 조합
- God Component 금지. 100줄 이상 JSX → 서브 컴포넌트.
- 비즈니스 로직 인라인 금지 → 훅/유틸 추출.

### 훅 = 단일 책임
- `useEverything()` 금지. 훅 하나 = 도메인 하나.
- 반환값 5개 이하. 초과 시 객체 그룹핑.
- `useEffect` = 외부 시스템 동기화만. 파생 상태 → `useMemo`.

### "use" 접두사는 React 훅만
```typescript
// ❌ function usePotOddsText() { return `${x}%`; }
// ✅ function getPotOddsText() { return `${x}%`; }
```

### memo/useMemo/useCallback
- 리스트 아이템, 자주 리렌더 → `memo()`
- 비용 높은 계산 → `useMemo`
- 자식 전달 콜백 → `useCallback`

### CSS 매직 값 상수화
```typescript
// ❌ className="absolute -top-[2%] left-[9%]"
// ✅ const LAYOUT = { seat: 'absolute -top-[2%] left-[9%]' } as const;
```

---

## 5. 상태 관리

### Zustand 슬라이스 패턴
- 10개 이상 필드 → 도메인별 슬라이스 분리
- 셀렉터로 구독 범위 제한
- 대형 액션 → `actions/` 디렉토리로 분리
→ `ZUSTAND_SLICE_PATTERN.md` 참조

### wrapSetWithPhase 패턴 (무침습 DU 도입)
```typescript
// 기존 플랫 구조를 유지하면서 phase DU 자동 동기화
const setWithPhase = (partial: Partial<State>) => {
  set((state) => {
    const next = { ...state, ...partial };
    return { ...next, phase: derivePhase(next) };
  });
};
```
→ `DISCRIMINATED_UNION.md` 참조

### 서버 상태 신뢰
- 중복 계산 금지. 서버가 내려준 값을 그대로 사용.
- 클라이언트 보정 필요 시 어댑터 패턴 (`adapters.ts`).

---

## 6. 서버/클래스

### 클래스 = 얇은 facade
- 300줄 이하. 10개 이하 private 필드.
- 로직 → 위임 모듈. 클래스는 조합만.

### Guard Clause 패턴
```typescript
// ❌ non-null assertion 남용
handleAction(playerId: string) {
  this.gameManager!.currentState.players[playerId]!.chips -= 10;
}

// ✅ guard clause + 로컬 변수
handleAction(playerId: PlayerId) {
  const { gameManager } = this;
  if (!gameManager) throw new Error('GameManager not initialized');

  const player = gameManager.currentState.players[playerId];
  if (!player) throw new Error(`Player ${playerId} not found`);

  return { ...player, chips: player.chips - 10 };
}
```

### 에러 처리
- Silent catch 금지. 최소 로깅 + 사용자 피드백.

---

## 7. 성능

### CSS animation > JS animation
- 무한 반복 애니메이션 → CSS `@keyframes` + opacity/transform

### backdrop-blur 최소화
- 동시 3개 이하.

### filter 애니메이션 금지
- `brightness()`, `blur()` 애니메이션 → 매 프레임 리페인트.

---

## 8. DRY

- 같은 패턴 2곳 → 공통 유틸 추출
- 같은 패턴 3곳 → 반드시 추출 (리뷰 거부 사유)
- 공통 파이프라인: 변하는 부분만 config로 전달

---

## 9. 에러 처리 — Result<T, E> 패턴

```typescript
type Result<T, E = string> = { ok: true; value: T } | { ok: false; error: E };

// 엔진: throw 대신 Result 반환
function applyAction(state: GameState, action: Action): Result<GameState, ActionError> {
  if (!isValidAction(state, action)) return Err('INVALID_ACTION');
  return Ok(computeNextState(state, action));
}

// 클라이언트: tryAsync로 try/catch 통일
const result = await tryAsync(() => api.postAction(action));
if (!result.ok) {
  showToast(result.error);
  return;
}
useValue(result.value);
```
→ `RESULT_PATTERN.md` 참조

---

## 10. 리팩토링 방지 시그널

"이미 늦었다"는 신호를 코드 작성 중에 감지:

| 시그널 | 대응 |
|--------|------|
| 파일 200줄 돌파 | 즉시 분리 계획 수립 |
| 함수 3가지 책임 | SRP 위반 — 분할 |
| 같은 로직 2곳 | 즉시 유틸 추출 |
| Props 5개 초과 | 객체 그룹핑/Context |
| `as any`, `!` 등장 | 타입 설계 재고 |
| useEffect 3개 이상 | 훅 분리 |
| if/else 4단 중첩 | 가드 클로즈 + 함수 분리 |

→ `REFACTORING_PREVENTION.md` 참조

---

## 11. 코드 리뷰 체크리스트

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
- [ ] 클래스 private 필드 10개 이하

### 에러 처리
- [ ] Silent catch 0개
- [ ] 검증 실패 → Result 사용
- [ ] 사용자 피드백 존재 (토스트/모달)

### 중복/매직
- [ ] 중복 코드 없음 (2곳 이상 = 추출)
- [ ] 매직 넘버/문자열 → 상수
- [ ] CSS 매직 값 → `LAYOUT` 상수

### 테스트/빌드
- [ ] 새 로직 → 테스트 추가
- [ ] `pnpm turbo build` 통과
- [ ] `pnpm turbo test` 통과
- [ ] `pnpm turbo typecheck` 통과

### 리팩토링 방지
- [ ] 파일이 200줄 이상이면 분리 계획 있는가
- [ ] 같은 패턴 2곳 이상 존재하면 추출했는가
- [ ] useEffect가 파생 상태 계산 용도 아닌가
