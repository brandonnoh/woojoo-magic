# 웹 개발 레퍼런스

> 프로젝트 기술 스택별 코드 스니펫 및 설정 가이드

---

## 1. React + Vite 설정

### Vite 설정 (vite.config.ts)

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@shared': path.resolve(__dirname, '../shared/src'),
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
```

### React 엔트리 포인트 패턴

```typescript
// client/src/main.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import { App } from './App';
import './styles/globals.css';
import './i18n'; // i18n 초기화

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
```

---

## 2. TypeScript 설정

### 공유 tsconfig (tsconfig.base.json)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  }
}
```

### 클라이언트 tsconfig

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "outDir": "./dist",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@shared/*": ["../shared/src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "../shared" }]
}
```

### 서버 tsconfig

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022"],
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@shared/*": ["../shared/src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "../shared" }]
}
```

---

## 3. TailwindCSS 설정

### tailwind.config.ts

```typescript
import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // 프로젝트 커스텀 팔레트 (필요에 맞게 수정)
        'brand-primary': '#3b82f6',
        'brand-secondary': '#6366f1',
        'brand-accent': '#f59e0b',
        'surface-dark': '#0d1117',
        'surface-light': '#f5f5f5',
        'status-success': '#22c55e',
        'status-error': '#ef4444',
        'status-warning': '#f59e0b',
      },
      fontFamily: {
        sans: ['"Inter"', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', '"Fira Code"', 'monospace'],
      },
      boxShadow: {
        'card': '0 4px 6px rgba(0, 0, 0, 0.1)',
        'elevated': '0 10px 25px rgba(0, 0, 0, 0.15)',
      },
      animation: {
        'fade-in': 'fade-in 0.3s ease-in-out',
        'slide-up': 'slide-up 0.4s ease-out',
        'pulse-subtle': 'pulse-subtle 2s ease-in-out infinite',
      },
      keyframes: {
        'fade-in': {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' },
        },
        'slide-up': {
          '0%': { transform: 'translateY(20px)', opacity: '0' },
          '100%': { transform: 'translateY(0)', opacity: '1' },
        },
        'pulse-subtle': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.7' },
        },
      },
    },
  },
  plugins: [],
};

export default config;
```

---

## 4. WebSocket 클라이언트/서버

### 서버 WebSocket 설정

```typescript
// server/src/ws/SocketServer.ts
import { WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage } from 'http';
import { ServerEvent, ClientEvent } from '@myapp/shared';

export class SocketServer {
  private wss: WebSocketServer;
  private rooms: Map<string, Set<WebSocket>> = new Map();

  constructor(port: number) {
    this.wss = new WebSocketServer({ port });
    this.wss.on('connection', this.handleConnection.bind(this));
    console.log(`WebSocket server running on port ${port}`);
  }

  private handleConnection(ws: WebSocket, req: IncomingMessage) {
    const roomId = this.extractRoomId(req.url);
    if (!roomId) {
      ws.close(1008, 'Room ID required');
      return;
    }

    this.joinRoom(roomId, ws);

    // heartbeat
    const interval = setInterval(() => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.ping();
      }
    }, 30000);

    ws.on('message', (data) => {
      try {
        const event: ClientEvent = JSON.parse(data.toString());
        this.handleEvent(roomId, ws, event);
      } catch (e) {
        ws.send(JSON.stringify({ type: 'ERROR', payload: { message: 'Invalid message format' } }));
      }
    });

    ws.on('close', () => {
      clearInterval(interval);
      this.leaveRoom(roomId, ws);
    });
  }

  broadcast(roomId: string, event: ServerEvent, exclude?: WebSocket) {
    const room = this.rooms.get(roomId);
    if (!room) return;
    const message = JSON.stringify(event);
    room.forEach((client) => {
      if (client !== exclude && client.readyState === WebSocket.OPEN) {
        client.send(message);
      }
    });
  }
}
```

### 클라이언트 WebSocket 훅

```typescript
// client/src/hooks/useSocket.ts
import { useRef, useCallback, useEffect } from 'react';
import { useAppStore } from '@/stores/appStore';
import type { ClientEvent, ServerEvent } from '@myapp/shared';

const WS_URL = import.meta.env.VITE_WS_URL;

export const useSocket = (roomId: string) => {
  const socketRef = useRef<WebSocket | null>(null);
  const reconnectAttempts = useRef(0);
  const maxReconnectAttempts = 5;
  const { setState, addNotification } = useAppStore();

  const connect = useCallback(() => {
    if (reconnectAttempts.current >= maxReconnectAttempts) return;

    const ws = new WebSocket(`${WS_URL}/room/${roomId}`);

    ws.onopen = () => {
      reconnectAttempts.current = 0;
      console.log('[WS] Connected to room:', roomId);
    };

    ws.onmessage = (event) => {
      const serverEvent: ServerEvent = JSON.parse(event.data);
      switch (serverEvent.type) {
        case 'STATE_UPDATE':
          setState(serverEvent.payload);
          break;
        case 'NOTIFICATION':
          addNotification(serverEvent.payload);
          break;
        // ... 다른 이벤트 핸들러
      }
    };

    ws.onclose = (event) => {
      if (!event.wasClean) {
        const delay = Math.min(1000 * 2 ** reconnectAttempts.current, 30000);
        console.log(`[WS] Reconnecting in ${delay}ms...`);
        setTimeout(connect, delay);
        reconnectAttempts.current++;
      }
    };

    ws.onerror = (error) => {
      console.error('[WS] Error:', error);
    };

    socketRef.current = ws;
  }, [roomId, setState, addNotification]);

  const sendEvent = useCallback((event: ClientEvent) => {
    if (socketRef.current?.readyState === WebSocket.OPEN) {
      socketRef.current.send(JSON.stringify(event));
    }
  }, []);

  useEffect(() => {
    connect();
    return () => {
      socketRef.current?.close(1000, 'Component unmounted');
    };
  }, [connect]);

  return { sendEvent, isConnected: socketRef.current?.readyState === WebSocket.OPEN };
};
```

---

## 5. Prisma 스키마 예시

```prisma
// server/prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id            String    @id @default(cuid())
  email         String    @unique
  nickname      String
  avatarUrl     String?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  memberships   Member[]
  createdRooms  Room[]    @relation("RoomCreator")
}

model Room {
  id          String      @id @default(cuid())
  code        String      @unique
  name        String
  maxMembers  Int         @default(10)
  status      RoomStatus  @default(WAITING)
  creatorId   String
  creator     User        @relation("RoomCreator", fields: [creatorId], references: [id])
  createdAt   DateTime    @default(now())

  sessions    Session[]
  members     Member[]
}

model Session {
  id          String    @id @default(cuid())
  roomId      String
  room        Room      @relation(fields: [roomId], references: [id])
  data        Json?
  startedAt   DateTime  @default(now())
  endedAt     DateTime?

  activities  Activity[]
}

model Member {
  id        String    @id @default(cuid())
  userId    String
  user      User      @relation(fields: [userId], references: [id])
  roomId    String
  room      Room      @relation(fields: [roomId], references: [id])
  role      String    @default("member")
  isActive  Boolean   @default(true)

  activities Activity[]

  @@unique([userId, roomId])
}

model Activity {
  id          String    @id @default(cuid())
  sessionId   String
  session     Session   @relation(fields: [sessionId], references: [id])
  memberId    String
  member      Member    @relation(fields: [memberId], references: [id])
  type        String
  data        Json?
  createdAt   DateTime  @default(now())
}

enum RoomStatus {
  WAITING
  ACTIVE
  FINISHED
}
```

### Prisma 클라이언트 초기화

```typescript
// server/src/db/prisma.ts
import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient };

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
```

---

## 6. Zustand 스토어 패턴

### 앱 스토어

```typescript
// client/src/stores/appStore.ts
import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import type { AppState, Notification } from '@myapp/shared';

interface AppStore {
  // 상태
  appState: AppState | null;
  notifications: Notification[];
  isConnected: boolean;

  // 액션
  setState: (state: AppState) => void;
  addNotification: (notification: Notification) => void;
  setConnected: (connected: boolean) => void;
  reset: () => void;
}

export const useAppStore = create<AppStore>()(
  devtools(
    (set) => ({
      appState: null,
      notifications: [],
      isConnected: false,

      setState: (appState) => set({ appState }),
      addNotification: (notification) =>
        set((state) => ({
          notifications: [...state.notifications.slice(-99), notification], // 최대 100개 유지
        })),
      setConnected: (isConnected) => set({ isConnected }),
      reset: () =>
        set({
          appState: null,
          notifications: [],
          isConnected: false,
        }),
    }),
    { name: 'app-store' },
  ),
);
```

### 인증 스토어

```typescript
// client/src/stores/authStore.ts
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface AuthStore {
  user: { id: string; nickname: string; email?: string } | null;
  token: string | null;
  login: (token: string, user: AuthStore['user']) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthStore>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      login: (token, user) => set({ token, user }),
      logout: () => set({ token: null, user: null }),
    }),
    { name: 'auth-storage' },
  ),
);
```

---

## 7. Framer Motion 애니메이션 패턴

### 리스트 아이템 애니메이션

```typescript
// client/src/components/AnimatedListItem.tsx
import { motion, AnimatePresence } from 'framer-motion';

interface AnimatedListItemProps {
  children: React.ReactNode;
  index: number;
  isVisible: boolean;
}

export const AnimatedListItem = ({ children, index, isVisible }: AnimatedListItemProps) => (
  <motion.div
    initial={{ x: -20, opacity: 0 }}
    animate={{ x: 0, opacity: 1 }}
    exit={{ x: 20, opacity: 0 }}
    transition={{
      type: 'spring',
      stiffness: 260,
      damping: 20,
      delay: index * 0.1,
    }}
    className="p-4 rounded-lg shadow-card"
  >
    {children}
  </motion.div>
);
```

### 요소 이동 애니메이션

```typescript
// client/src/components/SlideAnimation.tsx
import { motion } from 'framer-motion';

interface SlideAnimationProps {
  children: React.ReactNode;
  fromPosition: { x: number; y: number };
  toPosition: { x: number; y: number };
}

export const SlideAnimation = ({ children, fromPosition, toPosition }: SlideAnimationProps) => (
  <motion.div
    initial={{ x: fromPosition.x, y: fromPosition.y, scale: 0 }}
    animate={{ x: toPosition.x, y: toPosition.y, scale: 1 }}
    transition={{ type: 'spring', stiffness: 300, damping: 25 }}
    className="absolute"
  >
    {children}
  </motion.div>
);
```

---

## 8. 외부 서비스 연동

### 외부 API 클라이언트

```typescript
// client/src/lib/externalApi.ts
const API_BASE_URL = import.meta.env.VITE_EXTERNAL_API_URL;

export const externalApi = {
  async get<T>(endpoint: string): Promise<T> {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      headers: { 'Content-Type': 'application/json' },
    });
    if (!response.ok) throw new Error(`API error: ${response.status}`);
    return response.json();
  },

  async post<T>(endpoint: string, data: unknown): Promise<T> {
    const response = await fetch(`${API_BASE_URL}${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!response.ok) throw new Error(`API error: ${response.status}`);
    return response.json();
  },
};
```

### 서버 사이드 외부 서비스 연동

```typescript
// server/src/services/externalService.ts
import { z } from 'zod';

const responseSchema = z.object({
  id: z.string(),
  status: z.string(),
  data: z.unknown(),
});

export const callExternalService = async (payload: unknown) => {
  const response = await fetch(process.env.EXTERNAL_SERVICE_URL!, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.EXTERNAL_SERVICE_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`External service error: ${response.status}`);
  }

  const json = await response.json();
  return responseSchema.parse(json);
};
```

---

## 9. 환경변수 (.env) 설정 가이드

### .env.example (커밋 대상)

```env
# ===== Server =====
NODE_ENV=development
API_PORT=3000
WS_PORT=3001
DATABASE_URL=postgresql://postgres:password@localhost:5432/myapp
JWT_SECRET=your-jwt-secret-here
SESSION_SECRET=your-session-secret-here

# ===== Client =====
VITE_API_URL=http://localhost:3000
VITE_WS_URL=ws://localhost:3001

# ===== External Services =====
EXTERNAL_SERVICE_URL=https://api.example.com
EXTERNAL_SERVICE_API_KEY=your-api-key-here

# ===== Optional =====
LOG_LEVEL=debug
SENTRY_DSN=
```

### 환경변수 접근 패턴

```typescript
// server: process.env 직접 접근 (dotenv)
import 'dotenv/config';
const port = parseInt(process.env.API_PORT || '3000', 10);

// client: import.meta.env 접근 (Vite - VITE_ 접두사 필수)
const apiUrl = import.meta.env.VITE_API_URL;
```

### 환경변수 유효성 검사 (서버)

```typescript
// server/src/config/env.ts
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  API_PORT: z.coerce.number().default(3000),
  WS_PORT: z.coerce.number().default(3001),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
});

export const env = envSchema.parse(process.env);
```

---

## 10. 모노레포 (pnpm + Turborepo) 설정

### pnpm-workspace.yaml

```yaml
packages:
  - 'client'
  - 'server'
  - 'shared'
```

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {},
    "test": {
      "dependsOn": ["build"]
    },
    "typecheck": {
      "dependsOn": ["^build"]
    }
  }
}
```

### 주요 명령어

```bash
# 전체 빌드
pnpm turbo build

# 특정 패키지만 빌드
pnpm --filter shared build
pnpm --filter client build

# 개발 모드 (전체)
pnpm turbo dev

# 개발 모드 (특정 패키지)
pnpm --filter client dev
pnpm --filter server dev

# 테스트
pnpm turbo test

# 타입 체크
pnpm turbo typecheck

# Prisma 마이그레이션
pnpm --filter server prisma migrate dev --name <name>
pnpm --filter server prisma generate
```

---

*이 문서는 프로젝트의 기술 스택별 코드 스니펫 및 설정 가이드입니다.*
