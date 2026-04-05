# Zustand Slice Pattern

## 용도
- Zustand 스토어가 20개 이상 필드로 비대해진 경우 도메인별 분리
- 새 스토어 설계 시 처음부터 슬라이스 구조로 시작
- 대형 액션을 `actions/` 디렉토리로 분리

---

## 40+ 플랫 필드 문제점

### 증상

```typescript
// ❌ God Store — 45개 필드, 600줄
interface TrainingState {
  // 세션
  sessionId: string | null;
  sessionStatus: string;
  createdAt: number | null;

  // 오프닝
  openingStep: number;
  isTrainingOpening: boolean;
  seatAssignDone: boolean;
  dealerDrawDone: boolean;

  // 게임플레이
  gameState: GameState | null;
  currentPlayer: PlayerId | null;
  pot: number;
  // ... 20개 더

  // 토너먼트
  blindLevel: number;
  nextBlindAt: number;

  // 내부
  animationSkipped: boolean;
  soundEnabled: boolean;
  // ... 등등

  // 액션 — 모두 한 파일에
  createSession: () => Promise<void>;  // 80줄
  advanceAutoTurn: () => Promise<void>; // 120줄
  nextRound: () => Promise<void>;       // 90줄
  // ... 30개 액션
}
```

### 문제
1. **리렌더 폭발** — 작은 필드 변경에도 전체 구독자 재렌더
2. **파일 600줄+** — 300줄 규칙 위반
3. **도메인 경계 불명** — 오프닝 상태와 게임 상태가 섞임
4. **테스트 어려움** — 한 슬라이스만 모킹 불가
5. **팀 작업 충돌** — 같은 파일 수정 충돌 빈번

---

## 도메인별 슬라이스 분리

### 전체 구조

```
stores/
├── trainingStore.ts              # 조합 (50줄)
├── trainingStoreTypes.ts         # 타입 정의
├── slices/
│   ├── sessionSlice.ts           # 세션 도메인
│   ├── openingSlice.ts           # 오프닝 시퀀스
│   ├── gameplaySlice.ts          # 게임플레이
│   ├── tournamentSlice.ts        # 블라인드/토너먼트
│   └── internalSlice.ts          # 사운드/애니메이션 스킵
└── actions/
    ├── createSession.ts          # 대형 액션 분리
    ├── advanceAutoTurn.ts
    └── nextRound.ts
```

---

## 슬라이스 타입 정의

```typescript
// stores/trainingStoreTypes.ts
import type { StateCreator } from 'zustand';

// 1. 슬라이스별 인터페이스
export interface SessionSlice {
  sessionId: SessionId | null;
  sessionStatus: 'idle' | 'creating' | 'ready' | 'error';
  createdAt: number | null;
  setSession: (id: SessionId, createdAt: number) => void;
  clearSession: () => void;
}

export interface OpeningSlice {
  openingStep: number;
  isTrainingOpening: boolean;
  seatAssignDone: boolean;
  dealerDrawDone: boolean;
  advanceOpeningStep: () => void;
  finishOpening: () => void;
}

export interface GameplaySlice {
  gameState: GameState | null;
  currentPlayer: PlayerId | null;
  pot: ChipAmount;
  setGameState: (state: GameState) => void;
  setCurrentPlayer: (id: PlayerId) => void;
}

export interface TournamentSlice {
  blindLevel: number;
  nextBlindAt: number | null;
  advanceBlindLevel: () => void;
}

export interface InternalSlice {
  animationSkipped: boolean;
  soundEnabled: boolean;
  toggleSound: () => void;
  skipAnimation: () => void;
}

// 2. 합친 타입
export type TrainingState =
  & SessionSlice
  & OpeningSlice
  & GameplaySlice
  & TournamentSlice
  & InternalSlice;

// 3. StateCreator 타입 헬퍼
export type SliceCreator<T> = StateCreator<
  TrainingState,
  [],
  [],
  T
>;
```

---

## 슬라이스 구현

```typescript
// stores/slices/sessionSlice.ts
import type { SliceCreator, SessionSlice } from '../trainingStoreTypes';

export const createSessionSlice: SliceCreator<SessionSlice> = (set) => ({
  sessionId: null,
  sessionStatus: 'idle',
  createdAt: null,

  setSession: (id, createdAt) => set({
    sessionId: id,
    sessionStatus: 'ready',
    createdAt,
  }),

  clearSession: () => set({
    sessionId: null,
    sessionStatus: 'idle',
    createdAt: null,
  }),
});
```

```typescript
// stores/slices/openingSlice.ts
import type { SliceCreator, OpeningSlice } from '../trainingStoreTypes';

export const createOpeningSlice: SliceCreator<OpeningSlice> = (set) => ({
  openingStep: 0,
  isTrainingOpening: true,
  seatAssignDone: false,
  dealerDrawDone: false,

  advanceOpeningStep: () => set((state) => ({
    openingStep: state.openingStep + 1,
  })),

  finishOpening: () => set({
    isTrainingOpening: false,
    seatAssignDone: true,
    dealerDrawDone: true,
  }),
});
```

---

## 슬라이스 조합

```typescript
// stores/trainingStore.ts
import { create } from 'zustand';
import type { TrainingState } from './trainingStoreTypes';
import { createSessionSlice } from './slices/sessionSlice';
import { createOpeningSlice } from './slices/openingSlice';
import { createGameplaySlice } from './slices/gameplaySlice';
import { createTournamentSlice } from './slices/tournamentSlice';
import { createInternalSlice } from './slices/internalSlice';

export const useTrainingStore = create<TrainingState>()((...args) => ({
  ...createSessionSlice(...args),
  ...createOpeningSlice(...args),
  ...createGameplaySlice(...args),
  ...createTournamentSlice(...args),
  ...createInternalSlice(...args),
}));
```

---

## 대형 액션 분리

```typescript
// stores/actions/advanceAutoTurn.ts
import type { TrainingState } from '../trainingStoreTypes';
import { tryAsync } from '@/shared/result';
import { api } from '@/services/trainingService';

export async function advanceAutoTurn(
  get: () => TrainingState,
  set: (partial: Partial<TrainingState>) => void,
): Promise<void> {
  const { sessionId, gameState } = get();
  if (!sessionId || !gameState) return;

  const result = await tryAsync(() => api.advanceTurn(sessionId));
  if (!result.ok) {
    set({ sessionStatus: 'error' });
    return;
  }

  set({
    gameState: result.value.gameState,
    currentPlayer: result.value.currentPlayer,
  });
}
```

슬라이스에서 호출:
```typescript
// stores/slices/gameplaySlice.ts
import { advanceAutoTurn } from '../actions/advanceAutoTurn';

export const createGameplaySlice: SliceCreator<GameplaySlice> = (set, get) => ({
  // ... 상태
  advanceAutoTurn: () => advanceAutoTurn(get, set),
});
```

---

## 셀렉터로 구독 범위 제한

```typescript
// ❌ 전체 구독 — 모든 변경에 리렌더
const state = useTrainingStore();

// ✅ 셀렉터 — 해당 필드 변경에만 리렌더
const pot = useTrainingStore((s) => s.pot);

// ✅ shallow로 다중 필드 + 도메인 셀렉터 훅
import { useShallow } from 'zustand/react/shallow';
export const useSession = () => useTrainingStore(
  useShallow((s) => ({ sessionId: s.sessionId, status: s.sessionStatus })),
);
```

---

## 체크리스트

- [ ] 스토어 필드가 10개 이상이면 슬라이스로 분리했는가
- [ ] 각 슬라이스가 단일 도메인에 집중하는가
- [ ] 슬라이스 타입은 `StateCreator<Root, [], [], Slice>`로 선언했는가
- [ ] 50줄 이상 액션은 `actions/` 디렉토리로 분리했는가
- [ ] 컴포넌트는 셀렉터로 구독 범위를 제한하는가
- [ ] `useShallow`로 다중 필드 구독 최적화했는가
- [ ] 슬라이스 파일이 300줄 이하인가
- [ ] 도메인별 셀렉터 훅을 제공하는가
