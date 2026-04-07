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
`/wj:spec-init` 커맨드와 동일한 로직을 실행한다:
- tests.json의 `features[]` 순회 → 각 task에 대해:
  - `specs/{task-id}.md` **파일이 없으면** → spec 템플릿으로 생성 (배경, Acceptance Criteria, 설계, 구현 가이드, 파일 변경 목록, Edge Cases, 회귀 체크, 의존성)
  - **파일이 있으면** → acceptance_criteria가 spec에 전부 반영됐는지 검증 → 누락 항목 append
  - 출력: `[init] ✅ spec 생성: specs/{task-id}.md` 또는 `[init] ✅ spec 검증 OK`
- **spec 템플릿 상세는 `/wj:spec-init` 커맨드 참조**

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

---

## ⚡ 즉시 실행 — 반드시 Step 1~3 전부 수행

**install.sh 실행(Step 1)만으로 끝내지 마라. Step 2, Step 3까지 전부 수행해야 init이 완료된다.**

1. `bash install.sh $ARGUMENTS` 실행 (Step 1)
2. `prd.md` Read → `tests.json` Read → 정합성 대조 → 불일치 보고/수정 (Step 2-1)
3. `tests.json` features 순회 → `specs/{task-id}.md` 존재+내용 검증 → 누락분 생성 (Step 2-2)
4. `smoke-test.sh` 존재 확인 → 없으면 스택 감지 후 생성 (Step 2-3)
5. 결과 요약 출력 (Step 3)

**Step 1만 실행하고 "완료"라고 보고하는 것은 init 미완료다.**
