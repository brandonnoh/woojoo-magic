# Non-Null Assertion (!) Elimination

## 용도
- `!` 연산자 사용을 0으로 만들기 위한 실전 패턴
- 리뷰에서 `!` 발견 시 이 문서의 패턴으로 대체

---

## 왜 금지인가

```typescript
// ❌ ! 는 "컴파일러에게 거짓말"
const player = players.find(p => p.id === id)!;
player.chips; // 런타임에 player가 undefined면 크래시
```

1. **런타임 보호 없음** — 타입 시스템을 끌뿐 실제 null 체크는 안 함
2. **리팩토링에 취약** — 데이터 소스가 바뀌면 조용히 부서짐
3. **에러 메시지 없음** — `Cannot read property 'chips' of undefined`만 남김
4. **의도 불명** — "정말 null이 아닌가?" vs "귀찮아서 !"를 구분 불가

---

## 패턴 1: guard clause + 로컬 변수

```typescript
// ❌ non-null assertion 남발
class GameManager {
  handleAction(playerId: string) {
    this.state!.players[playerId]!.chips -= 10;
    this.state!.pot += 10;
    this.state!.lastAction = { playerId, amount: 10 };
  }
}

// ✅ 함수 시작부 guard + 로컬 변수
class GameManager {
  handleAction(playerId: PlayerId, amount: ChipAmount): void {
    const { state } = this;
    if (!state) throw new Error('GameManager: state not initialized');

    const player = state.players[playerId];
    if (!player) throw new Error(`Player ${playerId} not found`);

    // 이후 non-null 보장
    this.state = {
      ...state,
      pot: asChipAmount(state.pot + amount),
      players: {
        ...state.players,
        [playerId]: { ...player, chips: asChipAmount(player.chips - amount) },
      },
      lastAction: { playerId, amount },
    };
  }
}
```

**핵심**: 같은 필드를 여러 번 접근 → **로컬 변수로 한 번만 꺼낸다**.

---

## 패턴 2: find → findOrThrow 유틸

```typescript
// ❌ 반복되는 !
const player = players.find(p => p.id === id)!;
const dealer = players.find(p => p.isDealer)!;

// ✅ 유틸 추출
export function findOrThrow<T>(
  items: readonly T[],
  predicate: (item: T) => boolean,
  errorMessage: string,
): T {
  const found = items.find(predicate);
  if (!found) throw new Error(errorMessage);
  return found;
}

const player = findOrThrow(players, p => p.id === id, `Player ${id} not found`);
const dealer = findOrThrow(players, p => p.isDealer, 'Dealer not set');
```

---

## 패턴 3: Record 접근 — `in` 체크 또는 nullable 인정

```typescript
// ❌
const player = state.players[playerId]!;

// ✅ in 체크
if (!(playerId in state.players)) {
  throw new Error(`Player ${playerId} not found`);
}
const player = state.players[playerId]; // 여전히 undefined일 수 있음 (noUncheckedIndexedAccess)

// ✅ 더 확실 — 변수로 빼고 guard
const player = state.players[playerId];
if (!player) throw new Error(`Player ${playerId} not found`);
player.chips; // non-null 보장
```

**crypto-holdem 설정**: `tsconfig`에 `noUncheckedIndexedAccess: true` 필수.

---

## 패턴 4: Props에서 nullable — conditional rendering

```typescript
// ❌
interface Props { player: Player | null }
function PlayerCard({ player }: Props) {
  return <div>{player!.name}</div>;
}

// ✅ 부모에서 분기
function Parent() {
  const { player } = useStore();
  if (!player) return <EmptySlot />;
  return <PlayerCard player={player} />;
}

interface Props { player: Player } // nullable 제거
function PlayerCard({ player }: Props) {
  return <div>{player.name}</div>;
}
```

---

## 패턴 5: useRef — optional chaining

```typescript
// ❌
const ref = useRef<HTMLDivElement>(null);
useEffect(() => {
  ref.current!.focus();
}, []);

// ✅
const ref = useRef<HTMLDivElement>(null);
useEffect(() => {
  ref.current?.focus();
}, []);

// ✅ guard가 필요한 경우
useEffect(() => {
  const el = ref.current;
  if (!el) return;
  el.focus();
  el.scrollIntoView();
}, []);
```

---

## 패턴 6: useContext — 기본값 대신 provider guard

```typescript
// ❌ null 기본값 + !
const AuthContext = createContext<User | null>(null);
function useAuth() {
  return useContext(AuthContext)!;
}

// ✅ provider에서 검증
const AuthContext = createContext<User | null>(null);
function useAuth(): User {
  const user = useContext(AuthContext);
  if (!user) {
    throw new Error('useAuth must be used within <AuthProvider>');
  }
  return user;
}
```

---

## 패턴 7: 여러 필드 동시 검증

```typescript
// ❌
function startGame() {
  const room = store.room!;
  const dealer = store.dealer!;
  const deck = store.deck!;
  // ...
}

// ✅ 한 번에 검증
function startGame() {
  const { room, dealer, deck } = store;
  if (!room || !dealer || !deck) {
    throw new Error('Game not ready: room/dealer/deck required');
  }
  // 이후 non-null 보장
}
```

---

## 언제 `!`가 불가피한가?

**거의 없음.** 예외:

1. **테스트 코드** — `expect(result!.value).toBe(...)` 정도는 허용 (가독성)
2. **타입 가드가 어려운 서드파티 라이브러리** — 주석으로 이유 명시
3. **컴파일러가 좁히지 못하는 경우** — 타입 가드 함수 작성이 우선

```typescript
// 불가피한 경우에도 이유 주석 필수
// eslint-disable-next-line @typescript-eslint/no-non-null-assertion
const el = document.getElementById('root')!; // 빌드 타임 HTML에 보장됨
```

---

## 체크리스트

- [ ] 코드 전체에서 `!` 0개 (테스트 제외)
- [ ] 같은 필드 여러 번 접근 시 로컬 변수로 추출했는가
- [ ] 함수 시작부에 guard clause가 집중되어 있는가
- [ ] `findOrThrow` 같은 유틸로 패턴 통일했는가
- [ ] `tsconfig`에 `noUncheckedIndexedAccess: true` 있는가
- [ ] Props nullable 타입 → 부모에서 conditional rendering으로 해결했는가
- [ ] useRef는 optional chaining 또는 guard로 처리했는가
- [ ] 불가피한 `!`에는 주석으로 이유가 명시되었는가
