# 트러블슈팅 가이드

> 개발 중 발생하는 에러와 해결 방법 정리

**최종 업데이트**: 2026-03-18

---

## 1. Vite HMR (Hot Module Replacement) 이슈

### 증상: 코드 변경 시 전체 페이지가 리로드됨

```
[vite] page reload  src/components/MyComponent.tsx
```

### 원인

- 모듈 최상위 레벨에서 사이드 이펙트가 발생하는 코드
- React 컴포넌트가 default export가 아닌 경우
- 순환 참조(circular dependency)가 있는 경우

### 해결 방법

```typescript
// ❌ HMR 깨짐 - named export만 사용
export const MyComponent = () => { ... };

// ✅ HMR 정상 작동 - React.memo나 일반 함수 컴포넌트 + named export
// Vite React plugin은 named export도 지원하지만,
// 파일에 React 컴포넌트 외 다른 export가 섞이면 HMR이 깨짐
// 한 파일에 하나의 컴포넌트만 export할 것

// ❌ HMR 깨짐 - 컴포넌트와 유틸 혼재
export const formatCurrency = (n: number) => `${n}`;
export const MyComponent = () => { ... };

// ✅ 분리
// utils/format.ts
export const formatCurrency = (n: number) => `${n}`;

// components/MyComponent.tsx
export const MyComponent = () => { ... };
```

### 순환 참조 디버깅

```bash
# madge로 순환 참조 탐지
npx madge --circular --extensions ts,tsx client/src/
```

---

## 2. WebSocket 연결 끊김/재연결

### 증상: 실시간 통신 중 WebSocket 연결이 끊어지고 상태 동기화가 안됨

```
WebSocket connection to 'ws://localhost:3001/room/abc123' failed
```

### 원인

| 원인 | 확인 방법 |
|------|----------|
| 서버 미실행 | `lsof -i :3001` 로 포트 확인 |
| 프록시 타임아웃 | Nginx/Cloudflare WebSocket 타임아웃 설정 확인 |
| heartbeat 미구현 | 30초 이상 무통신 시 일부 프록시가 연결 종료 |
| 브라우저 탭 비활성화 | `visibilitychange` 이벤트로 재연결 트리거 |

### 해결 방법

```typescript
// 1. Exponential backoff 재연결
const reconnect = (attempts: number) => {
  const delay = Math.min(1000 * 2 ** attempts, 30000);
  setTimeout(() => connect(), delay);
};

// 2. Heartbeat 구현 (서버)
const HEARTBEAT_INTERVAL = 30000;
ws.on('pong', () => { ws.isAlive = true; });

setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL);

// 3. 브라우저 탭 복귀 시 재연결
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && !isConnected) {
    connect();
  }
});

// 4. 재연결 후 상태 동기화
ws.onopen = () => {
  // 재연결 시 서버에 현재 상태 요청
  ws.send(JSON.stringify({ type: 'REQUEST_SYNC' }));
};
```

### Nginx WebSocket 프록시 설정

```nginx
location /ws/ {
    proxy_pass http://localhost:3001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400;  # 24시간 (기본 60초)
}
```

---

## 3. CORS 설정 에러

### 에러 메시지

```
Access to fetch at 'http://localhost:3000/api/data' from origin 'http://localhost:5173'
has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present
```

### 원인

Express 서버에 CORS 미들웨어가 없거나 origin 설정이 잘못됨

### 해결 방법

```typescript
// server/src/app.ts
import cors from 'cors';

app.use(cors({
  origin: process.env.CLIENT_URL || 'http://localhost:5173',
  credentials: true,  // 쿠키/인증 헤더 허용
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
```

### 환경별 CORS 설정

```typescript
const corsOptions = {
  origin: process.env.NODE_ENV === 'production'
    ? ['https://yourdomain.com']
    : ['http://localhost:5173', 'http://localhost:3000'],
  credentials: true,
};
```

### WebSocket CORS

WebSocket은 CORS 정책을 적용받지 않지만, 보안을 위해 Origin 헤더 검증 권장:

```typescript
wss.on('connection', (ws, req) => {
  const origin = req.headers.origin;
  const allowedOrigins = ['http://localhost:5173', 'https://yourdomain.com'];

  if (origin && !allowedOrigins.includes(origin)) {
    ws.close(1008, 'Origin not allowed');
    return;
  }
});
```

---

## 4. Prisma 마이그레이션 에러

### 에러: `Migration failed to apply cleanly`

```
Error: P3006 - Migration failed to apply cleanly to the shadow database.
```

### 원인

- 스키마 변경이 기존 데이터와 충돌 (NOT NULL 컬럼 추가 등)
- 마이그레이션 파일이 수동 편집됨
- 데이터베이스 상태와 마이그레이션 히스토리 불일치

### 해결 방법

```bash
# 1. 개발 중: DB 초기화 후 재마이그레이션 (데이터 손실!)
pnpm --filter server prisma migrate reset

# 2. NOT NULL 컬럼 추가 시: 기본값 지정
# schema.prisma
# ❌
# newColumn  String

# ✅
# newColumn  String  @default("")

# 3. 마이그레이션 히스토리 불일치 시
pnpm --filter server prisma migrate resolve --applied <migration_name>

# 4. Prisma Client 재생성
pnpm --filter server prisma generate
```

### 에러: `Can't reach database server`

```
Error: P1001 - Can't reach database server at `localhost:5432`
```

```bash
# PostgreSQL 실행 확인
brew services list | grep postgresql
# 또는
pg_isready

# PostgreSQL 시작
brew services start postgresql@16

# DATABASE_URL 확인
echo $DATABASE_URL
# postgresql://postgres:password@localhost:5432/myapp
```

### 에러: `The database schema is not empty`

```bash
# 기존 DB에 첫 마이그레이션 적용 시
pnpm --filter server prisma db push  # 마이그레이션 없이 스키마 동기화
# 또는
pnpm --filter server prisma migrate dev --create-only  # SQL만 생성
```

---

## 5. TypeScript 빌드 에러

### 에러: `Cannot find module '@myapp/shared'`

```
error TS2307: Cannot find module '@myapp/shared' or its corresponding type declarations.
```

### 원인

모노레포 패키지 간 참조가 제대로 설정되지 않음

### 해결 방법

```bash
# 1. shared 패키지 빌드
pnpm --filter shared build

# 2. 의존성 재설치
pnpm install

# 3. TypeScript 프로젝트 참조 확인
# tsconfig.json에 references 추가
```

```json
// client/tsconfig.json
{
  "references": [{ "path": "../shared" }]
}
```

```json
// shared/package.json
{
  "name": "@myapp/shared",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "exports": {
    ".": {
      "import": "./dist/index.js",
      "types": "./dist/index.d.ts"
    }
  }
}
```

### 에러: `Type 'X' is not assignable to type 'Y'`

shared 타입을 변경한 후 발생:

```bash
# shared 리빌드 후 의존 패키지 타입체크
pnpm --filter shared build && pnpm turbo typecheck
```

### 에러: `ESM/CJS 모듈 호환성`

```
Error [ERR_REQUIRE_ESM]: require() of ES Module ... not supported
```

```json
// package.json에서 모듈 시스템 통일
{
  "type": "module"
}
```

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "module": "ESNext",
    "moduleResolution": "bundler"  // 또는 "nodenext"
  }
}
```

---

## 6. TailwindCSS 커스텀 테마 적용 이슈

### 증상: 커스텀 색상/애니메이션이 적용되지 않음

### 원인

| 원인 | 확인 방법 |
|------|----------|
| `content` 경로 누락 | `tailwind.config.ts`의 `content` 배열 확인 |
| 빌드 캐시 | `node_modules/.vite` 삭제 후 재시작 |
| CSS import 누락 | `main.tsx`에서 `globals.css` import 확인 |
| JIT 모드 동적 클래스 | 동적 클래스명은 safelist에 추가 |

### 해결 방법

```typescript
// tailwind.config.ts - content 경로 확인
export default {
  content: [
    './index.html',
    './src/**/*.{js,ts,jsx,tsx}',
    // shared 컴포넌트도 포함
    '../shared/src/**/*.{js,ts,jsx,tsx}',
  ],
};
```

```css
/* client/src/styles/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

### 동적 클래스명 문제

```typescript
// ❌ TailwindCSS는 동적 문자열 조합을 감지 못함
const color = isActive ? 'green' : 'red';
<div className={`bg-${color}-500`} />

// ✅ 전체 클래스명을 명시
const bgClass = isActive ? 'bg-green-500' : 'bg-red-500';
<div className={bgClass} />

// ✅ 또는 safelist 사용
// tailwind.config.ts
{
  safelist: [
    'bg-green-500', 'bg-red-500',
    { pattern: /bg-(brand-primary|status-error|status-success)/ },
  ]
}
```

---

## 7. 환경변수 미설정 에러

### 증상: 서버 시작 시 크래시

```
Error: Required environment variable 'DATABASE_URL' is missing
```

### 확인 체크리스트

```bash
# 1. .env 파일 존재 확인
ls -la server/.env

# 2. .env.example에서 복사
cp server/.env.example server/.env

# 3. 값 채우기 (에디터로 열어서 편집)

# 4. dotenv 로드 확인 (서버 진입점 최상단)
# import 'dotenv/config';
```

### Vite 환경변수 접두사

```bash
# ❌ Vite에서 접근 불가 (VITE_ 접두사 없음)
API_URL=http://localhost:3000

# ✅ Vite에서 접근 가능
VITE_API_URL=http://localhost:3000
```

```typescript
// 클라이언트에서 접근
console.log(import.meta.env.VITE_API_URL);      // ✅ 접근 가능
console.log(import.meta.env.DATABASE_URL);        // ❌ undefined (서버 전용)
```

### 환경별 .env 파일 우선순위 (Vite)

```
.env                # 항상 로드
.env.local          # 항상 로드, gitignore 대상
.env.[mode]         # 해당 모드에서만 로드
.env.[mode].local   # 해당 모드에서만 로드, gitignore 대상
```

---

## 8. pnpm 모노레포 의존성 이슈

### 에러: `ERR_PNPM_PEER_DEP_ISSUES`

```bash
# strict peer dependencies 무시 (개발 중)
# .npmrc
strict-peer-dependencies=false
```

### 에러: 패키지 간 의존성 해결 실패

```bash
# 1. 전체 의존성 재설치
rm -rf node_modules && rm -rf */node_modules && pnpm install

# 2. 특정 패키지 의존성 확인
pnpm --filter client list --depth 0

# 3. 패키지 간 참조 추가
pnpm --filter client add @myapp/shared --workspace
```

---

## 9. GitHub Actions CI 에러

### 에러: `pnpm install` 실패

```yaml
# .github/workflows/ci.yml
- uses: pnpm/action-setup@v4
  with:
    version: 9  # 프로젝트의 pnpm 버전과 일치

- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'pnpm'

- run: pnpm install --frozen-lockfile
```

### 에러: Prisma Client 생성 실패 (CI 환경)

```yaml
- name: Generate Prisma Client
  run: pnpm --filter server prisma generate
  # CI에서는 DB 연결 없이도 클라이언트 생성 가능
```

### 에러: Vitest 타임아웃

```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    testTimeout: 10000,  // 기본 5000ms → 10000ms
    hookTimeout: 10000,
  },
});
```

---

## 빠른 참조: 포트 & URL 가이드

| 서비스 | 포트 | URL |
|--------|------|-----|
| Vite Dev Server | 5173 | http://localhost:5173 |
| Express API | 3000 | http://localhost:3000 |
| WebSocket | 3001 | ws://localhost:3001 |
| PostgreSQL | 5432 | localhost:5432 |
| Prisma Studio | 5555 | http://localhost:5555 |

---

## 체크리스트: 개발 환경 시작 시

- [ ] PostgreSQL 실행 중 (`brew services start postgresql@16`)
- [ ] `.env` 파일 설정 완료 (server/, client/)
- [ ] `pnpm install` 완료
- [ ] `pnpm --filter shared build` 완료
- [ ] `pnpm --filter server prisma generate` 완료
- [ ] `pnpm --filter server prisma migrate dev` 완료
- [ ] `pnpm turbo dev` 로 개발 서버 시작

---

*이 문서는 개발 중 발생한 에러를 기록하고 해결 방법을 정리한 것입니다.*
*새로운 에러 발생 시 이 문서를 업데이트하세요.*
