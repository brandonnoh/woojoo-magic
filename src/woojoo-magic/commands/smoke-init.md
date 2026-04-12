---
description: Ralph smoke-test.sh 생성 — 프로젝트 스택에 맞는 E2E smoke test 자동 구성
---

# Smoke Test 생성기

프로젝트 스택을 감지하고, 핵심 플로우를 자동 검증하는 `smoke-test.sh`를 생성한다.

## 절차

### 1. 스택 감지
다음을 확인하여 프로젝트 유형을 판단한다:
- `package.json` → scripts에 `start`, `dev`, `serve` 중 어떤 것이 있는지
- 모노레포 여부 → `pnpm-workspace.yaml` 또는 `package.json` workspaces
- 서버 패키지 → `server/`, `api/`, `backend/` 디렉토리 또는 `*-server` 패키지
- 프레임워크 → Express, Fastify, Nest, Next.js, Hono 등 (package.json dependencies)
- DB → Prisma, Drizzle, TypeORM, Supabase 등
- 인증 → JWT, Passport, Lucia, Auth.js 등

### 2. 엔드포인트 탐색
서버 코드에서 핵심 API 라우트를 탐색한다:
- `app.get/post/put/delete`, `router.*` 패턴
- `/health`, `/api/auth/*`, `/api/sessions/*` 등 핵심 경로
- 미들웨어 체인 (인증 필수 vs 공개)

### 3. smoke-test.sh 생성
탐색 결과를 바탕으로 `smoke-test.sh`를 생성한다:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

필수 포함 항목:
- **서버 기동** — 감지된 start 명령 사용, `&`로 백그라운드, `trap cleanup EXIT`
- **서버 대기** — health 엔드포인트 폴링 (최대 15초)
- **핵심 플로우** — 최소 3단계:
  1. Health check
  2. 인증 (게스트/로그인)
  3. 핵심 기능 1개 (세션 생성, 데이터 조회 등)
- **각 단계별 성공/실패 출력** — `[smoke] OK <step-name>` / `[smoke] FAIL <step-name>`
- **환경 변수 분기** — `SMOKE_PORT`, `DATABASE_URL` 등 필요 시

### 4. 검증
- `bash smoke-test.sh`를 실행하여 정상 동작 확인
- 실패하면 원인 파악 후 수정
- `.env` 유무 양쪽에서 서버가 뜨는지 확인

### 5. .gitignore 확인
- `smoke-test.sh`는 커밋 대상 (gitignore에 추가하지 말 것)

## 출력 형식
완료 시 아래 형식으로 보고:

```
[smoke-init] 스택: {pm} + {framework} + {db}
[smoke-init] 감지된 엔드포인트: N개
[smoke-init] smoke-test.sh 생성 완료
[smoke-init] 검증 항목:
  1. health → /health
  2. auth → /api/auth/guest
  3. core → /api/sessions (POST)
```

## Guardrails
- 기존 `smoke-test.sh`가 있으면 **덮어쓰지 말고** 사용자에게 확인
- 서버가 뜨지 않으면 `.env.example` 또는 `.env.test` 참조
- DB 의존 테스트는 가능하면 피하거나, 인메모리/테스트 DB 사용

---

## 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 위 절차대로 실행하라.**
