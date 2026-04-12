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
interface AppState {
  // 인증
  userId: string | null;
  authStatus: string;
  token: string | null;

  // 장바구니
  cartItems: CartItem[];
  cartTotal: number;
  cartCoupon: string | null;

  // 알림
  notifications: Notification[];
  unreadCount: number;
  // ... 20개 더

  // 설정
  theme: 'light' | 'dark';
  locale: string;

  // 내부
  sidebarOpen: boolean;
  soundEnabled: boolean;
  // ... 등등

  // 액션 — 모두 한 파일에
  login: () => Promise<void>;        // 80줄
  addToCart: () => Promise<void>;     // 120줄
  checkout: () => Promise<void>;     // 90줄
  // ... 30개 액션
}
```

### 문제
1. **리렌더 폭발** — 작은 필드 변경에도 전체 구독자 재렌더
2. **파일 600줄+** — 300줄 규칙 위반
3. **도메인 경계 불명** — 인증 상태와 장바구니 상태가 섞임
4. **테스트 어려움** — 한 슬라이스만 모킹 불가
5. **팀 작업 충돌** — 같은 파일 수정 충돌 빈번

---

## 도메인별 슬라이스 분리

### 전체 구조

```
stores/
├── appStore.ts                  # 조합 (50줄)
├── appStoreTypes.ts             # 타입 정의
├── slices/
│   ├── authSlice.ts             # 인증 도메인
│   ├── cartSlice.ts             # 장바구니
│   ├── notificationSlice.ts     # 알림
│   ├── settingsSlice.ts         # 테마/로케일
│   └── uiSlice.ts               # 사이드바/사운드
└── actions/
    ├── login.ts                 # 대형 액션 분리
    ├── addToCart.ts
    └── checkout.ts
```

---

## 슬라이스 타입 정의

```typescript
// stores/appStoreTypes.ts
import type { StateCreator } from 'zustand';

// 1. 슬라이스별 인터페이스
export interface AuthSlice {
  userId: UserId | null;
  authStatus: 'idle' | 'loading' | 'authenticated' | 'error';
  token: string | null;
  setAuth: (userId: UserId, token: string) => void;
  clearAuth: () => void;
}

export interface CartSlice {
  cartItems: CartItem[];
  cartTotal: Money;
  cartCoupon: CouponCode | null;
  addItem: (item: CartItem) => void;
  removeItem: (itemId: ProductId) => void;
}

export interface NotificationSlice {
  notifications: Notification[];
  unreadCount: number;
  markAsRead: (id: NotificationId) => void;
  clearAll: () => void;
}

export interface SettingsSlice {
  theme: 'light' | 'dark';
  locale: string;
  setTheme: (theme: 'light' | 'dark') => void;
  setLocale: (locale: string) => void;
}

export interface UiSlice {
  sidebarOpen: boolean;
  soundEnabled: boolean;
  toggleSidebar: () => void;
  toggleSound: () => void;
}

// 2. 합친 타입
export type AppState =
  & AuthSlice
  & CartSlice
  & NotificationSlice
  & SettingsSlice
  & UiSlice;

// 3. StateCreator 타입 헬퍼
export type SliceCreator<T> = StateCreator<
  AppState,
  [],
  [],
  T
>;
```

---

## 슬라이스 구현

```typescript
// stores/slices/authSlice.ts
import type { SliceCreator, AuthSlice } from '../appStoreTypes';

export const createAuthSlice: SliceCreator<AuthSlice> = (set) => ({
  userId: null,
  authStatus: 'idle',
  token: null,

  setAuth: (userId, token) => set({
    userId,
    authStatus: 'authenticated',
    token,
  }),

  clearAuth: () => set({
    userId: null,
    authStatus: 'idle',
    token: null,
  }),
});
```

```typescript
// stores/slices/cartSlice.ts
import type { SliceCreator, CartSlice } from '../appStoreTypes';

export const createCartSlice: SliceCreator<CartSlice> = (set) => ({
  cartItems: [],
  cartTotal: asMoney(0),
  cartCoupon: null,

  addItem: (item) => set((state) => ({
    cartItems: [...state.cartItems, item],
    cartTotal: asMoney(state.cartTotal + item.price),
  })),

  removeItem: (itemId) => set((state) => {
    const items = state.cartItems.filter(i => i.id !== itemId);
    const total = items.reduce((sum, i) => sum + i.price, 0);
    return { cartItems: items, cartTotal: asMoney(total) };
  }),
});
```

---

## 슬라이스 조합

```typescript
// stores/appStore.ts
import { create } from 'zustand';
import type { AppState } from './appStoreTypes';
import { createAuthSlice } from './slices/authSlice';
import { createCartSlice } from './slices/cartSlice';
import { createNotificationSlice } from './slices/notificationSlice';
import { createSettingsSlice } from './slices/settingsSlice';
import { createUiSlice } from './slices/uiSlice';

export const useAppStore = create<AppState>()((...args) => ({
  ...createAuthSlice(...args),
  ...createCartSlice(...args),
  ...createNotificationSlice(...args),
  ...createSettingsSlice(...args),
  ...createUiSlice(...args),
}));
```

---

## 대형 액션 분리

```typescript
// stores/actions/checkout.ts
import type { AppState } from '../appStoreTypes';
import { tryAsync } from '@/shared/result';
import { api } from '@/services/orderService';

export async function checkout(
  get: () => AppState,
  set: (partial: Partial<AppState>) => void,
): Promise<void> {
  const { userId, cartItems } = get();
  if (!userId || cartItems.length === 0) return;

  const result = await tryAsync(() => api.createOrder(userId, cartItems));
  if (!result.ok) {
    set({ authStatus: 'error' });
    return;
  }

  set({
    cartItems: [],
    cartTotal: asMoney(0),
    cartCoupon: null,
  });
}
```

슬라이스에서 호출:
```typescript
// stores/slices/cartSlice.ts
import { checkout } from '../actions/checkout';

export const createCartSlice: SliceCreator<CartSlice> = (set, get) => ({
  // ... 상태
  checkout: () => checkout(get, set),
});
```

---

## 셀렉터로 구독 범위 제한

```typescript
// ❌ 전체 구독 — 모든 변경에 리렌더
const state = useAppStore();

// ✅ 셀렉터 — 해당 필드 변경에만 리렌더
const cartTotal = useAppStore((s) => s.cartTotal);

// ✅ shallow로 다중 필드 + 도메인 셀렉터 훅
import { useShallow } from 'zustand/react/shallow';
export const useAuth = () => useAppStore(
  useShallow((s) => ({ userId: s.userId, status: s.authStatus })),
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
