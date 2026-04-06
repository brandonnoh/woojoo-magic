---
description: Ralph v2 자율 개발 루프 설치 + 작업 문서 일괄 준비 (--force-code로 안전한 코드 업그레이드)
argument-hint: "[--force-code] [--force] [--no-backup]"
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치하고, **부족한 작업 문서를 일괄 생성**하라.

## 사용자 인자

`$ARGUMENTS` — 다음 옵션 해석:

| 인자 | 동작 |
|------|------|
| (없음) | **safe**: 기존 파일 전부 보존, 없는 것만 생성 |
| `--force-code` | **코드만** 덮어쓰기. PRD/tests.json/progress.md는 보존 ⭐ 권장 |
| `--force` | **전체** 덮어쓰기 (코드 + 데이터) ⚠️ 주의 |
| `--no-backup` | 백업 생략 (`--force*`와 함께, 권장 안 함) |

## 실행 절차

### Step 1: Ralph 코드 설치

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh" $ARGUMENTS
```

### Step 2: 누락 작업 문서 점검 + 일괄 생성

install.sh 실행 후, 아래 파일들의 존재 여부를 점검하고 **없는 것만** 생성한다.
**이미 존재하는 파일은 절대 건드리지 않는다.**

#### 2-1. `smoke-test.sh` (E2E smoke test)
- **없으면**: 프로젝트 스택을 감지하고 smoke-test.sh를 자동 생성한다.
  - `package.json` → 프레임워크 감지 (Express, Fastify, Next.js 등)
  - 서버 디렉토리 탐색 (server/, api/, backend/)
  - 핵심 API 라우트 탐색 → curl 기반 smoke test 생성
  - 최소 포함: health check, 인증, 핵심 기능 1개
  - 실행 확인: `bash smoke-test.sh`
- **있으면**: `[init] ✅ smoke-test.sh 이미 존재 — skip`

#### 2-2. `specs/` (상세 기획 문서)
- **tests.json이 있고 specs/ 디렉토리에 누락된 spec이 있으면**:
  - tests.json의 `features[]` 배열을 읽는다
  - 각 task의 `spec` 필드 경로 (기본: `specs/{task-id}.md`)를 확인
  - **파일이 없는 task만** spec을 생성한다
  - spec 내용: task의 `acceptance_criteria`, `affected_packages`, `depends_on`을 기반으로 상세 설계 작성
  - 포함 항목: 목적, 구현 범위, 파일 변경 목록, 엣지 케이스, 테스트 시나리오
  - 출력: `[init] ✅ spec 생성: specs/{task-id}.md` (task별)
- **tests.json이 없으면**: skip (init-prd로 먼저 생성해야 함)
- **모든 spec이 있으면**: `[init] ✅ specs/ 전체 존재 — skip`

#### 2-3. `prd.md`, `tests.json`, `progress.md`
- install.sh가 이미 처리함 (없을 때만 빈 템플릿 생성)
- **이미 존재하면 절대 건드리지 않는다**

### Step 3: 결과 요약

```
✅ Ralph v2 준비 완료

📁 코드:    ralph.sh, lib/, prompts/, schemas/ — {설치됨/최신화됨}
📋 PRD:     prd.md — {생성됨/이미 존재}
📋 Tasks:   tests.json — {생성됨/이미 존재} ({N}개 task, {M}개 passing)
📋 Specs:   specs/ — {N}개 생성, {M}개 기존
🔬 Smoke:   smoke-test.sh — {생성됨/이미 존재}
📊 상태:    .ralph-state/ — 초기화됨

🚀 다음: bash ralph.sh --dry-run
```

- tests.json이 비어있으면: `⚠️ tests.json이 비어있습니다. /wj:init-prd로 태스크를 정의하세요.`
- prd.md가 빈 템플릿이면: `⚠️ prd.md가 비어있습니다. 요구사항을 작성하거나 /wj:init-prd를 실행하세요.`

## 파일 카테고리

**CODE (플러그인 소스, 업그레이드 안전)**
- `ralph.sh`, `lib/`, `prompts/`, `schemas/`

**DATA (사용자 작성, 업그레이드 위험 → 보존 우선)**
- `prd.md`, `tests.json`, `progress.md`, `specs/`, `smoke-test.sh`

## 모드별 동작

| 모드 | CODE | DATA | 백업 |
|------|------|------|------|
| (없음) | 없을 때만 생성 | 없을 때만 생성 | 없음 |
| `--force-code` | **백업 후 덮어쓰기** | 스킵 (보존) | `.wj-backup-<ts>/` |
| `--force` | **백업 후 덮어쓰기** | **백업 후 덮어쓰기** | `.wj-backup-<ts>/` |

**Step 2 (누락 문서 생성)는 모든 모드에서 동일하게 동작한다** — 없는 파일만 생성.

## 실전 시나리오

### A. 새 프로젝트
```
/wj:init
```
→ 코드 설치 + 빈 템플릿 생성 + smoke-test.sh 생성
→ 이후 `/wj:init-prd`로 태스크 정의

### B. 기존 프로젝트 플러그인 업데이트 ⭐
```
/wj:init --force-code
```
→ Ralph 코드만 최신화
→ 기존 prd.md/tests.json 보존
→ **누락된 specs/ 일괄 생성, smoke-test.sh 생성**
→ 바로 `bash ralph.sh --iter 10` 가능

### C. 전부 초기화
```
/wj:init --force
```
→ 전체 덮어쓰기 (백업 생성)
