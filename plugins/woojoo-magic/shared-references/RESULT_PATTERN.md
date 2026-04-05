# Result<T, E> Pattern

## 용도
- `throw` 남용으로 인한 try/catch 산재를 제거
- 에러 가능성을 **타입 레벨**에 명시
- 엔진/서비스 레이어의 검증 실패 처리 표준화

---

## throw vs Result 비교

```typescript
// ❌ throw — 호출자가 에러 가능성을 알 수 없음
function applyBet(state: GameState, amount: number): GameState {
  if (amount < 0) throw new Error('Negative');
  if (amount > state.player.chips) throw new Error('Insufficient');
  return { ...state, pot: state.pot + amount };
}

// 호출자: try/catch 필수. 놓치면 앱 크래시.
try {
  const next = applyBet(state, amount);
} catch (e) {
  // e: unknown — 어떤 에러인지 타입으로 알 수 없음
}
```

```typescript
// ✅ Result — 타입이 에러 가능성 강제
type BetError = 'NEGATIVE' | 'INSUFFICIENT_CHIPS';

function applyBet(state: GameState, amount: ChipAmount): Result<GameState, BetError> {
  if (amount < 0) return Err('NEGATIVE');
  if (amount > state.player.chips) return Err('INSUFFICIENT_CHIPS');
  return Ok({ ...state, pot: asChipAmount(state.pot + amount) });
}

// 호출자: 타입 시스템이 처리 강제
const result = applyBet(state, amount);
if (!result.ok) {
  switch (result.error) {
    case 'NEGATIVE': return showToast('음수는 불가');
    case 'INSUFFICIENT_CHIPS': return showToast('칩 부족');
  }
}
const next = result.value; // 여기서만 value 접근 가능
```

---

## 기본 정의

```typescript
// shared/src/utils/result.ts
export type Result<T, E = string> =
  | { ok: true; value: T }
  | { ok: false; error: E };

export const Ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
export const Err = <E>(error: E): Result<never, E> => ({ ok: false, error });

// 유틸
export const isOk = <T, E>(r: Result<T, E>): r is { ok: true; value: T } => r.ok;
export const isErr = <T, E>(r: Result<T, E>): r is { ok: false; error: E } => !r.ok;

// map/flatMap
export function mapResult<T, U, E>(r: Result<T, E>, fn: (v: T) => U): Result<U, E> {
  return r.ok ? Ok(fn(r.value)) : r;
}

export function flatMapResult<T, U, E>(
  r: Result<T, E>,
  fn: (v: T) => Result<U, E>,
): Result<U, E> {
  return r.ok ? fn(r.value) : r;
}
```

---

## 엔진: throw → Result 전환

```typescript
// Before
export function applyAction(state: GameState, action: Action): GameState {
  if (state.currentPlayer !== action.playerId) throw new Error('NOT_YOUR_TURN');
  if (action.type === 'RAISE' && action.amount < state.minRaise) {
    throw new Error('RAISE_TOO_SMALL');
  }
  return computeNextState(state, action);
}

// After
export type ActionError =
  | 'NOT_YOUR_TURN'
  | 'RAISE_TOO_SMALL'
  | 'INSUFFICIENT_CHIPS'
  | 'INVALID_STAGE';

export function applyAction(
  state: GameState,
  action: Action,
): Result<GameState, ActionError> {
  if (state.currentPlayer !== action.playerId) return Err('NOT_YOUR_TURN');
  if (action.type === 'RAISE' && action.amount < state.minRaise) {
    return Err('RAISE_TOO_SMALL');
  }
  return Ok(computeNextState(state, action));
}
```

---

## 클라이언트: try/catch → tryAsync 통일

```typescript
// shared/src/utils/tryAsync.ts
export async function tryAsync<T>(
  fn: () => Promise<T>,
): Promise<Result<T, string>> {
  try {
    return Ok(await fn());
  } catch (error) {
    return Err(mapErrorToKey(error));
  }
}

function mapErrorToKey(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;
  return 'UNKNOWN_ERROR';
}
```

### 사용 예시

```typescript
// ❌ 기존 — try/catch 산재
async function handleJoinRoom(code: string) {
  try {
    setLoading(true);
    const room = await api.joinRoom(code);
    navigate(`/room/${room.id}`);
  } catch (e) {
    console.error(e);
    showToast('참가 실패');
  } finally {
    setLoading(false);
  }
}

// ✅ Result 패턴
async function handleJoinRoom(code: string) {
  setLoading(true);
  const result = await tryAsync(() => api.joinRoom(code));
  setLoading(false);

  if (!result.ok) {
    showToast(t(result.error)); // i18n 키로 바로 사용
    return;
  }

  navigate(`/room/${result.value.id}`);
}
```

---

## Result vs throw 선택 기준

| 상황 | 선택 | 이유 |
|------|------|------|
| 사용자 입력 검증 실패 | **Result** | 예상된 실패, 복구 가능 |
| 비즈니스 규칙 위반 | **Result** | 예상된 실패 |
| 네트워크 요청 실패 | **Result** (tryAsync) | 복구 가능 |
| null/undefined invariant | **throw** | 프로그래밍 에러 |
| 배열 인덱스 out-of-range | **throw** | 프로그래밍 에러 |
| 타입 가드 실패 (가정 위반) | **throw** | 프로그래밍 에러 |

**원칙**: "사용자가 고칠 수 있는가?" → Result. "개발자 버그인가?" → throw.

---

## 호출자 언래핑 패턴

### 체이닝
```typescript
const result = flatMapResult(
  validateInput(raw),
  (input) => flatMapResult(
    applyAction(state, input),
    (next) => persistState(next),
  ),
);
```

### 조기 반환 (권장)
```typescript
function handleTurn(raw: unknown): Result<GameState, Error> {
  const parsed = parseAction(raw);
  if (!parsed.ok) return parsed;

  const validated = validateAction(state, parsed.value);
  if (!validated.ok) return validated;

  return applyAction(state, validated.value);
}
```

### exhaustive switch
```typescript
if (!result.ok) {
  switch (result.error) {
    case 'NOT_YOUR_TURN': return showToast(t('turn.notYours'));
    case 'RAISE_TOO_SMALL': return showToast(t('bet.tooSmall'));
    case 'INSUFFICIENT_CHIPS': return showToast(t('chips.insufficient'));
    case 'INVALID_STAGE': return showToast(t('stage.invalid'));
    default: {
      const _exhaustive: never = result.error;
      return _exhaustive;
    }
  }
}
```

---

## 체크리스트

- [ ] 엔진 함수는 `throw` 대신 `Result` 반환하는가
- [ ] 에러 타입은 문자열 유니온(`'NOT_YOUR_TURN' | ...`)으로 좁혀져 있는가
- [ ] 클라이언트 API 호출은 `tryAsync`로 감쌌는가
- [ ] `if (!result.ok) return` 조기 반환 패턴을 쓰는가
- [ ] 에러 핸들링에 exhaustive switch가 있는가
- [ ] 프로그래밍 에러(invariant)는 여전히 `throw` 하는가
- [ ] 사용자에게 에러 메시지가 노출되는가 (silent fail 금지)
