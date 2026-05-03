# woojoo-magic v3 Redesign — 세션 내 Ralph + 클린 스캐폴딩

**작성일**: 2026-04-11
**현재 버전**: v2.3.9
**목표 버전**: v3.0.0 (breaking change)

---

## 1. 배경과 문제

### 1.1 현재 구조 (v2.3.9)

현재 플러그인은 13개 skill + 10개 command + 5개 agent + Ralph v2 외부 6-stage 파이프라인을 포함한다. Ralph v2는 `claude -p` 서브프로세스를 반복 호출하는 외부 bash 루프 시스템(`ralph.sh` 340줄 + `lib/` 6개 스크립트 654줄 + `prompts/` + `schemas/`)이다.

### 1.2 통증점 3가지

**P1. 루트 오염**
- `hooks/bootstrap.sh`가 세션 시작 시마다 유저 프로젝트 루트에 12개 이상 파일/폴더를 복사한다: `ralph.sh`, `lib/`, `prompts/`, `schemas/`, `prd.md`, `tests.json`, `progress.md`, `smoke-test.sh`, `specs/`, `.ralph-state/`, `CLAUDE.md`, `LESSONS.md`
- `.gitignore`와 `.mcp.json`을 무단 패치하고, 버전 업그레이드 시 **자동 git commit**까지 수행한다
- 사용자가 동의한 적 없는 파일들이 루트를 장악한다

**P2. Ralph 품질 게이트가 느리고 시끄럽다**
- 매 iteration마다 `pnpm turbo build` + `pnpm turbo test`를 콜드 스타트 (수십 초)
- 게이트 실패 → auto-rollback → 다음 iteration 재시작 루프가 빈번하게 트리거
- **smoke-test.sh가 주범** — 서버 기동 포함되어 매 iteration마다 수십 초~분 단위 지연
- 5종 감사 + 델타 비교 + tests.json 무결성 + high-risk 감지까지 한꺼번에 → 통과해야 할 관문이 너무 많음

**P3. 파일 레이아웃 혼돈**
- 사람이 편집하는 문서(`prd.md`, `specs/`)와 AI가 생성하는 흔적(`progress.md`, `.ralph-state/`)이 루트에 뒤섞임
- 플러그인 본체도 `skills/`에 13개, `commands/`에 10개가 평면 배치되어 Ralph 종속 vs 독립 스킬의 구분이 없음
- 일부 스킬은 실제로 안 쓰이는 레거시(예: `seo-optimizer`, `ui-ux-pro-max` 일부)

### 1.3 사용자 의도 (참고 이미지)

사용자가 공유한 3장의 참고 이미지 철학:

1. **이미지 1 — 클린 스캐폴딩**: `src/`, `docs/`, `tests/`, `.dev/`, `.claude/`, `out/`, `CLAUDE.md`의 레이어별 명확한 책임
2. **이미지 2 — 사람 문서 vs AI 문서**: `docs/`는 사람이 관리하는 비즈니스 진실(룰, 체크리스트, ADR, API 스펙), `.dev/`는 AI가 남기는 흔적(learnings, troubleshooting, 작업 로그, 실험 결과). `CLAUDE.md`는 ~100줄 지도 역할, 상세는 `.claude/rules/`가 glob 조건부 로드
3. **이미지 3 — AI 도구 배치**: Skills(레시피), Hooks(자동 안전장치: Pre/Post/Stop/Notification), Agents(전문가), MCP(외부 연동), Plugins(패키지)

---

## 2. 목표와 비목표

### 2.1 목표

1. **외부 Ralph 루프 삭제 + 세션 내 Stop hook 기반 자동 iteration 루프로 대체** (A1안)
2. **유저 프로젝트 루트 오염 제거** — `/wj:init`은 3개 엔트리만 생성(`docs/`, `.dev/`, `CLAUDE.md`)
3. **플러그인 본체 구조 재정비** — 이미지 철학에 따라 `docs/`, `src/`, `.dev/` 레이어 분리
4. **품질 게이트 경량화** — L1(grep, <1초) + L2(tsc 증분, 2~10초) + L3(targeted test, 5~30초). Smoke test 게이트에서 완전 제거
5. **스킬 13개 → 핵심만** 로 축소, Ralph 종속 스킬 삭제

### 2.2 비목표

- Ralph v2 기존 설치 프로젝트의 자동 마이그레이션 (사용자가 수동으로 `/wj:init` 재실행)
- 다른 플러그인 생태계(`ralph-loop:ralph-loop`)와의 호환
- 비-TS/JS 스택에 대한 L2/L3 구현 (v3.0은 TS/JS 우선, Python은 v3.1+)
- 과거 `.ralph-state/`, `prev-metrics.json` 포맷 보존

---

## 3. 새 플러그인 레포 구조

### 3.1 최상위 레이아웃

```
woojoo-magic/
├── .claude-plugin/
│   └── marketplace.json          # 마켓 진입점
├── docs/                          # 사람이 관리하는 진실
│   ├── ARCHITECTURE.md            # 플러그인 설계 개요
│   ├── PHILOSOPHY.md              # "사람 문서 vs AI 문서" 등 원칙
│   ├── MIGRATION.md               # v2 → v3 마이그레이션 가이드
│   └── superpowers/specs/         # 설계 문서 (본 문서 포함)
├── src/                           # 플러그인 본체 (기존 plugins/woojoo-magic/)
│   └── woojoo-magic/
│       ├── .claude-plugin/plugin.json
│       ├── settings.json
│       ├── agents/                # 전문가 서브에이전트
│       ├── commands/              # 슬래시 커맨드
│       ├── hooks/                 # 자동 안전장치 (bootstrap, stop, quality-check)
│       ├── skills/                # 반복 작업 레시피
│       ├── rules/                 # glob 조건부 로드 규칙
│       ├── templates/             # /wj:init이 복사할 스켈레톤
│       └── references/            # HIGH_QUALITY_CODE_STANDARDS 등 공유 문서
├── tests/                         # 플러그인 자체 회귀 테스트
│   ├── hooks/stop-loop.bats       # Stop hook 로직 테스트
│   ├── commands/init.bats         # /wj:init 시나리오 테스트
│   └── fixtures/                  # 테스트용 가상 프로젝트
├── .dev/                          # 개발 중 흔적 (이 레포에서도 사용)
│   ├── journal/                   # 작업 일지
│   └── learnings.md
├── .claude/                       # 개발용 Claude 설정 (플러그인 소스 아님)
├── CLAUDE.md                      # ~80줄 프로젝트 지도
├── README.md                      # 유저 대상
└── CHANGELOG.md
```

**핵심 변화**:
- 플러그인 소스가 `plugins/woojoo-magic/` → `src/wj-magic/`로 이동 (marketplace.json의 `source` 경로만 업데이트)
- `docs/`와 `tests/` 신설 — 레포 자체가 이미지 철학을 따름
- `shared-references/`가 `src/wj-magic/references/`로 이동 (플러그인 내부에 편입)
- 레포 루트의 `.ralph-state/` 제거 (플러그인 자기 자신이 Ralph 안 쓰므로)

### 3.2 `src/wj-magic/` 내부 구조

```
src/wj-magic/
├── .claude-plugin/plugin.json      # name: "wj", version: "3.0.0"
├── settings.json                   # permissions
├── agents/                         # 5개 유지
│   ├── backend-dev.md
│   ├── engine-dev.md
│   ├── frontend-dev.md
│   ├── qa-reviewer.md
│   └── docs-keeper.md
├── commands/                       # 5개로 축소
│   ├── init.md                     # 재작성 — 최소 스캐폴딩
│   ├── loop.md                     # 신규 — 세션 내 Ralph 루프 on/off
│   ├── verify.md                   # 신규 — 풀 build+test+smoke 수동 실행
│   ├── check.md                    # 유지 — 전수 품질 점검
│   └── help.md                     # 유지 — 커맨드 목록
├── hooks/                          # Stop hook 신규, bootstrap 경량화
│   ├── hooks.json
│   ├── bootstrap.sh                # 재작성 — 자동 복사/패치 완전 제거
│   ├── stop-loop.sh                # 신규 — 세션 내 Ralph 루프의 심장
│   ├── quality-check.sh            # 유지 — PostToolUse 경고
│   ├── block-dangerous.sh          # 유지
│   └── session-summary.sh          # 유지 — SessionStart 요약
├── skills/                         # 13개 → 7개로 축소
│   ├── commit/                     # 유지
│   ├── devrule/                    # 유지
│   ├── learn/                      # 유지
│   ├── standards/                  # 유지
│   ├── cto-review/                 # 유지 (가치 있음)
│   ├── ideation/                   # 유지
│   └── team/                       # 유지
├── rules/                          # 유지 (glob 조건부 로드)
│   ├── frontend.md
│   ├── server.md
│   ├── shared-engine.md
│   └── tests.md
├── references/                     # shared-references 이동
│   ├── HIGH_QUALITY_CODE_STANDARDS.md
│   ├── BRANDED_TYPES_PATTERN.md
│   ├── DISCRIMINATED_UNION.md
│   ├── RESULT_PATTERN.md
│   ├── NON_NULL_ELIMINATION.md
│   ├── ZUSTAND_SLICE_PATTERN.md
│   ├── LIBRARY_TYPE_HARDENING.md
│   └── REFACTORING_PREVENTION.md
├── templates/                      # /wj:init이 복사할 스켈레톤
│   ├── CLAUDE.template.md          # ~50줄
│   ├── docs/
│   │   └── prd.template.md
│   └── .dev/
│       └── tasks.template.json
└── lib/                            # Stop hook이 호출하는 bash 유틸
    ├── gate-l1.sh                  # 정적 grep 감사
    ├── gate-l2.sh                  # tsc 증분
    ├── gate-l3.sh                  # targeted test
    ├── journal.sh                  # .dev/journal/ append
    ├── loop-state.sh               # .dev/loop.state 관리
    └── tasks-sync.sh               # docs/prd.md → .dev/tasks.json 동기화
```

### 3.3 삭제 대상

| 기존 | 이유 |
|---|---|
| `templates/ralph-starter-kit/ralph.sh` | 외부 루프 폐기 |
| `templates/ralph-starter-kit/lib/*.sh` | quality-gate.sh 제외 전부 삭제 (로직은 새 `lib/gate-l*.sh`로 이식) |
| `templates/ralph-starter-kit/prompts/` | planner/worker/reviewer 외부 프롬프트 → 세션 내 통합 |
| `templates/ralph-starter-kit/schemas/` | plan.schema.json, tests.schema.json → tests.json 스키마만 `.dev/` 기본값으로 이동 |
| `commands/plan.md` | Ralph planner 단일 실행 커맨드 — 불필요 |
| `commands/result.md` | Ralph 결과 요약 커맨드 — 불필요 |
| `commands/harness.md` | Ralph 하네스 진단 — 루프 자체가 없으니 불필요 |
| `commands/spec-init.md` | `/wj:init`에 통합 |
| `commands/smoke-init.md` | smoke test 자체 폐기 |
| `commands/standards.md` | `skills/standards/` 스킬로 통합 |
| `commands/brand.md` | 거의 안 쓰임 — 스킬 `standards`에 통합 가능 |
| `skills/init-prd/` | `/wj:init`에 통합 |
| `skills/implement-next/` | Stop hook의 태스크 전진 로직으로 대체 |
| `skills/feedback-to-prd/` | 거의 안 쓰임, 필요시 `skills/learn/`에 흡수 |
| `skills/seo-optimizer/` | 레거시 |
| `skills/ui-ux-pro-max/` | `impeccable:*` 스킬 생태계가 대체함 |
| `skills/senior-frontend/` | `impeccable:frontend-design`가 대체 |
| `skills/backend-dev-rules/` | `rules/server.md`에 핵심만 병합 |
| `hooks/install-mcp.sh` | bootstrap과 중복 기능 |
| `.ralph-state/` (레포 루트) | 플러그인 자신이 Ralph 안 쓰므로 삭제 |

---

## 4. `/wj:init` 재설계

### 4.1 새 동작

```bash
/wj:init                # 기본: 없는 것만 생성, 아무것도 덮어쓰지 않음
/wj:init --with-prd     # 추가로 docs/prd.md 템플릿 생성
```

### 4.2 생성/수정 대상

| 경로 | 동작 | 출처 |
|---|---|---|
| `docs/` | 없으면 빈 디렉토리 생성 | — |
| `docs/prd.md` | `--with-prd` 플래그가 있고 파일 없을 때만 | `templates/docs/prd.template.md` |
| `docs/specs/` | 없으면 빈 디렉토리 생성 | — |
| `.dev/` | 없으면 빈 디렉토리 생성 | — |
| `.dev/tasks.json` | 없으면 빈 레지스트리 생성 (`{"features": [], "summary": {...}}`) | `templates/.dev/tasks.template.json` |
| `.dev/journal/` | 없으면 빈 디렉토리 생성 | — |
| `.dev/state/` | 없으면 빈 디렉토리 생성 | — |
| `CLAUDE.md` | 없을 때만 ~50줄 스켈레톤 생성 | `templates/CLAUDE.template.md` |

### 4.3 하지 않을 일 (명시)

- ❌ `.gitignore` 수정 (대신 출력 로그로 "`.dev/`를 .gitignore에 추가하세요" 권장 메시지)
- ❌ `.mcp.json` 자동 병합 (대신 `/wj:mcp-suggest` 별도 커맨드로 분리 — v3.1에)
- ❌ `ralph.sh`, `lib/`, `prompts/`, `schemas/` 복사 (전부 삭제됨)
- ❌ `LESSONS.md` 빈 파일 생성 (필요시 사용자가 만듦, 또는 `.dev/learnings.md` 사용)
- ❌ 기존 파일 덮어쓰기 (`--force` 플래그 완전 제거)
- ❌ 자동 git commit
- ❌ 버전 마커 파일 생성 (`.ralph-state/.plugin-version` 불필요)

### 4.4 기존 v2 프로젝트 마이그레이션

`/wj:init`이 기존 v2 설치를 감지하면(`ralph.sh` 또는 `.ralph-state/` 존재) 안내 메시지 출력:

```
⚠️ v2.x Ralph 설치 감지됨. 마이그레이션 필요:
  1. ralph.sh, lib/, prompts/, schemas/ 삭제 (루프 외부화 폐기)
  2. prd.md → docs/prd.md 이동
  3. tests.json → .dev/tasks.json 이동
  4. specs/ → docs/specs/ 이동
  5. progress.md → .dev/journal/legacy-progress.md 이동
  6. .ralph-state/ → .dev/state/ 이동 (또는 삭제)
  7. smoke-test.sh → scripts/smoke.sh 이동 (또는 삭제)
  8. LESSONS.md → .dev/learnings.md 이동

/wj:migrate-v2 커맨드로 자동화 가능 (v3.0.1+).
```

v3.0.0에서는 자동 마이그레이션 없이 **안내만**. v3.0.1에서 `/wj:migrate-v2` 추가.

---

## 5. 세션 내 Ralph 루프 — Stop Hook 설계

### 5.1 루프 상태 머신

상태 파일: `.dev/state/loop.state` (JSON)

```json
{
  "active": true,
  "started_at": "2026-04-11T14:32:00Z",
  "current_task": "engine-auth-005",
  "iteration": 3,
  "consecutive_failures": 0,
  "last_gate_result": "pass",
  "stop_reason": null
}
```

### 5.2 루프 수명 주기

```
사용자: /wj:loop start [task-id]
  ↓
loop-state.sh가 .dev/state/loop.state를 active=true로 기록
  ↓
사용자 또는 Claude가 task 작업 진행 (코드 편집)
  ↓
Claude 응답 종료 → Stop hook 발동
  ↓
stop-loop.sh 실행:
  1. loop.state 읽기 → active=false면 exit 0 (일반 세션)
  2. gate-l1.sh (L1 정적 감사)
  3. gate-l2.sh (L2 tsc 증분)
  4. gate-l3.sh (L3 targeted test)
  5. journal.sh로 .dev/journal/YYYY-MM-DD.md에 append
  6. 게이트 결과 분기:
     - 통과: tasks-sync.sh로 current_task 완료 체크 (완료 기준: `.dev/tasks.json`의 해당 task `status` 필드가 `"done"`)
         - 완료: 다음 eligible task 선택 → "다음: {task-id} 구현해" 주입 + stop 차단
         - 미완료 (status가 `"in_progress"` 또는 `"pending"`): "이어서 구현 계속해. 완료되면 `.dev/tasks.json`에서 이 task의 status를 `done`으로 업데이트하라" 주입 + stop 차단
         - 모든 task 완료: active=false + stop 허용
     - 실패: consecutive_failures++ → 실패 내역을 "이것부터 고쳐" 프롬프트로 주입 + stop 차단
     - 연속 3회 실패: active=false + "loop 자동 중단" 메시지 + stop 허용
  ↓
사용자 또는 Claude가 다음 턴 진행 (Stop hook의 주입 프롬프트를 Claude가 받음)
  ↓
(반복)
  ↓
사용자: /wj:loop stop 또는 모든 task 완료 또는 연속 실패 → loop 종료
```

### 5.3 Stop hook 차단 메커니즘

Claude Code의 Stop hook은 JSON 응답으로 `{"decision": "block", "reason": "..."}`을 반환하면 Claude가 stop하지 않고 reason을 컨텍스트에 추가해 자동 재개된다.

`stop-loop.sh`의 출력 예시:

```json
{
  "decision": "block",
  "reason": "[wj:loop] task=engine-auth-005 iter=3 — L2 게이트 실패:\n\nsrc/auth/guard.ts:42 - Type 'string | undefined' is not assignable to type 'string'.\n\n이 타입 에러부터 수정하세요. 다른 작업은 건너뛰고 이것만 고치세요."
}
```

게이트 통과 + 다음 task 전진 예시:

```json
{
  "decision": "block",
  "reason": "[wj:loop] task=engine-auth-005 완료 ✅ (L1/L2/L3 통과)\n\n다음 eligible task: engine-auth-006 (OAuth 콜백 핸들러)\n\n다음 task를 구현하세요. docs/specs/engine-auth-006.md를 먼저 읽고 TDD로 진행."
}
```

루프 종료 예시:

```json
{
  "continue": true
}
```
(block 없이 일반 종료 — 일반 대화 모드)

### 5.4 안전장치

1. **loop.state 없음/active=false** → stop-loop.sh는 즉시 exit 0 (일반 세션 오염 없음)
2. **연속 3회 실패** → 자동 중단, 사용자 개입 요청
3. **30분 타임아웃** — loop.state의 `started_at`을 체크해 30분 초과 시 자동 중단
4. **`/wj:loop stop`** — 즉시 active=false, 어느 상태에서든 강제 중단
5. **PreToolUse Bash 차단** — 기존 `block-dangerous.sh` 유지로 `rm -rf` 등 방어
6. **tasks.json 무결성 — Claude가 실수로 덮어쓰면** tasks-sync.sh가 감지 → 롤백 대신 **에러 주입** ("tasks.json이 훼손됐다. git diff로 확인하고 복구하라")

### 5.5 새 커맨드 `/wj:loop`

```bash
/wj:loop start              # 다음 eligible task로 시작
/wj:loop start <task-id>    # 특정 task로 시작
/wj:loop stop               # 즉시 중단
/wj:loop status             # 현재 상태
```

`commands/loop.md`에 정의. 커맨드 본문에서 `lib/loop-state.sh`를 호출해 state 파일을 조작하고, Claude 본인이 첫 번째 태스크 구현을 시작한다. 이후부터는 Stop hook이 이어받음.

### 5.6 새 커맨드 `/wj:verify`

풀 `build + test + smoke`를 수동 실행. 세션 내 루프는 L1/L2/L3만 돌리므로, 커밋 전 최종 검증용:

```bash
/wj:verify           # package.json의 build + test 풀 실행
/wj:verify --smoke   # scripts/smoke.sh도 실행 (존재 시)
```

---

## 6. 품질 게이트 — L1/L2/L3

### 6.1 L1 — 정적 grep 감사 (항상 실행, <1초)

`lib/gate-l1.sh`:

1. Stop hook의 stdin JSON에서 `transcript_path`를 읽거나, 또는 `git diff --name-only HEAD`로 이번 턴에서 편집된 파일 목록 추출
2. `.ts`, `.tsx`, `.mts`, `.cts`만 대상 (`.d.ts`, `__tests__`, `*.test.*`, `*.spec.*` 제외)
3. 5종 감사:
   - **300줄 초과**: `wc -l`
   - **any 금지**: `grep -E ':\s*any\b|<any>|\bas\s+any\b'`
   - **non-null assertion**: `grep -E '[A-Za-z0-9_\)\]]!\.'`
   - **silent catch**: `grep -E 'catch\s*\(\s*\w*\s*\)\s*\{\s*\}'`
   - **eslint-disable no-explicit-any**: `grep 'eslint-disable.*no-explicit-any'`
4. 하나라도 걸리면 실패 목록 반환

기존 `quality-gate.sh`의 `audit_diff_files()`를 그대로 이식 (이미 검증된 로직).

### 6.2 L2 — tsc 증분 (조건부, 2~10초)

`lib/gate-l2.sh`:

1. L1 통과 후 실행
2. 편집 파일 중 `.ts` 존재 시만
3. 프로젝트 루트 또는 가장 가까운 `tsconfig.json`을 찾아 `tsc --noEmit --incremental` 실행
4. **증분 빌드 정보(`*.tsbuildinfo`)를 `.dev/state/`에 보관** → 콜드 스타트 제거
5. 실패 시 에러 메시지(마지막 20줄)를 반환

Turbo/모노레포 감지:
- `turbo.json` 존재 시 `pnpm turbo typecheck --filter=...[HEAD^]` 형태로 scope 제한
- 일반 프로젝트는 `npx tsc --noEmit -p tsconfig.json`

### 6.3 L3 — targeted test (조건부, 5~30초)

`lib/gate-l3.sh`:

1. L1/L2 통과 후 실행
2. 현재 task가 있는 경우만 (loop 모드 전용)
3. **편집 파일 → 관련 테스트 매핑**:
   - `src/foo/bar.ts` → `src/foo/bar.test.ts` (같은 디렉토리)
   - `src/foo/bar.ts` → `src/foo/__tests__/bar.test.ts`
   - `src/foo/bar.ts` → `tests/foo/bar.test.ts`
   - `.dev/tasks.json`의 current_task에 `test_files` 필드가 있으면 그걸 우선 사용
4. 매칭된 테스트만 `vitest run <files>` 또는 `jest <files>` 실행
5. 매칭 0건이면 skip (L3 통과 처리, 경고 출력)

**NOT RUN 명시**:
- 전체 테스트 스위트
- smoke test (서버 기동 포함)
- e2e test
- `pnpm turbo build` 풀 빌드

### 6.4 Task 완료 판정의 책임 분리

Stop hook은 **Claude의 판단을 신뢰**한다. 게이트 통과 여부는 기계적으로 판정(L1/L2/L3 통과)하지만, "이 task가 acceptance criteria를 전부 만족했는가"는 Claude가 `.dev/tasks.json`의 `status` 필드를 직접 `"done"`으로 업데이트함으로써 선언한다. Stop hook은 이 필드만 확인한다.

이유: acceptance criteria는 자연어이므로 기계적 판정 불가. Claude가 본인 작업의 완료를 선언하고, 게이트가 기계적 품질(빌드/타입/테스트)만 검증하는 이원화가 실용적이다.

안전장치: Claude가 완료 선언을 안 하고 무한히 "이어서 구현"만 반복하는 경우 → 동일 task로 8회 iteration 돌면 "너무 오래 걸린다. task를 더 작게 쪼개거나 blocker를 보고하라" 자동 주입.

### 6.5 게이트 실패 후 재시도 방지

동일한 에러 메시지가 3회 연속 발생하면 → "같은 에러가 3회 반복됩니다. 수동 개입이 필요합니다" 로 자동 중단. `.dev/state/loop.state`의 `consecutive_failures`로 추적하되, 에러 지문(hash)도 함께 저장해 "다른 에러로 진전이 있는 경우"와 구별.

---

## 7. 문서 위치 매핑 요약

기존 Ralph 문서 → 새 위치:

| 기존 | 새 위치 | 관리 주체 |
|---|---|---|
| `prd.md` (루트) | `docs/prd.md` | 사람 |
| `specs/` (루트) | `docs/specs/` | 사람+AI |
| `tests.json` (루트) | `.dev/tasks.json` | AI |
| `progress.md` (루트) | `.dev/journal/YYYY-MM-DD.md` | AI |
| `smoke-test.sh` (루트) | ❌ **삭제** (옵션: `scripts/smoke.sh`) | 사람 |
| `CLAUDE.md` (루트) | `CLAUDE.md` (루트, ~50줄) | 사람 |
| `LESSONS.md` (루트) | `.dev/learnings.md` | AI |
| `.ralph-state/` (루트) | `.dev/state/` | AI |

---

## 8. 에러 처리와 엣지케이스

### 8.1 Stop hook 실패 모드

| 시나리오 | 동작 |
|---|---|
| `lib/gate-l1.sh` 자체가 크래시 | stderr에 에러 기록, exit 0 (루프 진행 방해 금지) |
| `.dev/state/` 디렉토리 없음 | stop-loop.sh 시작 시 자동 생성 |
| `loop.state` JSON 파싱 실패 | 경고 후 loop 비활성 처리 |
| `tsc` 바이너리 없음 | L2 skip, 경고 |
| 편집 파일 목록 빈값 | L1/L2/L3 전부 skip, journal만 append |
| git 없음/커밋 없음 | 이번 세션 전체를 diff 범위로 처리 |

### 8.2 유저 의도 충돌

| 시나리오 | 동작 |
|---|---|
| 루프 중 사용자가 "잠깐, 이거 먼저 봐줘" 식 개입 | Claude의 응답 중 `/wj:loop stop`을 사용자가 명시 호출해야 함 (Stop hook은 텍스트 내용 파싱 안 함) |
| 사용자가 수동으로 `.dev/loop.state` 편집 | stop-loop.sh는 파일 상태를 신뢰 |
| 여러 세션에서 동시에 루프 실행 | `loop.state`에 `pid` 기록, 다른 pid면 "이미 다른 세션에서 루프 중" 경고 |

### 8.3 `tasks.json` 오염

Claude가 실수로 `.dev/tasks.json`을 빈 객체 또는 잘못된 구조로 덮어쓰는 경우:
- `tasks-sync.sh`가 매 Stop hook마다 구조 검증 (`features` 배열 존재, `summary` 일관성)
- 실패 시 → Stop hook 블록 + "tasks.json이 손상됐다. `git checkout .dev/tasks.json`으로 복구하라" 주입
- 자동 수정/롤백 **안 함** (v2의 auto-commit 문제 재발 방지)

---

## 9. 테스트 전략

### 9.1 플러그인 자체 회귀 테스트 (`tests/`)

**bats** 기반 bash 테스트 스위트:

1. `tests/hooks/stop-loop.bats`:
   - loop.state inactive → exit 0
   - loop.state active + L1 실패 → decision=block 반환
   - loop.state active + L1/L2/L3 통과 + task 미완료 → "이어서 구현" 주입
   - loop.state active + task 완료 → 다음 task 주입
   - loop.state active + 모든 task 완료 → active=false + decision=continue
   - 연속 3회 실패 → 자동 중단

2. `tests/commands/init.bats`:
   - 빈 디렉토리 → docs/, .dev/, CLAUDE.md 생성
   - 기존 CLAUDE.md 존재 → 덮어쓰지 않음
   - v2 설치 감지 → 마이그레이션 메시지 출력 + 파일 생성 안 함

3. `tests/lib/gate-l1.bats`:
   - 300줄 미만 → 통과
   - any 사용 → 실패 + 메시지
   - non-null assertion → 실패 + 메시지
   - silent catch → 실패 + 메시지

4. `tests/fixtures/`:
   - `minimal-ts-project/` — 단일 TS 파일
   - `turbo-monorepo/` — pnpm workspace + turbo
   - `v2-legacy/` — ralph.sh + tests.json이 이미 있는 프로젝트

### 9.2 수동 통합 테스트 시나리오

새 프로젝트 시나리오:
1. 빈 디렉토리에서 `/wj:init` → 3개 엔트리 생성 확인
2. `docs/prd.md` 수기 작성 → `/wj:loop start` → 자동 태스크 전진 확인
3. 의도적으로 L1 에러 코드 작성 → Stop hook 차단 및 재시도 주입 확인

v2 마이그레이션 시나리오:
1. 기존 Ralph v2 프로젝트에서 플러그인 v3 업데이트 → `/wj:init` 실행 → 마이그레이션 안내 출력 확인
2. 수동으로 파일 이동 → `/wj:loop start` 동작 확인

---

## 10. 마이그레이션과 출시 계획

### 10.1 v3.0.0 breaking changes 목록

1. `ralph.sh`, `lib/`, `prompts/`, `schemas/` 루트 파일 전부 삭제
2. `prd.md`/`tests.json`/`progress.md`/`specs/` 위치 이동 (수동 마이그레이션 필요)
3. `smoke-test.sh` 자동 실행 제거
4. `/wj:init --force` 옵션 제거
5. `/wj:plan`, `/wj:result`, `/wj:harness`, `/wj:spec-init`, `/wj:smoke-init`, `/wj:standards`, `/wj:brand` 커맨드 삭제
6. 13개 스킬 → 7개로 축소 (`init-prd`, `implement-next`, `feedback-to-prd`, `seo-optimizer`, `ui-ux-pro-max`, `senior-frontend`, `backend-dev-rules` 삭제)
7. bootstrap.sh의 자동 복사/`.gitignore` 패치/auto-commit 전부 제거
8. plugins/ 디렉토리 → src/로 이동 (marketplace.json 경로 변경)

### 10.2 단계적 구현 순서 (plan 작성 시 참고)

1. **Phase 1 — 레포 구조 재배치**: plugins/ → src/ 이동, docs/·tests/ 신설, `.ralph-state/` 삭제
2. **Phase 2 — bootstrap 경량화**: hooks/bootstrap.sh 재작성 (복사/패치/commit 전부 제거)
3. **Phase 3 — /wj:init 재작성**: templates/CLAUDE.template.md, docs/prd.template.md, .dev/tasks.template.json 작성 + 새 commands/init.md
4. **Phase 4 — Ralph 삭제**: templates/ralph-starter-kit/, commands/{plan,result,harness,spec-init,smoke-init,standards,brand}.md, skills/{init-prd,implement-next,feedback-to-prd}/ 등 삭제
5. **Phase 5 — Stop hook 루프 구현**: lib/{gate-l1,gate-l2,gate-l3,journal,loop-state,tasks-sync}.sh + hooks/stop-loop.sh + hooks/hooks.json 업데이트
6. **Phase 6 — /wj:loop, /wj:verify 커맨드**: commands/loop.md, commands/verify.md
7. **Phase 7 — 스킬 프루닝**: seo-optimizer, ui-ux-pro-max, senior-frontend, backend-dev-rules, init-prd, implement-next, feedback-to-prd 디렉토리 삭제
8. **Phase 8 — 테스트 작성**: tests/fixtures/, bats 테스트
9. **Phase 9 — 문서**: docs/ARCHITECTURE.md, docs/PHILOSOPHY.md, docs/MIGRATION.md, 새 README.md, 새 CLAUDE.md
10. **Phase 10 — 릴리스**: CHANGELOG v3.0.0, marketplace.json 버전 업, 커밋/푸시

---

## 11. 열린 질문 (v3.0 이후)

이 스펙의 범위 밖, 향후 결정:

1. Python 스택 지원 — L1(grep) 재사용 가능, L2(mypy)/L3(pytest) 구현은 v3.1
2. `/wj:migrate-v2` 자동 마이그레이션 커맨드 — v3.0.1
3. `.dev/journal/` 주간 롤업 — v3.2
4. 멀티 세션 동시 루프 충돌 처리 심화 — v3.2

---

## 12. 성공 기준

v3.0.0 릴리스가 다음을 만족하면 성공:

1. 빈 디렉토리에서 `/wj:init` 실행 → **루트에 3개 엔트리만 생성** (`docs/`, `.dev/`, `CLAUDE.md`)
2. `.gitignore`, `.mcp.json`, 기존 파일 어떤 것도 자동 수정되지 않음
3. `/wj:loop start` → 사용자 개입 없이 L1/L2/L3 게이트를 거치며 task 자동 진행
4. 한 iteration의 게이트 실행 시간 **중간값 10초 미만** (L1 <1초 + L2 2~10초 + L3 5~30초 중 L3 skip 비율 높음)
5. smoke test가 게이트에서 실행되지 않음 (`/wj:verify --smoke` 수동 실행만)
6. 플러그인 소스 파일 수 **113 → 70개 이하**
7. `tests/`의 bats 테스트 **전체 통과**
