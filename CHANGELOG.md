# Changelog

## 1.2.3 — 2026-04-06

### Fixed
- **하우스키핑 커밋 hook 실패 시 루프 중단 방지**: post-gate·pre-gate의 하우스키핑 커밋에 `--no-verify` 추가. pre-commit hook 실패 시 양쪽 커밋이 모두 실패하여 dirty tree로 루프가 중단되던 edge case 수정.

## 1.2.2 — 2026-04-06

### Fixed (Ralph v2 P0)
- **Worker의 tests.json 배열 파괴 방지**: Worker(sonnet)가 task 완료 시 features 배열 전체를 유지하지 않고 단일 task 객체만 Write하여 35개 배열이 1개로 파괴되던 문제. worker.md/implement-next에 Read-Modify-Write 5단계 명시 + ⛔ 경고 추가.
- **Quality Gate tests.json 무결성 검증 추가**: features 배열 2개 미만 시 즉시 FAIL + features 개수와 summary 합계 불일치 시 FAIL. Worker가 배열을 파괴해도 Quality Gate에서 잡혀 rollback 수행.

## 1.2.1 — 2026-04-06

### Fixed (Ralph v2 P0)
- **post-gate 하우스키핑 미커밋으로 iter 2+ 차단**: `post-gate.sh`가 worker commit 이후에 `tests.json` summary를 재계산하고 `progress.md`에 iteration 로그를 append하면서도 이 변경을 커밋하지 않아, 다음 iteration의 pre-gate가 `M tests.json` / `M progress.md` dirty tree로 즉시 중단되던 문제. post-gate 끝에 `chore(ralph): iter-XX housekeeping` 자동 커밋 추가. 추가 안전망으로 pre-gate에도 회수 로직을 넣어 **tests.json/progress.md 단독 dirty**인 경우 자동으로 복구 커밋 후 진행.

## 1.2.0 — 2026-04-06

### Fixed (Ralph v2 P0)
- **pre-gate `.ralph-state/` self-block**: Ralph 런타임 산출물(`checkpoint-*.sha`, `plan-*.json`, `metrics.jsonl`, `quality-pre-*.json`)이 dirty 체크를 막아 iteration 2+가 거부되던 문제. `git status --porcelain`에 `:!:.ralph-state` pathspec 적용 + `install.sh`가 `.gitignore`에 `.ralph-state/` 블록 자동 패치 (`stack.json`만 유지).
- **Quality Gate task scope 미인지**: 단일 task 구현 후 전체 모노레포 테스트를 돌려 타 pending task의 선작성 Red 테스트로 롤백되던 문제. `plan-${iter}.json`의 `affected_packages`를 읽어 `pnpm --filter='*<pkg>*'` 패턴으로 build/test scope 제한 (pnpm monorepo 한정).

### Added
- **감사 5종 스크립트** (`lib/quality-gate.sh` → `audit_diff_files()`): 이번 iteration diff 파일만 대상으로 300줄 초과, `any`, non-null `!.`, silent `catch {}`, `eslint-disable no-explicit-any` 차단.
- **`prompts/worker.md` 필수 문서 Read 강제**: `HIGH_QUALITY_CODE_STANDARDS.md` + 언어별 standards 직접 로드 의무화. "문서 미로드 상태로 구현 시작 금지".
- **`prompts/planner.md` TDD Red 선 작성 격리 정책**: `affected_packages` 엄격 격리로 타 패키지 pending Red가 현재 iteration을 막지 않음.

## 1.1.0 — 2026-04-05

### Added
- **`/wj:standards` 신규 커맨드**: `HIGH_QUALITY_CODE_STANDARDS.md` + 언어별 standards 문서를 세션에 로드하여 이후 모든 코드 작성·수정·리뷰에 표준을 강제 적용. 새 기능 구현·리팩토링·PR 준비 전 호출.
- **Python Standards (`shared-references/standards/python.md`)**: 2026 실리콘밸리 표준 반영.
  - 툴체인: Ruff + Pyright strict + pytest-cov (80%+)
  - 타입 안전성: `Any` 금지, `NewType` (Branded Types 대응), `Protocol` (구조적 서브타이핑), `Literal` + frozen dataclass + `match` (DU 대응)
  - 에러 처리: EAFP + 경계 규율, bare/silent except 금지, `raise ... from e` 필수
  - 복잡도: Cyclomatic Complexity ≤ 10 (Ruff C901), 파일 400줄 / 함수 30줄 soft limit
  - 레이어 분리: `domain ← application ← infrastructure/interface`
- **TypeScript Standards (`shared-references/standards/typescript.md`)**: 기존 TS 전용 규칙 분리 (파일 300줄/함수 20줄 hard limit, Branded Types, Result<T,E>, DU, `any`/`!` 금지).

### Changed
- **`HIGH_QUALITY_CODE_STANDARDS.md` v2 → v3**: 공통 원칙(언어 불문)과 언어별 디스패처 구조로 리라이트. 9개 불변 원칙(SRP, 타입 안전성, 불변성, 레이어 분리, Silent failure 금지, 복잡도 ≤10, DRY, 테스트 우선, 검증 전 완료 주장 금지) + 언어별 문서 링크.
- **`/wj:check` 언어 자동 감지**: TS(`package.json`, `*.ts`) / Python(`pyproject.toml`, `*.py`) 감지 후 해당 규칙 적용. Python 점검 추가: 400줄 초과, `Any`, bare/silent except, mutable default argument, Ruff C901 복잡도.
- **`/wj:help`**: 콤팩트 재구성, `/wj:standards` 반영, shared-references 목록 갱신.

## 1.0.2 — 2026-04-05

### Fixed
- **block-dangerous.sh 오탐 수정**: `> /dev/` 패턴이 `2>/dev/null` 같은 일반적인 stderr 리다이렉트까지 차단하던 버그. `/dev/null`, `/dev/stderr`, `/dev/stdout`, `/dev/tty`, `/dev/fd/*` 화이트리스트 방식으로 전환하여 실제 장치(`/dev/sda` 등) 쓰기만 차단.

## 1.0.0 — 2026-04-05

### 초기 릴리스

crypto-holdem 프로젝트의 Phase 1-7 리팩토링 여정에서 축적된 실전 패턴을 플러그인화.

#### Added
- **Skills (13개)**: devrule, senior-frontend, backend-dev-rules, commit, learn, team, ui-ux-pro-max, cto-review, init-prd, ideation, feedback-to-prd, implement-next, seo-optimizer
- **Agents (5개)**: frontend-dev, backend-dev, engine-dev, qa-reviewer, docs-keeper (Creator-Reviewer 패턴)
- **Shared References (8개)**:
  - HIGH_QUALITY_CODE_STANDARDS.md (파일/함수/Props 한계, 타입 안전, 성능, DRY)
  - BRANDED_TYPES_PATTERN.md
  - RESULT_PATTERN.md
  - DISCRIMINATED_UNION.md (wrapSetWithPhase 무침습 도입)
  - NON_NULL_ELIMINATION.md
  - LIBRARY_TYPE_HARDENING.md (viem 실전 예시)
  - ZUSTAND_SLICE_PATTERN.md
  - REFACTORING_PREVENTION.md
- **Ralph v2**: 5-Stage Pipeline (Pre-Gate → Planner → Workers → Quality-Gate → Reviewer → Post-Gate)
  - 모델 라우팅 (haiku/sonnet/opus)
  - 병렬 워커 (`--parallel N`)
  - 품질 회귀 자동 차단 (`--strict`)
  - 자동 git rollback
  - append-only metrics.jsonl
- **MCP (10개)**: serena, context7, sequential-thinking, playwright, chrome-devtools, shadcn, magic, tavily-remote, memory, smithery-ai-github
- **Hooks (4개)**: install-mcp (dedup 자동 설치), session-summary, block-dangerous, quality-check
- **Commands (6개)**: /woojoo:init-ralph, check-quality, apply-branded, apply-result, refactor-plan, check-harness
- **Rules (4개)**: frontend, server, shared-engine, tests (레이어별 규칙 템플릿)

#### 주요 설계 결정
- **SessionStart 훅으로 MCP 자동 dedup 설치**: 기존 `~/.claude.json`과 비교 후 누락된 것만 프로젝트 `.mcp.json`에 병합. 재실행 방지 마커 사용.
- **모든 스킬이 shared-references 중앙 참조**: 중복 제거 + 단일 진실 공급원.
- **Ralph v2는 Creator-Reviewer 분리**: 같은 인스턴스가 짜고 리뷰하는 bias 제거.
- **품질 델타 추적**: iteration마다 300줄/any/!./tests 메트릭 기록 → 회귀 시 즉시 중단.
