# woojoo-magic (wj) v4.5

> Claude Code 플러그인 — 처음부터 고품질 코드를 강제하는 자율 개발 환경

13명의 전문가 에이전트가 디자인, 보안, 테스트, 코드 품질을 처음부터 강제합니다.
국정조사급 버그 조사(5 에이전트 팀) + 6개 언어 품질 게이트 + 디자인 레퍼런스 7개 + Anti-Slop 패턴 탐지 + 포인터 아키텍처(단일 진실 공급원)로,
리팩토링이 필요 없는 코드와 AI스럽지 않은 UI를 만듭니다.

## 한눈에 보기

```
┌─────────────────────────────────────────────────────────────┐
│                     woojoo-magic v4.5                        │
│                                                             │
│  5 커맨드 · 13 스킬 · 13 에이전트 · 7 훅 · 7 규칙 · 8 MCP   │
│                                                             │
│  ┌───────────┐ ┌─────────────────┐ ┌────────────────────┐  │
│  │  커맨드    │ │  스킬            │ │  자동 훅            │  │
│  │           │ │                 │ │                    │  │
│  │  init     │ │  investigate    │ │  L1 정적 감사       │  │
│  │  loop     │ │  devrule        │ │  L2 타입 체크       │  │
│  │  verify   │ │  tdd            │ │  L3 테스트          │  │
│  │  check    │ │  design/polish  │ │  위험 명령 차단      │  │
│  │  help     │ │  brainstorm     │ │  민감 파일 보호      │  │
│  │           │ │  plan           │ │  서브에이전트 게이트  │  │
│  │           │ │  team/ideation  │ │                    │  │
│  │           │ │  cto-review     │ │                    │  │
│  │           │ │  learn/commit   │ │                    │  │
│  └───────────┘ └─────────────────┘ └────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  전문 에이전트 팀 (13명)                                │  │
│  │  frontend-dev · backend-dev · engine-dev             │  │
│  │  design-dev   · design-reviewer                      │  │
│  │  security-auditor · test-engineer · qa-reviewer      │  │
│  │  docs-keeper                                         │  │
│  │  web-researcher · code-analyst (investigate팀)       │  │
│  │  perf-analyst · regression-hunter (investigate팀)    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  자동 적용 규칙 (rules/)                               │  │
│  │  frontend · server · shared-engine · tests · design  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  MCP 프리셋 (자동 등록)                                │  │
│  │  serena · context7 · sequential-thinking             │  │
│  │  playwright · chrome-devtools · shadcn               │  │
│  │  magic (21st.dev) · memory                           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 설치

```
# 1. 마켓플레이스 등록 (최초 1회)
/plugin marketplace add brandonnoh/woojoo-magic

# 2. 플러그인 설치
/plugin install wj-magic@woojoo-magic
/plugin install srt-magic@woojoo-magic

# 3. 활성화
/reload-plugins
```

설치하면 다음이 자동 적용됩니다:
- 커맨드/스킬/에이전트 등록
- hooks 이벤트 바인딩
- rules glob 매칭 활성화
- MCP 서버 프리셋 등록
- 권한 허용/차단 설정

---

## 구성요소 간 연결 관계

플러그인의 모든 구성요소가 어떻게 연결되는지 보여줍니다.

### 전체 흐름도

```
사용자 입력
  │
  ├─ "구현해줘" ─────→ /wj:devrule (스킬) ──→ [일반 개발 모드]
  ├─ "/wj:loop start" → loop.md (커맨드) ──→ [루프 개발 모드]
  ├─ "기획해줘" ─────→ /wj:ideation (스킬) ──→ 전문가 스쿼드 논의
  ├─ "팀 구성해줘" ──→ /wj:team (스킬) ────→ 에이전트 팀 병렬 작업
  └─ "전수 점검" ────→ /wj:cto-review (스킬) → 코드베이스 전수 점검
          │
          ▼
    ┌─ 개발 중 자동 작동 ───────────────────────────────────────┐
    │                                                          │
    │  파일 편집 시                                              │
    │   ├→ rules/ 규칙 자동 주입 (경로 glob 매칭)                 │
    │   ├→ quality-check.sh 즉시 품질 체크 (PostToolUse 훅)       │
    │   └→ references/ 품질 기준 참조 (INDEX.md 라우터)           │
    │                                                          │
    │  Bash 실행 시                                              │
    │   └→ block-dangerous.sh 위험 명령 차단 (PreToolUse 훅)      │
    │                                                          │
    │  Edit/Write 시                                            │
    │   └→ block-sensitive-write.sh 민감 파일 보호 (PreToolUse 훅) │
    │                                                          │
    │  매 턴 종료 시                                              │
    │   └→ stop-loop.sh → L1/L2/L3 게이트 실행 (Stop 훅)         │
    │                                                          │
    │  서브에이전트 종료 시                                        │
    │   └→ subagent-gate.sh → L1 게이트 실행 (SubagentStop 훅)   │
    │                                                          │
    └──────────────────────────────────────────────────────────┘
          │
          ▼
    구현 완료 후
      ├→ /wj:commit ──→ 한글 커밋 메시지 자동 생성
      ├→ docs-keeper ──→ 구조 변경 시 문서 동기화
      └→ /wj:learn ───→ 실패·반복 실수 시 교훈 축적
```

### 훅 이벤트 바인딩

어떤 이벤트가 발생하면 어떤 훅이 실행되고, 훅이 어떤 내부 스크립트를 호출하는지:

```
이벤트               훅                        내부 호출 (lib/)
─────────────────────────────────────────────────────────────────

SessionStart    ──→  bootstrap.sh              (환경 초기화)
                ──→  session-summary.sh        (세션 요약 출력)

PreToolUse
  [Bash]        ──→  block-dangerous.sh        (rm -rf, sudo 등 차단)
  [Edit|Write]  ──→  block-sensitive-write.sh  (.env, .pem 등 차단)

PostToolUse
  [Edit|Write]  ──→  quality-check.sh          patterns.sh 참조
                                               (즉시 파일 크기·금지 패턴 체크)

Stop            ──→  stop-loop.sh         ──→  gate-l1.sh (정적 감사)
                                          ──→  gate-l2.sh (타입 체크)
                                          ──→  gate-l3.sh (테스트)
                                          ──→  loop-state.sh (루프 상태)
                                          ──→  tasks-sync.sh (task 진행)

SubagentStop    ──→  subagent-gate.sh     ──→  gate-l1.sh (정적 감사)
```

### 스킬 → 에이전트 위임 조건

`/wj:devrule`과 `/wj:loop`이 에이전트를 선택하는 조건:

```
규모 판정
  │
  ├─ S (파일 1~3개) ───→ Claude 직접 구현 (에이전트 없음)
  │
  ├─ M (파일 4~10개) ──→ 전문 에이전트 1개 위임
  │                       │
  │                       ├→ 유형 판정 (아래 참조)
  │                       ├→ 구현 후 test-engineer 테스트 보강
  │                       └→ security-auditor + qa-reviewer 병렬 검수
  │
  └─ L (파일 10개+) ───→ 팀 에이전트 병렬 위임
                          │
                          ├→ 유형별 에이전트 각각 위임 (isolation: worktree)
                          ├→ 파일 소유권 엄격 분리 (같은 파일 2개 에이전트 금지)
                          ├→ 전체 완료 후 test-engineer 테스트 보강
                          └→ security-auditor + qa-reviewer 병렬 검수


유형 판정 (affected_packages 또는 tags 기반)
  │
  ├─ client/, web/, frontend/  ──→  frontend-dev
  ├─ server/, backend/, api/   ──→  backend-dev
  ├─ shared/, core/, domain/   ──→  engine-dev
  └─ 문서 변경                  ──→  docs-keeper


보조 에이전트 투입 조건
  │
  ├─ test-engineer
  │    조건: M/L 규모 구현 후 필수
  │    구현 에이전트 완료 → 테스트 커버리지 갭 분석 + 엣지케이스 + 누락 테스트 작성
  │    테스트 파일만 수정 (구현 코드 수정 금지)
  │
  ├─ security-auditor
  │    조건: 인증/API/입력처리/DB 관련 변경 시 (qa-reviewer와 병렬)
  │    PASS → 커밋 진행
  │    WARN → 커밋 가능 (후속 수정 권장)
  │    FAIL → CRITICAL 발견, 수정 후 재감사 필수
  │
  ├─ qa-reviewer
  │    조건: M/L 규모 구현 후 필수
  │    PASS → 커밋 진행
  │    FAIL → 재위임 (최대 2회, 총 3회 실패 시 중단)
  │           + /wj:learn 호출 (컨벤션 위반일 때)
  │
  └─ docs-keeper
       필수 조건: 새 공개 파일 3개+ 또는 API 시그니처 변경 또는 아키텍처 변경
       생략 가능: 기존 파일 내부 수정만 또는 테스트 파일만
```

### Rules → 파일 경로 자동 매칭

```
사용자가 client/components/Button.tsx 편집
  │
  ▼
rules/frontend.md 자동 주입
  │  globs: **/client/**, **/web/**, **/frontend/**
  │
  ├→ React/Vite/Zustand/TailwindCSS 규칙 적용
  ├→ Serena MCP로 심볼 탐색 필수
  └→ Context7 MCP로 라이브러리 문서 조회 필수


사용자가 server/routes/auth.ts 편집
  │
  ▼
rules/server.md 자동 주입
  │  globs: **/server/**, **/backend/**, **/api/**
  │
  ├→ Express/ws/Zod/Pino 규칙 적용
  └→ 개발 완료 후 QA 필수


사용자가 shared/types/user.ts 편집
  │
  ▼
rules/shared-engine.md 자동 주입
  │  globs: **/shared/**, **/core/**, **/domain/**
  │
  ├→ 순수 함수 규칙
  └→ IO 금지, 사이드이펙트 금지


사용자가 tests/auth.test.ts 편집
  │
  ▼
rules/tests.md 자동 주입
  │  globs: **/*.test.ts, **/*.spec.ts
  │
  └→ 테스트 프레임워크 규칙, 모킹 패턴
```

### References 로딩 체인

```
/wj:devrule 또는 /wj:loop 실행
  │
  ▼
Step 0: 언어 감지 (프로젝트 루트 파일 스캔)
  │  tsconfig.json → TypeScript
  │  pyproject.toml → Python
  │  go.mod → Go
  │  Cargo.toml → Rust
  │  Package.swift → Swift
  │  build.gradle.kts → Kotlin
  │
  ▼
references/INDEX.md (라우터) 읽기
  │
  ├→ 항상 로드
  │   ├── common/AGENT_QUICK_REFERENCE.md        (에이전트 포인터 — 단일 진실 공급원)
  │   ├── common/HIGH_QUALITY_CODE_STANDARDS.md  (공통 품질 원칙 상세)
  │   └── common/REFACTORING_PREVENTION.md       (리팩토링 방지)
  │
  └→ 감지된 언어만 로드 (컨텍스트 절약)
      │
      ├─ TS 감지 → typescript/standards.md
      │            + 필요 시 패턴 문서:
      │              Branded Types, Discriminated Union,
      │              Result Pattern, Non-null Elimination,
      │              Library Type Hardening, Zustand Slice
      │
      ├─ Python 감지 → python/standards.md
      ├─ Go 감지     → go/standards.md
      ├─ Rust 감지   → rust/standards.md
      ├─ Swift 감지  → swift/standards.md
      └─ Kotlin 감지 → kotlin/standards.md
```

---

## 두 가지 개발 모드

### 모드 1: 일반 개발 — 직접 요청

"이거 구현해줘", "버그 고쳐줘" 같은 직접 요청 시 `/wj:devrule` 스킬이 자동 작동합니다.

```
사용자: "로그인 기능 만들어줘"
  │
  ▼
/wj:devrule 자동 트리거
  │
  ├─ Step 0: 언어 감지 → references 로드
  ├─ Step 2: 규모 판정 (S/M/L)
  ├─ Step 3: 품질 기준 확인
  ├─ Step 4: 구현 (직접 또는 에이전트 위임)
  │           ├→ test-engineer 테스트 보강 (M/L)
  │           ├→ security-auditor + qa-reviewer 병렬 검수
  │           ├→ /wj:commit (커밋)
  │           ├→ docs-keeper (구조 변경 시)
  │           └→ /wj:learn (실패·반복 실수 시)
  │
  └─ 매 턴마다 Stop 훅 → L1/L2 게이트 자동 실행
```

### 모드 2: 루프 개발 — 자율 루프

PRD(요구사항 문서) 기반으로 여러 task를 자동 순회하며 개발합니다.

```
/wj:loop plan "채팅 앱 만들어줘"
  │
  ▼
코드베이스 분석 → PRD + tasks.json + specs 자동 생성
  │
  ▼
/wj:loop start
  │
  ▼
┌─────────────────────────────────────────────┐
│           자율 루프 (task 단위)               │◀────┐
│                                             │     │
│  A. Task 분석 — spec + criteria 파악         │     │
│         ▼                                   │     │
│  B. 규모·유형 판정 → 에이전트 선택            │     │
│         ▼                                   │     │
│  C. 에이전트 위임 — 구현 (S: 직접, M/L: 위임) │     │
│         ▼                                   │     │
│  D. 검수 — 테스트 + 보안 + QA + L1/L2/L3     │     │
│         │  FAIL → 재위임 (최대 2회)           │     │
│         │         + /wj:learn 교훈 축적       │     │
│         ▼                                   │     │
│  E. 완료 처리                                │     │
│     E-1. tasks.json → "done"                │     │
│     E-2. /wj:commit 커밋                     │     │
│     E-3. docs-keeper (구조 변경 시)           │     │
│     E-4. /wj:learn (QA FAIL 있었으면)         │     │
│     E-5. 다음 task 자동 전진 ─────────────────┘     │
│                                             │
└─────────────────────────────────────────────┘
  │
  ▼
모든 task 완료 → /wj:verify (최종 검증)
```

---

## 빠른 시작

```bash
# 1. 프로젝트 스캐폴딩
/wj:init --with-prd

# 2. docs/prd.md 편집 → 요구사항 작성

# 3. 루프 계획 생성 (PRD + tasks.json + specs 자동 생성)
/wj:loop plan

# 4. 자율 루프 시작
/wj:loop start

# 5. 중단하고 싶으면
/wj:loop stop

# 6. 최종 검증
/wj:verify
```

---

## 설치되는 전체 구조

```
src/woojoo-magic/
│
├── commands/                 ← 슬래시 커맨드 (5개)
│   ├── init.md                  /wj:init — 스캐폴딩
│   ├── loop.md                  /wj:loop — 자율 루프
│   ├── verify.md                /wj:verify — 빌드+테스트
│   ├── check.md                 /wj:check — 품질 전수 점검
│   └── help.md                  /wj:help — 가이드
│
├── skills/                   ← 자동 트리거 스킬 (13개)
│   ├── investigate/skill.md     /wj:investigate — 국정조사급 심층 이슈 분석
│   ├── commit/skill.md          /wj:commit — 한글 커밋
│   ├── devrule/                 /wj:devrule — 구조 적용 개발
│   │   ├── skill.md
│   │   └── references/          MACOS_DEV_REFERENCE, TROUBLESHOOTING
│   ├── tdd/skill.md             /wj:tdd — Red-Green-Refactor TDD 강제
│   ├── design/skill.md          /wj:design — 디자인 기획+구현
│   ├── polish/skill.md          /wj:polish — 디자인 개선
│   ├── brainstorm/skill.md      /wj:brainstorm — 아이디어 → 설계 문서
│   ├── plan/skill.md            /wj:plan — 스펙 → 구현 계획
│   ├── learn/skill.md           /wj:learn — 교훈 축적
│   ├── cto-review/              /wj:cto-review — 전수 점검
│   │   ├── skill.md
│   │   └── references/          review-checklist
│   ├── ideation/                /wj:ideation — 기획 논의
│   │   ├── skill.md
│   │   └── references/          squad (PM/UX/사업/마케팅/데이터)
│   └── team/                    /wj:team — 팀 병렬 작업
│       ├── skill.md
│       └── references/          agents (조직도)
│
├── agents/                   ← 전문 에이전트 (13개)
│   ├── frontend-dev.md          UI 기능 구현, 상태 관리
│   ├── backend-dev.md           API, DB, 인증
│   ├── engine-dev.md            도메인 규칙, 타입, 순수 함수
│   ├── design-dev.md            디자인 구현, CSS, 모션, 토큰
│   ├── design-reviewer.md       디자인 품질 리뷰, Anti-Slop
│   ├── security-auditor.md      보안 감사, OWASP Top 10
│   ├── test-engineer.md         테스트 설계, 커버리지 보강
│   ├── qa-reviewer.md           코드 리뷰, 회귀 검증
│   ├── docs-keeper.md           문서 동기화
│   ├── web-researcher.md        Context7+WebSearch CVE/유사이슈 조사
│   ├── code-analyst.md          Serena MCP 심볼 추적+SBFL 의심도 분석
│   ├── perf-analyst.md          Core Web Vitals+N+1/재렌더링 안티패턴 탐지
│   └── regression-hunter.md     git bisect 자동화+blame 회귀 도입 커밋 특정
│
├── rules/                    ← 파일 경로별 자동 적용 규칙 (7개)
│   ├── frontend.md              **/client/**, **/web/**, **/frontend/**
│   ├── server.md                **/server/**, **/backend/**, **/api/**
│   ├── shared-engine.md         **/shared/**, **/core/**, **/domain/**
│   ├── design.md                **/*.css, **/*.scss, **/*.styled.*
│   ├── tests.md                 **/*.test.ts, **/*.spec.ts
│   ├── db-migration.md          **/migrations/**, **/*.migration.*
│   └── scripts.md               **/*.sh, **/*.bash
│
├── hooks/                    ← 이벤트 훅 (7개)
│   ├── hooks.json               훅 이벤트 바인딩 설정
│   ├── session-summary.sh       SessionStart → 세션 시작 요약
│   ├── bootstrap.sh             SessionStart → 환경 초기화
│   ├── block-dangerous.sh       PreToolUse(Bash) → 위험 명령 차단
│   ├── block-sensitive-write.sh PreToolUse(Edit|Write) → 민감 파일 보호
│   ├── quality-check.sh         PostToolUse(Edit|Write) → 즉시 품질 체크
│   ├── stop-loop.sh             Stop → L1/L2/L3 게이트 실행
│   └── subagent-gate.sh         SubagentStop → 서브에이전트 L1 게이트
│
├── lib/                      ← 내부 스크립트 (훅에서 호출)
│   ├── gate-l1.sh               L1 정적 감사 (grep 기반)
│   ├── gate-l2.sh               L2 타입 체크 (tsc, pyright 등)
│   ├── gate-l3.sh               L3 targeted 테스트
│   ├── patterns.sh              공통 정규식 패턴 (gate-l1, quality-check이 공유)
│   ├── loop-state.sh            루프 상태 관리 (start/stop/status)
│   ├── tasks-sync.sh            tasks.json 동기화
│   ├── journal.sh               작업 일지 기록
│   └── investigation-utils.sh   /wj:investigate 헬퍼 (git-suspects, bisect, report-init)
│
├── references/               ← 품질 기준 레퍼런스 (INDEX.md가 라우팅)
│   ├── INDEX.md                 언어 감지 → 해당 언어만 로드
│   ├── common/                  공통 (모든 언어에 항상 로드)
│   │   ├── AGENT_QUICK_REFERENCE.md  에이전트 포인터 아키텍처 단일 진실 공급원
│   │   ├── HIGH_QUALITY_CODE_STANDARDS.md
│   │   ├── REFACTORING_PREVENTION.md
│   │   └── SKILL_PREAMBLE.md    스킬 공통 품질 프리앰블
│   ├── design/                  디자인 품질 레퍼런스 7개
│   │   ├── DESIGN_QUALITY_STANDARDS.md
│   │   ├── ANTI_SLOP_PATTERNS.md
│   │   ├── TYPOGRAPHY_SYSTEM.md
│   │   ├── COLOR_SYSTEM.md
│   │   ├── SPACING_RHYTHM.md
│   │   ├── LAYOUT_PATTERNS.md
│   │   └── MOTION_PRINCIPLES.md
│   ├── typescript/              TS 표준 + 패턴 6개
│   │   ├── standards.md
│   │   ├── BRANDED_TYPES_PATTERN.md
│   │   ├── DISCRIMINATED_UNION.md
│   │   ├── RESULT_PATTERN.md
│   │   ├── NON_NULL_ELIMINATION.md
│   │   ├── LIBRARY_TYPE_HARDENING.md
│   │   └── ZUSTAND_SLICE_PATTERN.md
│   ├── python/standards.md
│   ├── go/standards.md
│   ├── rust/standards.md
│   ├── swift/standards.md
│   └── kotlin/standards.md
│
├── templates/                ← /wj:init 스캐폴딩 템플릿
│   ├── CLAUDE.template.md       프로젝트 지도 템플릿
│   ├── docs/prd.template.md     PRD 템플릿
│   └── .dev/tasks.template.json task 레지스트리 템플릿
│
├── mcp-presets/              ← MCP 서버 자동 등록
│   └── default.json             8개 MCP 서버 프리셋
│
└── settings.json             ← 권한 허용/차단 설정
```

---

## 커맨드 레퍼런스

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 커맨드 가이드 출력 |
| `/wj:init` | `[--with-prd]` | 클린 스캐폴딩 (docs/ + .dev/ + CLAUDE.md) |
| `/wj:loop` | `plan <요구사항> \| start [task-id] \| stop \| status` | PRD/task 생성 + 세션 내 자율 루프 |
| `/wj:verify` | `[--smoke]` | 전체 빌드+테스트 최종 검증 |
| `/wj:check` | — | 품질 전수 점검 (6개 언어) |

## 스킬 레퍼런스

| 스킬 | 역할 | 트리거 |
|------|------|--------|
| `/wj:investigate` | 국정조사급 심층 이슈 분석 (5 에이전트 팀 + 웹 리서치 + 자동 수정) | "버그", "조사", "안된다", "느려", "보안", "원인 찾아줘" |
| `/wj:devrule` | 프로젝트 구조 적용 개발 (S/M/L 규모별 전략) | "구현해줘", "만들어줘", "고쳐줘" |
| `/wj:tdd` | Red-Green-Refactor TDD 프로세스 강제 | "TDD로", "테스트 먼저" |
| `/wj:brainstorm` | 아이디어 → 설계 문서 1:1 대화 | "기획 도와줘", "아이디어 있어", "어떻게 만들지" |
| `/wj:plan` | 스펙 → 구현 계획 (태스크 분해) | "계획 세워줘", "태스크 나눠줘" |
| `/wj:design` | 디자인 기획 + 구현 (방향 설정 → 구현 → 리뷰) | "디자인해줘", "UI 만들어줘", "랜딩페이지" |
| `/wj:polish` | 기존 UI 디자인 개선 (진단 → 처방 → 검증) | "디자인 개선", "더 예쁘게", "AI스러워" |
| `/wj:learn` | 교훈을 개발 규칙에 축적 | "기억해", QA 실패 시 자동 |
| `/wj:cto-review` | 코드베이스 전수 점검 + 최적화 | "코드 리뷰", "전수 점검" |
| `/wj:ideation` | 전문가 스쿼드 기획 논의 | "기획해줘", "아이데이션" |
| `/wj:team` | 에이전트 팀 구성 병렬 작업 | "팀 구성", "에이전트 소환" |
| `/wj:commit` | 한글 커밋 메시지 자동 생성 | "커밋해줘", "commit" |

## 전문 에이전트

작업 규모가 M/L이면 Claude가 직접 코딩하지 않고 전문 에이전트에게 위임합니다.
`/wj:investigate` 실행 시에는 조사 전문 4명이 병렬 투입됩니다.

```
┌─────────────────────────────────────────────────────────────────┐
│                 Claude (PM/오케스트레이터)                         │
│          분석 → 위임 → 검수 → 커밋만 수행                         │
└──┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬────────────┘
   ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼
frontend backend engine design  test  security  qa    docs
  -dev    -dev    -dev   -dev  engineer auditor reviewer keeper

/wj:investigate Phase 1 병렬 조사팀 (run_in_background: true):
  web-researcher · code-analyst · perf-analyst · regression-hunter
```

**개발 흐름 (devrule/loop):**
```
구현 에이전트 (frontend/backend/engine/design-dev)
    │
    ▼
test-engineer (테스트 보강) ── 순차
    │
    ├──→ design-reviewer (디자인 리뷰) ─┐
    ├──→ security-auditor (보안 감사) ──┤── 병렬
    └──→ qa-reviewer (최종 리뷰) ───────┘
              │
              ▼
         커밋 → docs-keeper → learn
```

**조사 흐름 (/wj:investigate):**
```
Phase 0: 트리아지 (이슈 타입 감지: bug/perf/security/arch)
    │
Phase 1: 병렬 조사 (5 에이전트, run_in_background)
    ├──→ web-researcher   (Context7 + WebSearch + CVE)
    ├──→ code-analyst     (Serena MCP + SBFL 의심도)
    ├──→ perf-analyst     (Chrome DevTools + N+1 탐지)
    ├──→ regression-hunter (git bisect + blame)
    └──→ security-auditor (OWASP Top 10)
    │
Phase 2: 수렴 (Sequential Thinking 7단계 RCA)
    │
Phase 3: 수정 (devrule S/M/L 패턴)
    │
Phase 4: 검증 (L1/L2/L3 게이트)
    │
Phase 5: 리포트 + Memory MCP 저장 + /wj:learn
```

| 에이전트 | 담당 영역 | 투입 조건 |
|----------|----------|----------|
| `frontend-dev` | UI 기능 구현, 상태 관리, 컴포넌트 로직 | affected_packages에 client/web/frontend 포함 |
| `backend-dev` | API, WebSocket, DB, 인증, 세션 | affected_packages에 server/backend/api 포함 |
| `engine-dev` | 도메인 규칙, 타입 정의, 순수 함수 | affected_packages에 shared/core/domain 포함 |
| `design-dev` | 시각적 설계, CSS/스타일, 디자인 토큰, 모션 | UI 디자인/비주얼/스타일링 task |
| `design-reviewer` | 디자인 품질 리뷰, Anti-Slop, 접근성 검증 | UI 변경 시 (qa-reviewer와 병렬) |
| `security-auditor` | OWASP Top 10, XSS, 인젝션, 인증 검증 | 인증/API/입력처리/DB 관련 변경 시 |
| `test-engineer` | 테스트 설계, 커버리지 보강, 엣지케이스 | M/L 규모 구현 후 **필수** |
| `qa-reviewer` | 코드 리뷰, 품질 검증, 회귀 체크 | M/L 규모 구현 후 **필수** |
| `docs-keeper` | 문서 동기화, CLAUDE.md 반영 | 새 파일 3개+ 또는 API/아키텍처 변경 시 |
| `web-researcher` | Context7+WebSearch CVE/유사 이슈 조사 | `/wj:investigate` Phase 1 |
| `code-analyst` | Serena MCP 심볼 추적, SBFL 의심도 분석 | `/wj:investigate` Phase 1 |
| `perf-analyst` | Core Web Vitals, N+1/재렌더링 안티패턴 | `/wj:investigate` Phase 1 |
| `regression-hunter` | git bisect 자동화, blame 회귀 분석 | `/wj:investigate` Phase 1 |

## 자동 적용 규칙 (Rules)

**편집하는 파일 경로가 glob 패턴에 매칭되면, 해당 규칙이 Claude의 컨텍스트에 자동 주입됩니다.**
사람이 아무 명령을 하지 않아도 — 파일을 열거나 편집하는 것만으로 규칙이 활성화됩니다.

```
예시: client/components/Button.tsx 를 편집
  │
  ▼
Claude 컨텍스트에 rules/frontend.md 자동 주입
  → "Serena MCP로 심볼 탐색 필수"
  → "레이아웃 변경 전 뷰포트 예산 계산"
  → "비즈니스 로직 컴포넌트 인라인 금지"
  → "Quality Standards: AGENT_QUICK_REFERENCE.md"
     ... 이 모든 것을 Claude가 알고 작업
```

규칙 파일은 `rules/` 디렉터리에 있으며, frontmatter의 `globs:` 배열이 매칭 조건입니다.

| 규칙 | 자동 매칭 경로 | 핵심 내용 |
|------|--------------|----------|
| `frontend` | `**/client/**`, `**/web/**`, `**/frontend/**` | Serena+Context7 MCP 필수, 레이아웃 체크리스트 5항목, 비즈니스 로직 인라인 금지 |
| `server` | `**/server/**`, `**/backend/**`, `**/api/**` | 엔진 경계 강제, Zod 런타임 검증, 가상 파일 생성 금지, QA 필수 |
| `shared-engine` | `**/shared/**`, `**/core/**`, `**/domain/**` | 순수 함수 강제, IO 절대 금지, 불변성, 빌드+테스트 통과 필수 |
| `design` | `**/*.css`, `**/*.scss`, `**/*.styled.*` | Anti-Slop 4항목, WCAG AA 접근성, design-reviewer 필수 |
| `tests` | `**/*.test.ts`, `**/*.spec.ts` | AAA 패턴, 팩토리 함수, 가짜 테스트 금지 |
| `db-migration` | `**/migrations/**`, `**/*.migration.*` | 롤백 필수, 트랜잭션, 데이터 파괴 작업 체크리스트, 기존 파일 수정 금지 |
| `scripts` | `**/*.sh` | `set -euo pipefail` 필수, 멱등성, 에러 메시지 필수, rm -rf 가드 |

## 품질 게이트 (자동)

매 턴 종료 시 Stop hook이 자동 실행합니다. 별도 명령 불필요.

```
매 턴 종료
  │
  ├─ L1 정적 감사 ·····················  <1초
  │    파일 크기, 금지 패턴(any, !., silent catch),
  │    eslint-disable, 함수 길이, 복잡도
  │
  ├─ L2 타입 체크 ·····················  2~10초
  │    tsc --noEmit (TS), pyright (Python),
  │    go vet (Go), cargo check (Rust) 등
  │
  └─ L3 테스트 ························  5~30초
       편집된 파일과 매칭되는 테스트만 실행
```

| 게이트 | 내용 | 속도 | 실행 조건 |
|--------|------|------|----------|
| L1 | grep 기반 정적 감사 | <1초 | 매 턴 (항상) |
| L2 | 타입 체크 / 컴파일 | 2~10초 | 코드 변경 시 |
| L3 | targeted test | 5~30초 | 루프 모드 + 코드 변경 시 |

전체 빌드/smoke test는 `/wj:verify`로 수동 실행.

### 지원 언어별 품질 기준

| 언어 | 파일 한도 | 함수 한도 | 금지 패턴 |
|------|----------|----------|----------|
| TypeScript | 300줄 | 20줄 | `any`, `!.`, `as` 남용, silent catch |
| Python | 600줄 | 50줄 | `Any`, bare `except:`, `except: pass` |
| Go | 500줄 | 40줄 | `interface{}`, `_ = err`, `panic()` |
| Rust | 500줄 | 40줄 | `unwrap()`, `unsafe` 남용, `clone()` 남용 |
| Swift | 400줄 | 30줄 | force unwrap `!`, `Any`, `try!`, `as!` |
| Kotlin | 400줄 | 30줄 | `!!`, `Any`, `var` 남용, `GlobalScope` |

## MCP 서버 프리셋

설치 시 다음 MCP 서버가 자동 등록됩니다.
rules와 skills에서 이 MCP 서버들의 사용을 요구합니다.

| MCP 서버 | 용도 | 사용하는 곳 |
|----------|------|-----------|
| **Serena** | 시맨틱 코드 탐색 (심볼 기반 읽기/수정) | rules (전 규칙), devrule |
| **Context7** | 라이브러리 공식 문서 실시간 조회 | rules (전 규칙), devrule |
| **Sequential Thinking** | 복잡한 리팩토링 계획 수립 | devrule |
| **Playwright** | 브라우저 자동화 테스트 | frontend 규칙, 테스트 |
| **Chrome DevTools** | 브라우저 디버깅, 성능 분석 | frontend 규칙 |
| **shadcn/ui** | UI 컴포넌트 레지스트리 조회 | frontend 규칙 |
| **Magic (21st.dev)** | AI 컴포넌트 빌더 | frontend 규칙 |
| **Memory** | 세션 간 메모리 저장 | learn 스킬 |

## 권한 설정

`settings.json`으로 자동 허용/차단 권한이 설정됩니다:

**허용** — Read, Edit, Write, Grep, Glob, pnpm/npm/yarn, git 기본 명령, ls, mkdir, cp, mv 등

**차단** — `rm -rf`, `sudo`, `git push --force`, `chmod 777`, `/dev` 리다이렉트

## /wj:init 이 생성하는 프로젝트 구조

```
your-project/
├── CLAUDE.md          ← 프로젝트 지도 (~100줄, 사람이 편집)
├── docs/              ← 비즈니스 문서 (사람이 관리)
│   ├── prd.md         ← 요구사항 정의서 (--with-prd 시)
│   └── specs/         ← task별 상세 구현 가이드
└── .dev/              ← AI 작업 흔적 (자동 생성, .gitignore 권장)
    ├── tasks.json     ← task 레지스트리 (상태 추적)
    ├── journal/       ← 작업 일지
    └── state/         ← 루프 상태
```

## v2에서 마이그레이션

`docs/MIGRATION.md` 참조.

## 라이선스

MIT
