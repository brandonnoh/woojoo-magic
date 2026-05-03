# Branded Types Pattern

## 용도
- 도메인 식별자(`UserId`, `OrderId` 등)와 원시 타입(`string`, `number`)의 혼동 방지
- 인자 순서 오류를 **컴파일 타임에** 감지
- 새 API/함수 시그니처 작성 시, 기존 코드 점진 도입 시 참조

---

## 왜 필요한가

```typescript
// ❌ 모두 string — 순서 바꿔도 컴파일 통과
function assignRole(teamId: string, userId: string) { ... }

assignRole(userId, teamId); // 버그. 런타임에만 터짐.
```

```typescript
// ✅ Branded Type — 컴파일 에러
type TeamId = string & { readonly __brand: 'TeamId' };
type UserId = string & { readonly __brand: 'UserId' };

function assignRole(teamId: TeamId, userId: UserId) { ... }

assignRole(userId, teamId); // ❌ 타입 에러
```

---

## 정의 방법

```typescript
// shared/src/types/ids.ts
export type UserId = string & { readonly __brand: 'UserId' };
export type OrderId = string & { readonly __brand: 'OrderId' };
export type Email = string & { readonly __brand: 'Email' };
export type Money = number & { readonly __brand: 'Money' };
export type SessionId = string & { readonly __brand: 'SessionId' };

// 팩토리 — 검증 포함
export const asUserId = (value: string): UserId => {
  if (!value) throw new Error('UserId cannot be empty');
  return value as UserId;
};

export const asMoney = (value: number): Money => {
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`Invalid Money: ${value}`);
  }
  return value as Money;
};

// 형식 검증
export const asEmail = (value: string): Email => {
  if (!/^[^@]+@[^@]+\.[^@]+$/.test(value)) {
    throw new Error(`Invalid email format: ${value}`);
  }
  return value as Email;
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
async function fetchUser(id: string): Promise<User> {
  const raw = await api.get(`/users/${id}`);
  return {
    id: asUserId(raw.id),             // 캐스트
    balance: asMoney(raw.balance),    // 캐스트
    email: asEmail(raw.email),        // 캐스트
    name: raw.name,
  };
}

// ✅ 내부 함수 — 캐스트 없이 자연 전파
function transferFunds(from: UserId, to: UserId, amount: Money) {
  // ... 내부에서는 이미 브랜드된 타입
}

// ✅ URL 파라미터 경계점
const params = useParams();
const orderId = asOrderId(params.id ?? ''); // 한 번만 캐스트
loadOrder(orderId); // 이후 자연 전파
```

---

## 실전 예시 (도메인별)

### 이커머스
```typescript
export interface Order {
  id: OrderId;
  buyerId: UserId;
  sellerId: UserId;
  total: Money;
  items: Record<ProductId, OrderItem>;
}

export function applyDiscount(
  order: Order,
  discount: Money,
): Result<Order, DiscountError> {
  if (discount > order.total) return Err('DISCOUNT_EXCEEDS_TOTAL');

  return Ok({
    ...order,
    total: asMoney(order.total - discount),
  });
}
```

### SaaS
```typescript
export interface Workspace {
  id: WorkspaceId;
  ownerId: UserId;
  members: Record<UserId, Member>;
  plan: PlanId;
}
```

---

## `Record<BrandedId, X>` 주의점

TypeScript에서 Branded string을 Record 키로 쓸 때 **string 리터럴 접근은 에러**:

```typescript
const users: Record<UserId, User> = {};

// ❌ string 리터럴은 UserId가 아님
users['abc123']; // Type error

// ✅ 이미 브랜드된 변수로 접근
const id: UserId = asUserId('abc123');
users[id];

// ✅ 또는 Object.entries로 순회 (키는 string으로 복귀)
Object.entries(users).forEach(([rawId, user]) => {
  const id = asUserId(rawId); // 재캐스트 필요
});
```

**팁**: 순회가 많으면 `Map<UserId, User>`가 더 편함.

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
- [ ] `any as UserId` 같은 우회 캐스트 없는가
- [ ] 금액류(`Money`)는 음수/NaN 검증하는가
