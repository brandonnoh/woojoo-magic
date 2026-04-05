# woojoo-magic

> **리팩토링이 필요 없도록 처음부터 실리콘밸리 수준으로 코딩하는 Claude Code 플러그인**

13 skills + 5 agents + Ralph v2 자율 개발 루프 + 10 MCPs + 8 quality standards 문서를 하나의 플러그인으로 묶어 다른 머신/프로젝트에 이식 가능하게 했다.

---

## 철학

> "리팩토링은 실패의 신호다. 처음부터 제대로 짜면 리팩토링이 필요 없다."

이 플러그인은 방어적 설계가 아니라 **공격적 품질 강제**를 지향한다. 코드 작성 전(Pre-gate), 작성 중(Skill/Agent), 작성 후(Reviewer/Quality-gate) 모든 단계에서 Silicon Valley 수준의 품질 기준을 자동 적용한다.

---

## 포함 내용

### Skills (13개)
| 스킬 | 역할 |
|------|------|
| `devrule` | 개발 작업 전반 워크플로우 |
| `senior-frontend` | React/Vite/Zustand 등 프론트엔드 |
| `backend-dev-rules` | 백엔드 설계 |
| `commit` | 한글 커밋 메시지 표준 |
| `learn` | 발견한 교훈을 규칙에 자동 반영 |
| `team` | 에이전트 병렬 작업 오케스트레이션 |
| `ui-ux-pro-max` | UI/UX 디자인 지식 |
| `cto-review` | 전수 코드 리뷰 |
| `init-prd` | PRD → tests.json 변환 |
| `ideation` | 기능 기획 5인 스쿼드 |
| `feedback-to-prd` | 피드백 자동 반영 |
| `implement-next` | TDD 기반 next task 구현 |
| `seo-optimizer` | SEO 최적화 |

모든 스킬은 `shared-references/HIGH_QUALITY_CODE_STANDARDS.md`를 참조한다.

### Agents (5개)
- `frontend-dev` — React/Vue/Svelte UI 전문
- `backend-dev` — Express/Fastify/NestJS 서버 전문
- `engine-dev` — 순수 함수/비즈니스 로직 (IO 금지)
- `qa-reviewer` — Creator-Reviewer 패턴의 Reviewer 역할
- `docs-keeper` — 코드 변경 시 문서 자동 동기화

### Shared References (8개)
실전 검증된 고품질 코딩 가이드:
- **HIGH_QUALITY_CODE_STANDARDS.md** — 파일/함수 크기, 타입 안전, React, 상태, 성능, DRY
- **BRANDED_TYPES_PATTERN.md** — PlayerId/ChipAmount/SessionId 팩토리 + 경계 캐스트
- **RESULT_PATTERN.md** — throw → Result<T,E> 전환, tryAsync 헬퍼
- **DISCRIMINATED_UNION.md** — wrapSetWithPhase 무침습 패턴 (Zustand 호환)
- **NON_NULL_ELIMINATION.md** — `!` 금지, guard clause + 로컬 변수
- **LIBRARY_TYPE_HARDENING.md** — viem 등 any 제거 (Context7 조회 필수)
- **ZUSTAND_SLICE_PATTERN.md** — 도메인별 슬라이스 + actions 분리
- **REFACTORING_PREVENTION.md** — "이미 늦었다" 시그널 사전 감지

### Ralph v2 — 자율 개발 루프
단순 `claude -p` 루프가 아닌 **5-Stage Pipeline + Quality Gates + Parallel Workers**:

```
Stage 0: Pre-Gate          (bash, git clean + 품질 스냅샷)
Stage 1: Planner           (claude -p haiku, task 선별 + 병렬 그룹)
Stage 2: Workers (N개)     (claude -p sonnet, TDD 구현)
Stage 3: Quality Gate      (bash, 빌드/테스트/품질 델타 검증)
Stage 4: Reviewer          (claude -p opus, diff 리뷰)
Stage 5: Post-Gate         (bash, 커밋/메트릭/LESSONS 기록)
```

| 항목 | 기존 ralph.sh | Ralph v2 |
|------|--------------|----------|
| 구조 | 단일 `claude -p` | 5-stage 파이프라인 |
| 모델 라우팅 | 없음 | haiku/sonnet/opus 역할 분담 |
| 품질 검증 | 없음 | 300줄/any/!./테스트 정량 델타 |
| 롤백 | 없음 | 자동 git reset |
| 메트릭 | 없음 | append-only metrics.jsonl |
| 병렬화 | 없음 | `--parallel N` 워커 |
| 회귀 차단 | 없음 | `--strict` 모드 |

### MCP (10개)
자동으로 dedup 설치:
- **serena** — 심볼릭 코드 탐색
- **context7** — 라이브러리 공식 문서
- **sequential-thinking** — 복잡한 reasoning
- **playwright** — 브라우저 E2E
- **chrome-devtools** — 성능 측정
- **shadcn** — shadcn/ui 컴포넌트
- **magic** — 21st.dev UI 생성
- **tavily-remote** — 웹 리서치
- **memory** — 세션 간 영구 메모리 (learn 스킬 시너지)
- **smithery-ai-github** — GitHub API

### Commands (7개, prefix `wj`)
- `/wj:help` — 전체 커맨드 가이드
- `/wj:init` — Ralph v2 재설치 (첫 세션 자동 부트스트랩)
- `/wj:check` — 품질 전수 점검 (300줄/any/!./중복)
- `/wj:harness` — 하네스 건강 진단
- `/wj:brand` — Branded Types 마이그레이션
- `/wj:result` — Result 패턴 도입
- `/wj:plan` — 리팩토링 계획 생성

### Hooks (4개)
- **SessionStart**: `install-mcp.sh` (MCP 자동 dedup 설치), `session-summary.sh` (프로젝트 상태 요약)
- **PreToolUse (Bash)**: `block-dangerous.sh` (rm -rf, sudo, force push 등 차단)
- **PostToolUse (Edit/Write)**: `quality-check.sh` (편집 파일 300줄/any/!./silent catch 감지)

---

## 설치

### 방법 1: 로컬 개발 (이 저장소에서 직접)
```bash
git clone https://github.com/your-org/woojoo-magic ~/Documents/GitHub/woojoo-magic
cd ~/your-project
claude --plugin-dir ~/Documents/GitHub/woojoo-magic/plugins/woojoo-magic
```

### 방법 2: Marketplace 등록 (권장)
```bash
# Claude Code 세션 내
/plugin marketplace add your-org/woojoo-magic
/plugin install woojoo-magic@woojoo-tools
```

### 첫 세션 후 자동 동작
1. **SessionStart 훅**이 자동 실행되며 `~/.claude.json`과 dedup하여 프로젝트 `.mcp.json`에 누락 MCP 병합
2. 프로젝트 상태 요약 출력 (브랜치, 커밋, 품질 메트릭)
3. 즉시 13 skills + 5 agents + 10 MCPs 사용 가능

### Ralph v2 부트스트랩 (선택)
```
/wj:init-ralph
```
현재 프로젝트에 `ralph.sh`, `prd.md`, `tests.json`, `.ralph-state/` 셋업.

---

## 사용 예시

### 예시 1: 새 기능 구현
```
/devrule 결제 기능 구현해줘
```
→ serena로 영향 탐색 → context7로 결제 SDK 문서 조회 → TDD 구현 → 빌드/테스트 → commit 스킬로 커밋

### 예시 2: 리팩토링 계획
```
/wj:refactor-plan
```
→ 300줄 초과 파일 감지 → 분할 계획 자동 생성 → 의존성 순서 제안

### 예시 3: 자율 개발 루프
```bash
bash ralph.sh --parallel 2 --strict
```
→ tests.json의 eligible task를 2개 병렬 워커로 구현 → 품질 회귀 시 즉시 중단

---

## 디렉토리 구조

```
woojoo-magic/
├── .claude-plugin/
│   └── marketplace.json              # Marketplace 정의
└── plugins/
    └── woojoo-magic/
        ├── .claude-plugin/plugin.json
        ├── .mcp.json                 # 10개 MCP
        ├── settings.json             # 권한
        ├── skills/                   # 13개
        ├── agents/                   # 5개
        ├── shared-references/        # 8개 quality docs
        ├── hooks/                    # 4개 훅 + hooks.json
        ├── commands/                 # 6개 슬래시 커맨드
        ├── rules/                    # 4개 레이어별 규칙
        └── templates/
            └── ralph-starter-kit/    # Ralph v2 전체
                ├── ralph.sh
                ├── lib/              # 6개 bash 모듈
                ├── prompts/          # 3개 (planner/worker/reviewer)
                ├── schemas/          # 3개 JSON 스키마
                └── templates/        # prd/tests/progress 템플릿
```

---

## 라이선스

MIT

---

## Credits

crypto-holdem 프로젝트의 리팩토링 여정에서 축적된 실전 패턴을 기반으로 작성되었다. 특히 Phase 1-7 리팩토링 과정에서 검증된:
- 39개 파일 → 0개 (300줄 초과)
- Branded Types 전면 적용 (140+ 파일)
- Result<T,E> 패턴 전환 (엔진 12개 함수)
- Discriminated Union 무침습 도입 (wrapSetWithPhase)
- Non-null assertion 25개 완전 제거
- viem any 9개 → 공식 타입

이 모든 교훈이 `shared-references/`에 담겨있다.
