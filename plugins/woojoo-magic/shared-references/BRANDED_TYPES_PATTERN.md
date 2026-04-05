# Branded Types Pattern

## 용도
- 도메인 식별자(`PlayerId`, `SessionId` 등)와 원시 타입(`string`, `number`)의 혼동 방지
- 인자 순서 오류를 **컴파일 타임에** 감지
- 새 API/함수 시그니처 작성 시, 기존 코드 점진 도입 시 참조

---

## 왜 필요한가

```typescript
// ❌ 모두 string — 순서 바꿔도 컴파일 통과
function kickPlayer(roomId: string, playerId: string) { ... }

kickPlayer(playerId, roomId); // 버그. 런타임에만 터짐.
```

```typescript
// ✅ Branded Type — 컴파일 에러
type RoomId = string & { readonly __brand: 'RoomId' };
type PlayerId = string & { readonly __brand: 'PlayerId' };

function kickPlayer(roomId: RoomId, playerId: PlayerId) { ... }

kickPlayer(playerId, roomId); // ❌ 타입 에러
```

---

## 정의 방법

```typescript
// shared/src/types/ids.ts
export type PlayerId = string & { readonly __brand: 'PlayerId' };
export type SessionId = string & { readonly __brand: 'SessionId' };
export type RoomCode = string & { readonly __brand: 'RoomCode' };
export type ChipAmount = number & { readonly __brand: 'ChipAmount' };
export type HandId = string & { readonly __brand: 'HandId' };

// 팩토리 — 검증 포함
export const asPlayerId = (value: string): PlayerId => {
  if (!value) throw new Error('PlayerId cannot be empty');
  return value as PlayerId;
};

export const asChipAmount = (value: number): ChipAmount => {
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`Invalid ChipAmount: ${value}`);
  }
  return value as ChipAmount;
};

// 정수 강제
export const asRoomCode = (value: string): RoomCode => {
  if (!/^[A-Z0-9]{6}$/.test(value)) {
    throw new Error(`RoomCode must be 6 alphanumeric chars: ${value}`);
  }
  return value as RoomCode;
};
```

---

## 경계점(Boundary) 캐스트 전략

**핵심 원칙: 경계점에서만 캐스트, 내부는 자연 전파**

### 경계점 = 타입 정보가 없는 지점
1. 서버 응답 파싱
2. 사용자 입력 (폼, URL 파라미터)
3. 외부 라이브러리 반환값
4. localStorage / IndexedDB 역직렬화

### 내부 = 이미 브랜드된 타입이 흐름

```typescript
// ✅ 서버 응답 경계점 (1번만 캐스트)
async function fetchPlayer(id: string): Promise<Player> {
  const raw = await api.get(`/players/${id}`);
  return {
    id: asPlayerId(raw.id),              // 캐스트
    chips: asChipAmount(raw.chips),      // 캐스트
    sessionId: asSessionId(raw.sessionId), // 캐스트
    name: raw.name,
  };
}

// ✅ 내부 함수 — 캐스트 없이 자연 전파
function transferChips(from: PlayerId, to: PlayerId, amount: ChipAmount) {
  // ... 내부에서는 이미 브랜드된 타입
}

// ✅ URL 파라미터 경계점
const params = useParams();
const roomCode = asRoomCode(params.code ?? ''); // 한 번만 캐스트
joinRoom(roomCode); // 이후 자연 전파
```

---

## 실전 예시 (crypto-holdem 검증)

```typescript
// shared/src/types/game.ts
export interface GameState {
  dealerPlayerId: PlayerId;
  sbPlayerId: PlayerId;
  bbPlayerId: PlayerId;
  pot: ChipAmount;
  players: Record<PlayerId, Player>; // ⚠️ 주의: 아래 섹션 참조
}

// engine/betting.ts — 내부 전파
export function applyBet(
  state: GameState,
  playerId: PlayerId,
  amount: ChipAmount,
): Result<GameState, BetError> {
  const player = state.players[playerId];
  if (!player) return Err('PLAYER_NOT_FOUND');
  if (player.chips < amount) return Err('INSUFFICIENT_CHIPS');

  return Ok({
    ...state,
    pot: asChipAmount(state.pot + amount),
    players: {
      ...state.players,
      [playerId]: { ...player, chips: asChipAmount(player.chips - amount) },
    },
  });
}
```

---

## `Record<PlayerId, X>` 주의점

TypeScript에서 Branded string을 Record 키로 쓸 때 **string 리터럴 접근은 에러**:

```typescript
const players: Record<PlayerId, Player> = {};

// ❌ string 리터럴은 PlayerId가 아님
players['abc123']; // Type error

// ✅ 이미 브랜드된 변수로 접근
const id: PlayerId = asPlayerId('abc123');
players[id];

// ✅ 또는 Object.entries로 순회 (키는 string으로 복귀)
Object.entries(players).forEach(([rawId, player]) => {
  const id = asPlayerId(rawId); // 재캐스트 필요
});
```

**팁**: 순회가 많으면 `Map<PlayerId, Player>`가 더 편함.

---

## 점진 도입 전략

기존 프로젝트에 한 번에 적용하면 타입 에러 폭발. 순서:

1. **shared/types** 에 Branded Type 정의 추가
2. **shared/engine** 순수 함수 시그니처부터 변경 (테스트로 보호)
3. **server** 경계점(REST/WS 핸들러)에서 캐스트 추가
4. **client** 스토어/서비스 경계점에서 캐스트 추가
5. **client/components** 는 props로 자연 전파 (마지막)

각 단계마다 `pnpm turbo typecheck` 통과 확인 후 다음 단계로.

---

## 체크리스트

- [ ] 도메인 식별자(ID류)는 모두 Branded Type인가
- [ ] 팩토리 함수에 검증 로직이 있는가
- [ ] 캐스트는 경계점(API/입력/라이브러리)에서만 발생하는가
- [ ] 내부 함수 시그니처는 Branded Type을 받는가
- [ ] `Record<BrandedId, X>` 사용 시 접근 방식이 올바른가
- [ ] `any as PlayerId` 같은 우회 캐스트 없는가
- [ ] 금액류(`ChipAmount`)는 음수/NaN 검증하는가
