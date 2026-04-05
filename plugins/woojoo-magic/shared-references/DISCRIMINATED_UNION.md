# Discriminated Union Pattern

## 용도
- `status: string` + 플랫 필드로 상태 모델링하는 방식을 DU로 전환
- 기존 Zustand 스토어를 **무침습**으로 DU 도입 (wrapSetWithPhase)
- 불가능한 상태 조합을 컴파일 타임에 차단

---

## status 필드 vs DU

```typescript
// ❌ 플랫 + status — 불가능한 조합 허용
interface GameState {
  status: 'idle' | 'dealing' | 'betting' | 'showdown';
  currentPlayer: PlayerId | null;
  dealingStartedAt: number | null;
  winners: PlayerId[] | null;
}

// 문제: status='idle'인데 winners가 있는 상태도 타입상 유효
// 접근 시마다 null 체크 산재
if (state.status === 'betting') {
  state.currentPlayer!; // ❌ non-null assertion 남발
}
```

```typescript
// ✅ DU — status별로 유효 필드만 존재
type GamePhase =
  | { kind: 'idle' }
  | { kind: 'dealing'; startedAt: number }
  | { kind: 'betting'; currentPlayer: PlayerId; minRaise: ChipAmount }
  | { kind: 'showdown'; winners: PlayerId[]; pot: ChipAmount };

// 타입 좁히기로 null 체크 불필요
if (phase.kind === 'betting') {
  phase.currentPlayer; // 타입: PlayerId (non-null 보장)
  // phase.winners;    // ❌ 컴파일 에러
}
```

---

## exhaustive never 체크

```typescript
function renderPhase(phase: GamePhase): JSX.Element {
  switch (phase.kind) {
    case 'idle':     return <IdleScreen />;
    case 'dealing':  return <DealingOverlay startedAt={phase.startedAt} />;
    case 'betting':  return <BettingControls player={phase.currentPlayer} />;
    case 'showdown': return <ShowdownResult winners={phase.winners} />;
    default: {
      const _exhaustive: never = phase;
      throw new Error(`Unhandled phase: ${JSON.stringify(_exhaustive)}`);
    }
  }
}
```

새 phase가 추가되면 switch에 누락된 case가 **컴파일 에러**로 감지됨.

---

## wrapSetWithPhase: 무침습 도입 패턴

### 배경
기존 Zustand 스토어에는 플랫 필드가 40개 이상 존재. 전체를 DU로 전환하면 모든 셀렉터/컴포넌트를 수정해야 함. → **기존 플랫 구조 + 신규 phase 필드를 공존**시키는 패턴.

### 구조

```typescript
// stores/trainingStoreTypes.ts
interface FlatState {
  status: 'idle' | 'dealing' | 'betting' | 'showdown';
  currentPlayer: PlayerId | null;
  winners: PlayerId[] | null;
  dealingStartedAt: number | null;
  // ... 기존 플랫 필드
}

// 신규 phase DU — 파생 필드
type Phase =
  | { kind: 'idle' }
  | { kind: 'dealing'; startedAt: number }
  | { kind: 'betting'; currentPlayer: PlayerId }
  | { kind: 'showdown'; winners: PlayerId[] }
  | { kind: 'error'; message: string };

interface State extends FlatState {
  phase: Phase;
}
```

### derivePhase — 플랫 → DU 변환

```typescript
// stores/trainingStoreHelpers.ts
export function derivePhase(state: FlatState): Phase {
  try {
    switch (state.status) {
      case 'idle':
        return { kind: 'idle' };

      case 'dealing':
        if (state.dealingStartedAt == null) {
          return { kind: 'error', message: 'dealing without startedAt' };
        }
        return { kind: 'dealing', startedAt: state.dealingStartedAt };

      case 'betting':
        if (!state.currentPlayer) {
          return { kind: 'error', message: 'betting without currentPlayer' };
        }
        return { kind: 'betting', currentPlayer: state.currentPlayer };

      case 'showdown':
        if (!state.winners) {
          return { kind: 'error', message: 'showdown without winners' };
        }
        return { kind: 'showdown', winners: state.winners };

      default: {
        const _exhaustive: never = state.status;
        return { kind: 'error', message: `unknown status: ${_exhaustive}` };
      }
    }
  } catch (e) {
    return { kind: 'error', message: String(e) };
  }
}
```

### setWithPhase 래퍼

```typescript
// stores/trainingStore.ts
export const useTrainingStore = create<State>((set, get) => {
  // 플랫 필드 업데이트 시 phase 자동 동기화
  const setWithPhase = (partial: Partial<FlatState>) => {
    set((state) => {
      const nextFlat = { ...state, ...partial };
      return { ...nextFlat, phase: derivePhase(nextFlat) };
    });
  };

  return {
    // 초기 플랫 상태
    status: 'idle',
    currentPlayer: null,
    winners: null,
    dealingStartedAt: null,
    phase: { kind: 'idle' },

    // 액션 — setWithPhase 사용
    startDealing: (now: number) => setWithPhase({
      status: 'dealing',
      dealingStartedAt: now,
    }),

    enterBetting: (player: PlayerId) => setWithPhase({
      status: 'betting',
      currentPlayer: player,
      dealingStartedAt: null,
    }),
  };
});
```

---

## 점진 전환

1. **기존 코드**: 플랫 필드(`status`, `currentPlayer`) 그대로 사용 — 수정 불필요
2. **신규 코드**: `phase` DU로 접근
3. **리팩토링 시점**: 셀렉터 하나씩 `phase` 기반으로 교체

```typescript
// 기존 셀렉터 — 그대로 동작
const status = useTrainingStore((s) => s.status);

// 신규 셀렉터 — DU 사용
const phase = useTrainingStore((s) => s.phase);
if (phase.kind === 'betting') {
  // phase.currentPlayer 타입 안전
}
```

---

## invariant 위반 시 error phase 폴백

`derivePhase`에서 잘못된 조합 감지 시 `{ kind: 'error', message }` 반환. 앱 크래시 대신 에러 UI 노출:

```tsx
function GameScreen() {
  const phase = useTrainingStore((s) => s.phase);

  if (phase.kind === 'error') {
    return <ErrorBoundary message={phase.message} />;
  }

  return <PhaseRenderer phase={phase} />;
}
```

---

## 체크리스트

- [ ] 상태 머신이 있는 도메인은 DU로 모델링했는가
- [ ] `status: string` + 플랫 nullable 필드 조합을 피했는가
- [ ] 기존 스토어 전환 시 `wrapSetWithPhase` 패턴을 썼는가
- [ ] `derivePhase`에 exhaustive never 체크가 있는가
- [ ] invariant 위반 시 `error` phase로 폴백하는가
- [ ] switch/case에 `default: const _e: never = phase` 있는가
- [ ] 불가능한 상태 조합이 타입으로 차단되는가
