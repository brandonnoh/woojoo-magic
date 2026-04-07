# Library Type Hardening

## 용도
- 외부 라이브러리를 `any`로 받고 있는 코드를 정확한 타입으로 교체
- 새 라이브러리 도입 시 처음부터 정확한 제네릭 지정
- Context7 MCP로 공식 타입 조회

---

## 원칙

1. **`any` 절대 금지** — 라이브러리 타입이 복잡해도 우회 금지
2. **Context7 MCP 필수** — 공식 문서에서 타입 시그니처 조회
3. **제네릭 파라미터 명시** — `AxiosResponse`가 아니라 `AxiosResponse<UserDto>`
4. **경계 타입을 프로젝트에 흡수** — 래퍼에서 한 번만 정의, 내부는 도메인 타입으로 변환

---

## Context7 MCP 사용 패턴

```
작업: axios의 response 타입 정확히 잡기

1. mcp__context7__resolve-library-id("axios")
   → /axios/axios 획득
2. mcp__context7__query-docs("/axios/axios", "AxiosResponse generic parameters")
   → AxiosResponse<T, D> 시그니처 확인
3. 적용
```

**원칙**: 라이브러리 타입을 추측하지 말고, 항상 Context7로 확인.

---

## 실전 사례: HTTP 클라이언트

### Before (any 사용)

```typescript
// ❌ client: any
import axios from 'axios';

let client: any;

export function initClient() {
  client = axios.create({
    baseURL: 'https://api.example.com',
    timeout: 5000,
  });
}

export async function getUser(id: string): Promise<any> {
  return client.get(`/users/${id}`).then((r: any) => r.data);
}
```

### After (정확한 제네릭)

```typescript
// ✅ 정확한 타입
import axios, { type AxiosInstance, type AxiosResponse } from 'axios';

let client: AxiosInstance | null = null;

export function initClient(): AxiosInstance {
  client = axios.create({
    baseURL: 'https://api.example.com',
    timeout: 5000,
  });
  return client;
}

export async function getUser(id: UserId): Promise<User> {
  const c = client;
  if (!c) throw new Error('Client not initialized');
  const response: AxiosResponse<UserDto> = await c.get(`/users/${id}`);
  return mapToUser(response.data);
}
```

**포인트**:
- `any` 대신 `AxiosInstance`, `AxiosResponse<UserDto>` 제네릭 명시
- `string` 대신 도메인 타입 `UserId` 사용
- `as any` 제거

---

## 제네릭 파라미터 올바른 지정

많은 라이브러리가 제네릭을 명시하지 않으면 `unknown` 또는 너무 넓은 타입으로 퇴화함:

```typescript
// ❌ TData가 unknown으로 추론됨
const query = useQuery({
  queryKey: ['user', id],
  queryFn: () => fetchUser(id),
});
query.data; // unknown

// ✅ 제네릭 명시
const query = useQuery<User, Error>({
  queryKey: ['user', id],
  queryFn: () => fetchUser(id),
});
query.data; // User | undefined
```

### Zustand store

```typescript
// ❌ create() 타입 추론에 의존
const useStore = create((set) => ({ count: 0, inc: () => set(s => ({ count: s.count + 1 })) }));

// ✅ StateCreator 명시
import { create, type StateCreator } from 'zustand';

interface CounterState {
  count: number;
  inc: () => void;
}

const createCounter: StateCreator<CounterState> = (set) => ({
  count: 0,
  inc: () => set((s) => ({ count: s.count + 1 })),
});

const useStore = create<CounterState>()(createCounter);
```

---

## 타입 호환성 이슈 해결 전략

라이브러리 업데이트로 타입이 맞지 않을 때:

### 1. 버전 맞추기 (1순위)
```bash
# Context7로 호환 버전 확인
pnpm add axios@^1.7.0
```

### 2. 공식 타입 유틸 사용
```typescript
import type { Parameters, ReturnType } from 'type-fest';
type UserResponse = Awaited<ReturnType<typeof api.getUser>>;
```

### 3. 래퍼로 경계 흡수
```typescript
// services/api.ts — 라이브러리 타입은 이 파일만 알게 함
import axios from 'axios';

export interface ApiService {
  getUser(id: UserId): Promise<User>;
  createOrder(input: OrderInput): Promise<Order>;
}

export function createApiService(baseURL: string): ApiService {
  const client = axios.create({ baseURL });
  return {
    getUser: async (id) => {
      const { data } = await client.get<UserDto>(`/users/${id}`);
      return mapToUser(data);
    },
    createOrder: async (input) => {
      const { data } = await client.post<OrderDto>('/orders', input);
      return mapToOrder(data);
    },
  };
}

// 나머지 코드는 ApiService만 앎 — axios 버전 업에도 안전
```

### 4. 마지막 수단: declaration merging
정말로 라이브러리 타입이 틀렸다면:
```typescript
// types/axios-augment.d.ts
declare module 'axios' {
  interface AxiosRequestConfig {
    // 누락된 필드 추가
  }
}
```

---

## 흔한 실수와 대응

| 실수 | 대응 |
|------|------|
| `as any` 로 타입 에러 우회 | Context7로 정확한 타입 조회 |
| `@ts-ignore` 주석 | `@ts-expect-error` + 이유 주석 |
| 제네릭 생략 → `unknown` 퍼짐 | 호출부에서 제네릭 명시 |
| 라이브러리 타입 직접 수정 | 래퍼 서비스로 경계 흡수 |
| 여러 곳에서 중복 import | `services/*.ts` 에서만 import |

---

## React Query, TanStack Router, shadcn 등 대표 케이스

```typescript
// React Query
import type { UseQueryResult } from '@tanstack/react-query';
function useUser(id: UserId): UseQueryResult<User, Error> { ... }

// TanStack Router
import type { Route } from '@tanstack/react-router';
const route: Route<typeof rootRoute, '/users/$id'> = ...;

// Framer Motion
import type { Variants, Transition } from 'framer-motion';
const variants: Variants = { ... };
```

---

## 체크리스트

- [ ] 라이브러리 반환값을 `any`로 받지 않았는가
- [ ] 제네릭 파라미터를 명시했는가 (`AxiosResponse<T>`, `UseQueryResult<T, E>`)
- [ ] Context7 MCP로 공식 타입 확인했는가
- [ ] `as any`, `@ts-ignore` 없는가 (`@ts-expect-error` + 이유는 허용)
- [ ] 라이브러리 타입이 프로젝트 전반에 누출되지 않았는가 (래퍼로 차단)
- [ ] 라이브러리 고유 타입을 올바르게 사용했는가
- [ ] 버전 업데이트 시 타입 호환성 검증했는가
