---
description: Ralph v2 자율 개발 루프 설치 + 작업 문서 일괄 준비
argument-hint: "[--force] [--no-backup]"
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치하고, **부족한 작업 문서를 일괄 생성**하라.

## 핵심 원칙

- **CODE(ralph.sh, lib/, prompts/, schemas/)는 항상 최신 덮어쓰기** — 플러그인 소스이므로 매번 최신화가 기본
- **DATA(prd.md, tests.json, progress.md)는 보존 우선** — 없을 때만 빈 템플릿 생성
- **누락 문서(specs/, smoke-test.sh)는 자동 보충** — install.sh 실행 후 Claude가 점검+생성

## 사용자 인자

`$ARGUMENTS` — 다음 옵션 해석:

| 인자 | 동작 |
|------|------|
| (없음) | CODE 최신화 + DATA 보존 + 누락 문서 생성 |
| `--force` | CODE 최신화 + **DATA 백업 후 덮어쓰기** ⚠️ 전체 초기화 |
| `--no-backup` | 백업 생략 (`--force`와 함께, 권장 안 함) |

## 실행 절차

### Step 1: Ralph 코드 설치

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh" $ARGUMENTS
```

### Step 2: 문서 정합성 검증 + 누락 보충

install.sh 실행 후, **prd.md ↔ tests.json ↔ specs/ 간 정합성을 검증**하고 빠진 것을 채운다.

#### 2-1. prd.md ↔ tests.json 정합성 검증
- prd.md의 `[ ]`/`[x]` task 목록과 tests.json의 `features[]` 배열을 대조
- **불일치 발견 시 보고 + 수정 제안:**
  - prd.md에 있는데 tests.json에 없는 task → `⚠️ tests.json에 누락: {task-id}` → tests.json에 추가할지 사용자에게 확인
  - tests.json에 있는데 prd.md에 없는 task → `⚠️ prd.md에 누락: {task-id}` → prd.md에 추가
  - status 불일치 (prd.md `[x]`인데 tests.json `pending`, 또는 그 반대) → 보고
- **tests.json 필수 필드 검증** — 각 feature에 `id`, `acceptance_criteria`, `affected_packages`, `status` 존재하는지
  - 빠진 필드 있으면 → `⚠️ {task-id}: acceptance_criteria 없음` → 보충
- prd.md/tests.json 둘 다 비어있으면: `⚠️ /wj:init-prd로 태스크를 정의하세요.`

#### 2-2. specs/ 정합성 검증 + 생성
- tests.json의 `features[]` 순회 → 각 task에 대해:
  - `specs/{task-id}.md` **파일 존재** 확인
  - **파일이 없으면** → task의 `acceptance_criteria`, `affected_packages`, `depends_on`을 기반으로 spec 생성
  - **파일이 있으면** → 내용이 acceptance_criteria와 매칭되는지 간략 검증
    - spec에 acceptance_criteria 항목이 반영 안 됐으면 → `⚠️ {task-id} spec 업데이트 필요` → 누락 항목 append
  - spec 포함 항목: 목적, 구현 범위, 파일 변경 목록, 엣지 케이스, 테스트 시나리오
  - 출력: `[init] ✅ spec 생성: specs/{task-id}.md` 또는 `[init] ✅ spec 검증 OK`

#### 2-3. smoke-test.sh
- **없으면**: 프로젝트 스택 감지 → smoke-test.sh 생성
  - `package.json` → 프레임워크 감지 (Express, Fastify, Next.js 등)
  - 서버 디렉토리 탐색 (server/, api/, backend/)
  - 핵심 API 라우트 탐색 → curl 기반 smoke test 생성
  - 최소 포함: health check, 인증, 핵심 기능 1개
- **있으면**: `[init] ✅ smoke-test.sh 이미 존재 — skip`

### Step 3: 결과 요약

```
✅ Ralph v2 준비 완료

📁 코드:     ralph.sh, lib/, prompts/, schemas/ — 최신화됨
📋 PRD:      prd.md — {N}개 task ({M}개 완료)
📋 Tasks:    tests.json — {N}개 feature, 정합성 {OK/N건 수정}
📋 Specs:    specs/ — {N}개 생성, {M}개 검증OK, {K}개 업데이트
🔬 Smoke:    smoke-test.sh — {생성됨/이미 존재}

🚀 다음: bash ralph.sh --dry-run
```

## 파일 카테고리

**CODE (플러그인 소스, 업그레이드 안전)**
- `ralph.sh`, `lib/`, `prompts/`, `schemas/`

**DATA (사용자 작성, 업그레이드 위험 → 보존 우선)**
- `prd.md`, `tests.json`, `progress.md`, `specs/`, `smoke-test.sh`

## 모드별 동작

| 모드 | CODE | DATA | 백업 |
|------|------|------|------|
| (없음) | **항상 최신화** | 없을 때만 생성 | CODE만 백업 |
| `--force` | **항상 최신화** | **백업 후 덮어쓰기** | CODE+DATA 백업 |

**Step 2 (누락 문서 생성)는 모든 모드에서 동일하게 동작한다** — 없는 파일만 생성.

## 실전 시나리오

### A. 새 프로젝트 / 기존 프로젝트 업데이트 (동일)
```
/wj:init
```
→ Ralph 코드 최신화 + 기존 prd.md/tests.json 보존
→ 누락된 specs/ 일괄 생성, smoke-test.sh 생성
→ 바로 `bash ralph.sh --iter 10` 가능

### B. 전부 초기화
```
/wj:init --force
```
→ 전체 덮어쓰기 (백업 생성)
