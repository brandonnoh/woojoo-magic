# Refactoring Prevention

## 용도
- "리팩토링 필요" = 이미 실패의 신호. 처음부터 고품질로 짜기 위한 사전 감지 체크리스트
- 코드 작성 **도중**에 "아직 늦지 않았다" 시점을 놓치지 않기
- PR 리뷰 시 리팩토링 부채 조기 식별

---

## 철학

> **리팩토링은 실패의 신호다.**
>
> 처음부터 올바른 구조로 짰다면 리팩토링은 필요 없다.
> "나중에 리팩토링하자"는 거의 항상 "영원히 안 한다"와 같다.

### "이미 늦었다" 시그널

| 시그널 | 의미 |
|--------|------|
| 파일 300줄 초과 | SRP 위반 — 한 파일이 너무 많은 책임 |
| 함수 50줄 초과 | 여러 단계가 한 함수에 섞임 |
| God Class (500줄+) | 위임 경계 실패 |
| 중복 코드 3곳 이상 | DRY 실패 — 이미 의미 분산 |
| Props 7개 이상 | 컴포넌트가 너무 많은 맥락을 받음 |
| useEffect 5개 이상 | 훅 하나가 여러 도메인 관리 |
| `any` 1개 이상 | 타입 시스템 우회 시작 |
| `!` 3개 이상 | 런타임 보호 포기 |
| Store 필드 30개+ | 도메인 분리 실패 |

이 중 **하나라도 해당**하면 이미 기술 부채가 누적된 상태.

---

## 사전 감지 방법

### 실시간 측정

```bash
# 파일 라인 수 모니터링
find client/src -name '*.ts' -o -name '*.tsx' | xargs wc -l | sort -n | tail -20

# 함수 길이 — eslint max-lines-per-function
# Props 개수 — eslint-plugin-react max-props
# 복잡도 — eslint complexity
```

### ESLint 규칙 (권장)

```json
{
  "rules": {
    "max-lines": ["error", { "max": 300 }],
    "max-lines-per-function": ["error", { "max": 30 }],
    "max-params": ["error", 3],
    "complexity": ["error", 10],
    "max-depth": ["error", 3],
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-non-null-assertion": "error"
  }
}
```

---

## 체크포인트: 파일 작성 중

### 200줄 돌파 시점
**멈추고 질문**: "이 파일이 한 가지 책임에 집중하는가?"

- Yes → 계속 작성 (300줄까지 여유)
- No → **즉시** 분리 계획 세우기:
  1. 책임 목록 나열
  2. 어느 부분이 빠질 수 있는가
  3. 파일명/위치 결정
  4. 작성 중이던 것 완료 후 분리

### 함수 30줄 돌파 시점
**질문**: "이 함수가 여러 단계를 수행하는가?"

- 3단계 이상 → 각 단계를 함수로 추출
- 단일 단계 — 루프/분기가 복잡 → 헬퍼 함수 추출

### Props 5개 돌파 시점
**질문**: "이 Props 그룹이 의미적으로 하나인가?"

- Yes → 객체로 묶기 (`{ user, handlers, config }`)
- No → Context 또는 컴포넌트 분할

---

## 사례: 200줄 돌파 대응

```typescript
// UserProfile.tsx — 작성 중 220줄
// 책임 목록:
//   1. 프로필 헤더 (아바타, 이름)
//   2. 활동 내역 리스트
//   3. 통계 차트
//   4. 설정 토글
//   5. 액션 버튼 (저장, 로그아웃)

// → 분리 계획
// UserProfile.tsx           (80줄) - 오케스트레이터
// ProfileHeader.tsx         (50줄) - 1번
// ActivityList.tsx          (70줄) - 2번
// ProfileStats.tsx          (60줄) - 3번
// ProfileActions.tsx        (40줄) - 4, 5번
```

**핵심**: 300줄 다 쓰고 나서 분리가 아니라, **쓰는 도중** 분리.

---

## 체크리스트: 작성 중 실시간 점검

### 매 30분마다 확인
- [ ] 현재 파일 몇 줄인가? (200줄 넘으면 분리 계획)
- [ ] 현재 함수 몇 줄인가? (20줄 넘으면 헬퍼 추출)
- [ ] Props 몇 개인가? (5개 넘으면 그룹핑)
- [ ] 같은 패턴 여러 번 쓰지 않는가? (2곳 이상 → 유틸)
- [ ] `any`, `!`, `as` 썼는가? (대체 방법 고민)

### 커밋 전
- [ ] `pnpm turbo typecheck` 통과
- [ ] `pnpm turbo build` 통과
- [ ] `pnpm turbo test` 통과
- [ ] ESLint 경고 0개
- [ ] HIGH_QUALITY_CODE_STANDARDS.md 체크리스트 통과

---

## 중복 감지 트리거

| 상황 | 액션 |
|------|------|
| 같은 패턴 **2곳** | "3번째 나오면 추출" 메모 |
| 같은 패턴 **3곳** | **즉시** 유틸 추출 (리뷰 거부 사유) |
| 비슷한 타입 2개 | 제네릭으로 통합 검토 |
| 비슷한 컴포넌트 2개 | props 기반 1개로 통합 검토 |

---

## SRP 위반 감지

함수/클래스가 "그리고", "또는"으로 설명되면 SRP 위반:

```typescript
// ❌ "사용자를 찾아서 잔액을 차감하고 로그를 기록한다"
function processOrder(userId, amount) {
  const user = users.find(...);   // 1) 찾기
  user.balance -= amount;          // 2) 차감
  log.push({ userId, amount });    // 3) 기록
}

// ✅ 3개 함수로 분리
function findUser(id): User | null { ... }
function deductBalance(user, amount): User { ... }
function logTransaction(log, entry): Log { ... }

function processOrder(userId, amount) {
  const user = findUser(userId);
  if (!user) return;
  const updated = deductBalance(user, amount);
  const nextLog = logTransaction(log, { userId, amount });
  return { user: updated, log: nextLog };
}
```

---

## 처음부터 고품질 마인드셋

### 잘못된 생각
- "일단 돌아가게 만들고 나중에 리팩토링"
- "TODO: 나중에 분리"
- "MVP니까 지금은 괜찮아"
- "시간 없으니 any로"

### 올바른 생각
- "처음부터 올바른 구조" = "리팩토링 불필요"
- "나중에 = 영원히 안 한다"
- "고품질 = 느리다"는 거짓 — **부채 없는 속도가 진짜 속도**
- "any 1개 = 전체 타입 시스템 신뢰 붕괴 시작"

### 실리콘밸리 원칙
1. **코드는 쓰는 시간보다 읽히는 시간이 10배 길다** → 가독성 우선
2. **첫 커밋이 최종 품질을 결정한다** → 리뷰어 마인드셋으로 작성
3. **기술 부채는 복리로 늘어난다** → 오늘의 `any`가 내일의 버그
4. **작게 자주 분리** → 한 번에 대공사 금지

---

## "나중에 리팩토링" 탈출구

이미 부채가 쌓였다면:

1. **동결** — 새 기능 추가 중단, 해당 파일은 테스트만 추가
2. **경계 긋기** — 새 코드는 새 파일/모듈에 작성, 기존은 동결
3. **Strangler Fig** — 새 구조로 점진 이식, 기존은 호출 래퍼만 남김
4. **삭제 우선** — 리팩토링보다 **삭제 가능 여부** 먼저 검토

---

## 체크리스트 (PR 제출 전)

- [ ] 어떤 파일도 300줄 초과하지 않는가
- [ ] 어떤 함수도 30줄 초과하지 않는가
- [ ] Props 5개 초과 컴포넌트 없는가
- [ ] 같은 패턴 3곳 이상 존재하는 중복 없는가
- [ ] `any`, `!`, `as any` 없는가
- [ ] useEffect가 파생 상태 계산 용도가 아닌가
- [ ] "TODO: 리팩토링" 주석 없는가 (있다면 지금 해라)
- [ ] 새 파일/함수가 단일 책임에 집중하는가
- [ ] 이름이 의도를 명확히 전달하는가
- [ ] 커밋 전 ESLint 경고 0개인가
