# Changelog

## 2.3.1 — 2026-04-07

### Fixed
- **ralph.sh 연속 실패 카운터 크래시**: `$MAX_CONSECUTIVE_FAILS회`에서 한글 `회`가 bash 변수명 일부로 해석되어 `unbound variable` 에러 발생. `${MAX_CONSECUTIVE_FAILS}회`로 중괄호 감싸기 (3곳)

## 2.3.0 — 2026-04-07

### Changed
- **범용 하네스 전환**: 플러그인 전체 문서에서 프로젝트 귀속 예시(crypto-holdem/포커 도메인) 제거. 모든 shared-references, skills, commands, agents, templates를 도메인 무관한 패턴 설명 문서로 리라이트
- **shared-references 7개 리라이트**: BRANDED_TYPES, RESULT, DU, NON_NULL, REFACTORING_PREVENTION, ZUSTAND_SLICE, LIBRARY_TYPE_HARDENING — 이커머스/SaaS 범용 예시로 교체
- **standards 2개 리라이트**: typescript.md, python.md — 포커 타입/페이즈를 범용 도메인(Order, User, Money)으로 교체
- **skills 13개 일괄 수정**: 핵심 규칙 섹션의 도메인 귀속 예시 제거. init-prd, feedback-to-prd 대폭 리라이트
- **agents 5개 수정**: 하드코딩된 플러그인명 → 상대경로 참조로 전환
- **commands 3개 수정**: brand, help, standards의 포커 예시 → 범용 예시
- **참조 경로 정합성 수정**: 3개 스킬의 dead link(`references/HIGH_QUALITY_CODE_STANDARDS.md`) → 올바른 shared-references 경로로 수정
- **Ralph reviewer 프롬프트**: "게임" → "주요 기능"으로 범용화

## 2.2.2 — 2026-04-07

### Fixed
- **Ralph Quality Gate 실시간 로그**: Stage 0/3/5 출력이 로그 파일로만 리다이렉트되어 터미널에 안 보이던 문제 수정 (`> file` → `| tee file`)
- **smoke-test timeout 추가**: smoke-test.sh hang 시 Ralph 전체가 무한 대기하던 문제. 기본 5분(300s) timeout + 포트 프로세스 자동 정리 (`SMOKE_TIMEOUT` 환경변수로 조정 가능)
- **smoke-test 템플릿 trap cleanup 기본 활성화**: 서버 프로세스가 정리 안 되는 근본 원인 해소

## 2.2.1 — 2026-04-07

### Fixed
- **spec-init 품질 강화**: tests.json 복붙 금지를 명시. Serena 코드 분석 → 현재 코드 분석/구현 방향/Before-After/테스트 케이스를 구체적으로 작성하도록 절차 전면 개정. 템플릿에 "현재 코드 분석", "테스트 계획" 섹션 추가.

## 2.2.0 — 2026-04-07

### Added
- **`/wj:spec-init` 커맨드**: 기존 tests.json 기반으로 누락 spec 일괄 생성 + 기존 spec 정합성 검증. 템플릿(배경, AC, 설계, 구현 가이드, Edge Cases, 회귀 체크, 의존성) 포함.
- **`⚡ 즉시 실행` 블록 일괄 추가**: standards, check, harness, brand, result, plan 커맨드 6개에 즉시 실행 지시 추가. Claude가 지시를 수행하지 않는 문제 방지.
- **install.sh CLAUDE.md/LESSONS.md 자동 생성**: 없으면 빈 파일로 touch. Ralph 프롬프트가 필수로 참조하는 파일 누락 방지.

### Fixed
- **reviewer.md 번호 오류**: 4번이 중복이던 것 → 4, 5로 수정.
- **release 스킬 플러그인 외부로 이동**: 개발용 릴리스 스킬이 배포되는 플러그인에 포함되지 않도록 `.claude/commands/`로 분리.

### Changed
- **릴리스 스킬 전면 개정**: description/숫자 동기화 검증을 필수 단계로 추가.
- **커맨드 9→10개**: `/wj:spec-init` 추가.

## 2.1.1 — 2026-04-07

### Changed
- **release 스킬을 플러그인 밖으로 이동**: `plugins/woojoo-magic/skills/release/` → `.claude/commands/release.md` (프로젝트 로컬 커맨드). 배포되는 플러그인에 개발용 릴리스 스킬이 포함되지 않도록 분리.
- **Skills 14개 → 13개**: release 제거에 따른 description/help.md 숫자 동기화.

## 2.1.0 — 2026-04-07

### Fixed
- **`/wj:init` Step 2 미실행 수정**: `⚡ 즉시 실행` 블록 추가 — Claude가 install.sh(Step 1)만 실행하고 멈추던 문제 해결. Step 1~3 전부 수행을 명시적으로 강제.

### Changed
- **릴리스 스킬 전면 개정**: description/숫자 동기화 검증을 필수 단계로 추가. 커맨드 수, 스킬 수, 에이전트 수를 실제 파일과 대조하고 help.md/marketplace.json/plugin.json 전부 일치시킨 후에만 커밋 허용.

## 2.0.1 — 2026-04-07

### Fixed
- **`/wj:init` Step 2 미실행 수정**: `⚡ 즉시 실행` 블록 추가 — Claude가 install.sh(Step 1)만 실행하고 멈추던 문제 해결. Step 1~3 전부 수행을 명시적으로 강제.

## 2.0.0 — 2026-04-07

### Changed
- **Worker 모델 opus 승격**: Worker sonnet→opus, Planner haiku→sonnet으로 모델 업그레이드.
- **`/wj:init` 완전 재설계**: 한 번 실행으로 Ralph 전체 준비 완료.
  - CODE(ralph.sh, lib/, prompts/, schemas/) 항상 최신 덮어쓰기가 기본. `--force-code` 폐기.
  - prd.md ↔ tests.json ↔ specs/ 정합성 검증 + 누락 필드/내용 자동 보충.
  - smoke-test.sh 없으면 스택 감지 후 자동 생성.
- **Planner에 failure/feedback 참조 추가**: `last-failure.log`, `review-feedback.log`를 읽고 실패 task 재선별/피드백 task 우선 배치.
- **Reviewer에 HIGH_QUALITY_CODE_STANDARDS.md 명시적 로드 지시 추가**.
- **6-stage pipeline 명칭 정정**: "5-stage" → "6-stage" (Stage 0~5).
- **`--force-code` 참조 전체 제거**: help.md, standards.md, README.md에서 폐기된 플래그 참조 정리.

## 1.8.2 — 2026-04-07

### Changed
- **Ralph README.md 전면 업데이트**: v1.7.3~1.8.1 신규 기능(smoke test, review-feedback, last-failure, high-risk 감지) 전부 반영. 상태 파일 목록, 필수 파일 목록, pipeline 표 갱신.
- **plugin.json/marketplace.json description 동기화**: 9 commands + 14 skills + Ralph v2 신규 기능 반영.
- **help.md 스킬 수 보정**: 13개 → 14개 (`/release` 누락 수정).

## 1.8.1 — 2026-04-07

### Added
- **`/wj:smoke-init` 커맨드**: 프로젝트 스택(프레임워크, DB, 인증)을 감지하고 핵심 플로우를 검증하는 `smoke-test.sh`를 자동 생성.
- **`wj:init`에 smoke-test.sh 템플릿 포함**: Ralph 설치 시 smoke-test.sh 골격이 함께 생성됨. 주석 해제 후 프로젝트에 맞게 수정하여 사용.

## 1.8.0 — 2026-04-07

### Added
- **Smoke Test 지원**: 프로젝트 루트에 `smoke-test.sh`가 있으면 Quality Gate에서 빌드/테스트 후 자동 실행. E2E 핵심 플로우 검증 가능.
- **High-Risk 변경 감지**: auth/middleware/guard/route/session 파일 변경 시 scope 제한 무시하고 전체 빌드+테스트 강제 실행.
- **Reviewer 회귀 위험 평가**: 체크리스트 섹션 G 추가 — 인증/라우트/환경변수/shared 타입 변경의 회귀 영향 필수 평가.
- **Worker 크로스 패키지 검증 강화**: 인증/미들웨어 변경 시 전체 엔드포인트 접근성, 환경변수 분기 양쪽 테스트 필수화.

## 1.7.5 — 2026-04-06

### Added
- **Reviewer 피드백 자동 전달**: `CHANGES_REQUESTED` 감지 시 `review-feedback.log`에 저장하고, 다음 iteration Worker가 피드백을 우선 수정하도록 자동화. Worker 성공 시 피드백 파일 자동 삭제.

## 1.7.4 — 2026-04-06

### Added
- **시작 배너에 플러그인 버전 표시**: Ralph 실행 시 `Ralph v2 Autonomous Loop (woojoo-magic vX.Y.Z)` 형태로 현재 플러그인 버전 출력.

## 1.7.3 — 2026-04-06

### Fixed
- **Pre-Gate 임시 파일 오탐 수정**: `.bak/.tmp/.orig` 파일이 dirty tree로 감지되어 루프가 중단되던 문제 해결. pathspec 제외 + 자동 삭제 정리 추가.
- **Rollback 후 동일 실패 반복 방지**: 롤백 시 실패 원인을 `last-failure.log`에 기록하고, Worker가 다음 iteration에서 참조하여 같은 실수를 반복하지 않도록 개선.
- **Housekeeping 커밋 실패 연쇄 차단 수정**: post-gate 하우스키핑 커밋 실패 시 `git checkout`으로 복원하여 다음 pre-gate 차단 방지.

## 1.7.2 — 2026-04-06

### Added
- **Stage별 소요 시간 로그**: 각 Stage 완료 시 `Stage N 완료 Xs` 출력으로 병목 즉시 파악 가능.
- **spec 로드 확인 로그**: Worker/Reviewer가 spec 읽었는지 `✅ spec 로드` / `⚠️ spec 없음` 명시 출력. Planner도 eligible task의 spec 유무 표시.

## 1.7.1 — 2026-04-06

### Fixed
- **Planner 16분 지연 수정**: 전 Stage 공통 `--max-turns 200`을 역할별로 분리 (Planner 30, Worker 200, Reviewer 50). Haiku가 MCP 도구를 과도 호출하며 빙빙 돌던 문제 해결.

## 1.7.0 — 2026-04-06

### Added
- **init-prd 추가 모드**: 기존 prd.md/tests.json이 있으면 자동으로 추가 모드 전환. 새 task만 append, 기존 항목 수정 금지. "태스크 추가", "기능 추가", "task 추가해줘" 등 트리거 키워드 추가.

## 1.6.0 — 2026-04-06

### Added
- **specs/ 상세 기획 시스템**: 각 task에 `specs/{task-id}.md` 상세 설계 문서를 연결. tests.json에 `spec` 필드 추가. Worker가 구현 전 반드시 spec을 읽고, Reviewer가 spec 대비 구현 일치를 검증. init-prd/feedback-to-prd 스킬에서 spec 파일 동시 생성. 5개 에이전트 모두 spec 참조 가이드 추가.

## 1.5.2 — 2026-04-06

### Fixed
- **Quality Gate tests.json summary 자동 보정**: Worker가 summary 카운트를 잘못 계산해도 rollback하지 않고 features 배열 기준으로 자동 보정 후 진행. 배열 파괴(features < 2)는 여전히 FAIL.

## 1.5.1 — 2026-04-06

### Fixed
- **인프라 자동 업그레이드 후 커밋 누락**: bootstrap.sh가 ralph.sh/lib/prompts/schemas를 덮어쓴 뒤 커밋하지 않아 다음 pre-gate에서 dirty tree로 루프가 중단되던 문제. 업그레이드 직후 `--no-verify` 자동 커밋 추가.

## 1.5.0 — 2026-04-06

### Fixed
- **Worker 대기 모드 진입 버그**: 프롬프트 내 `$PLAN_FILE`, `$RALPH_ITER` 등 환경변수가 리터럴 텍스트로 전달되어 Worker가 plan 파일을 찾지 못하고 "작업 지시를 기다리고 있습니다" 상태에 빠지던 문제. `envsubst`로 실제 값 치환 추가.
- **전 Stage 즉시 실행 지시 추가**: Planner/Worker/Reviewer 프롬프트 끝에 명시적 실행 명령 섹션 추가. Claude가 대기 모드 없이 바로 작업 시작.

## 1.4.0 — 2026-04-06

### Added
- **iteration 배너에 남은 task 카운트 표시**: Ralph 루프 iteration 시작 시 tests.json에서 passing/total을 읽어 `남은 task: N/M` 출력. 진행 상황을 한눈에 파악 가능.

## 1.3.0 — 2026-04-06

### Added
- **플러그인 업데이트 시 프로젝트 인프라 자동 업그레이드**: 매 세션마다 plugin.json 버전과 `.ralph-state/.plugin-version`을 비교하여 `ralph.sh`, `lib/`, `prompts/`, `schemas/`를 자동 덮어씀. 사용자 데이터(prd.md, tests.json, progress.md)는 건드리지 않음. 이전에는 플러그인을 업데이트해도 이미 설치된 프로젝트의 Ralph 인프라가 구버전으로 남아 버그 수정이 전파되지 않았음.

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
