---
description: 세션 내 자율 개발 루프 — plan/start/stop/status
argument-hint: "plan <요구사항> | start [task-id] | stop | status"
---

세션 내 Ralph 루프를 제어한다. **메인 세션은 오케스트레이터 전용** — 직접 코드를 작성하지 않고, 분석·에이전트 위임·커밋만 수행한다.

## 사용법

| 명령 | 동작 |
|------|------|
| `/wj:loop plan` | 요구사항 분석 → PRD + tasks.json + specs 자동 생성 |
| `/wj:loop start` | 다음 eligible task로 루프 시작 (기본 타임아웃 없음) |
| `/wj:loop start <task-id>` | 특정 task로 루프 시작 |
| `/wj:loop start <task-id> <분>` | 특정 task + 커스텀 타임아웃 (예: 120 = 2시간, 0 = 무제한) |
| `/wj:loop stop` | 루프 즉시 중단 |
| `/wj:loop status` | 현재 루프 상태 표시 |

## 핵심 원칙

1. **메인 세션 = PM/오케스트레이터**: 코드 작성 금지, 분석·위임·검수·커밋만
2. **모든 구현은 Agent 도구로 위임**: 서브에이전트가 독립 컨텍스트에서 작업
3. **task 완료마다 커밋**: 게이트 통과 + QA PASS 후 즉시 자동 커밋
4. **컨텍스트 절약**: 메인 세션은 에이전트 결과 요약만 수신

## 실행 절차

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

### plan

요구사항(대화 컨텍스트 또는 인자)을 분석하여 루프 실행에 필요한 모든 재료를 생성한다.

#### Plan-1. 스캐폴딩 확인

`.dev/tasks.json`과 `docs/` 디렉토리가 없으면 자동 생성:
```bash
mkdir -p docs/specs .dev/state .dev/journal
```
`tasks.json` 없으면 빈 레지스트리 생성.

#### Plan-2. 요구사항 분석 (코드베이스 기반)

사용자의 요구사항을 바탕으로 **실제 코드를 읽고** 분석한다:

1. **코드베이스 스캔** — Glob/Grep으로 관련 파일 탐색, 영향 범위 파악
2. **현재 구조 파악** — 수정 대상 파일을 **Read로 실제 읽어서** 줄 번호, 함수 구조, 의존 관계 기록
3. **task 도출** — 각 작업 단위를 독립적이고 원자적인 task로 분할
   - UI/페이지 생성 task는 `tags: ["design"]` 추가 → design-dev 에이전트 자동 투입
   - 디자인 시스템 변경 task는 `tags: ["design-system"]` 추가
4. **의존성 분석** — task 간 선후 관계 + 파일 간 의존 관계 파악
   - 디자인 task는 보통 기능 구현 task 이후 (engine → backend → frontend → design)
5. **규모 추정** — 각 task의 affected_packages, 예상 파일 수

> **핵심**: "무엇을 할지"가 아닌 "현재 코드가 어떻고, 어디를 어떻게 바꿀지"를 파악하는 단계.

#### Plan-3. 산출물 생성

다음 3개 산출물을 생성한다:

**① `docs/prd.md`** — 전체 계획 문서 (사람이 읽는 로드맵)
```markdown
# PRD — {프로젝트/이니셔티브 이름}

## 개요
- 목표: {한 문장}
- 범위: {영향 범위}

## Phase 1 — {테마}
- [ ] task-001 {task 제목}
- [ ] task-002 {task 제목}

## Phase 2 — {테마}
- [ ] task-003 {task 제목}
```

**② `.dev/tasks.json`** — 루프 엔진이 읽는 task 레지스트리
```json
{
  "summary": { "total": N, "done": 0, "in_progress": 0, "pending": N },
  "features": [
    {
      "id": "task-001",
      "title": "한글 제목",
      "status": "pending",
      "priority": "critical|high|medium|low",
      "affected_packages": ["lib", "hooks"],
      "tags": ["gate", "python"],
      "acceptance_criteria": [
        "검증 가능한 구체적 수락 조건 (빌드 통과, 파일 존재, grep 결과 등)",
        "bash -n 문법 검증 통과"
      ],
      "test_scenarios": [
        "구체적 테스트 시나리오"
      ],
      "depends_on": []
    }
  ]
}
```

**③ `docs/specs/{task-id}.md`** — 각 task의 상세 구현 가이드 (**핵심**)

모든 task에 spec을 생성한다. **에이전트가 이 문서만 읽고 구현할 수 있을 만큼 상세하게 작성**:

```markdown
# {task-id}: {제목}

## 배경
왜 이 변경이 필요한지. 현재 어떤 문제가 있는지.

## 현재 코드 구조
수정 대상 파일의 현재 상태를 줄 번호와 함께 기술:
- `파일경로` (N줄)
  - 줄 1-20: {역할 설명}
  - 줄 21-50: {역할 설명}
  - 줄 51: 문제가 되는 코드 `{실제 코드 스니펫}`

## 변경 범위
| 파일 | 변경 유형 | 줄 범위 | 내용 |
|------|----------|---------|------|
| `lib/gate-l2.sh` | 수정 | 12-15 | 조기 종료 → 언어 분기 추가 |
| `lib/gate-l2.sh` | 추가 | 48 뒤 | Python 타입체크 블록 |

## 구현 방향
구체적 구현 코드 또는 before/after 스니펫:

### Before (현재 줄 12-15)
\`\`\`bash
if [[ ! -f "tsconfig.json" ]]; then
  echo "[L2] skip (tsconfig 없음)"
  exit 0
fi
\`\`\`

### After
\`\`\`bash
# tsconfig.json, pyproject.toml, go.mod 등 순차 확인
_detected=0
\`\`\`

## 의존 관계
- 이 파일을 source 하는 곳: `hooks/stop-loop.sh` (줄 86)
- 이 파일이 source 하는 곳: 없음
- 이 변경에 영향받는 파일: `references/INDEX.md` (L2 지원 언어 목록)

## 수락 조건
tasks.json의 acceptance_criteria와 동일.

## 검증 명령
\`\`\`bash
bash -n lib/gate-l2.sh  # 문법 검증
\`\`\`
```

> **spec 작성의 핵심 원칙**:
> - **에이전트는 spec만 읽고 구현할 수 있어야 한다** — 추가 탐색 없이
> - **줄 번호는 필수** — 현재 코드의 정확한 위치
> - **before/after는 필수** — 뭘 어떻게 바꿀지 명확하게
> - **의존 관계는 필수** — 이 파일을 바꾸면 어디가 영향받는지
> - **검증 명령은 필수** — 완료 후 어떻게 확인하는지

#### Plan-4. 계획 출력

```
📋 루프 계획 생성 완료

PRD:    docs/prd.md
Tasks:  .dev/tasks.json ({N}개 task)
Specs:  docs/specs/ ({M}개 spec)

Phase 1: {task 목록}
Phase 2: {task 목록}

의존성 순서:
  task-001 → task-002 → task-003
  task-004 (독립)

🚀 다음: /wj:loop start
```

#### Plan 규칙

- task ID는 짧고 의미 있게 (`fix-l2-multilang`, `extract-skill-preamble`)
- acceptance_criteria는 **검증 가능한** 구체적 조건 (빌드 통과, 파일 존재 등)
- 의존성이 있는 task는 `depends_on` 필드로 명시
- Phase는 의존성 기준으로 자연스럽게 그룹핑
- 하나의 task는 하나의 커밋으로 끝나는 크기 (S/M 규모)
- L 규모가 예상되면 더 작게 분할

---

### start

1. `.dev/tasks.json` 존재 확인. 없으면:
   ```
   ⚠️ .dev/tasks.json이 없습니다. /wj:loop plan으로 계획을 먼저 생성하세요.
   ```

2. task-id 인자가 있으면 해당 task, 없으면 다음 eligible task 자동 선택.
   세 번째 인자로 타임아웃(분)을 설정할 수 있음 (기본 60분):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" start "<task-id>" [timeout-min]
   ```

3. 선택된 task 정보 출력:
   ```
   🚀 루프 시작: task=<task-id>

   모드: 에이전트 위임 (메인 세션은 오케스트레이션만)
   Stop hook이 매 턴 종료 시 L1/L2/L3 게이트를 실행합니다.

   중단: /wj:loop stop
   ```

4. **Step A: Task 분석** → **Step B: 에이전트 선택** → **Step C: 위임 실행** → **Step D: 검수** → **Step E: 커밋** 순서로 진행.

### stop

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" stop "manual"
```

출력:
```
⏹ 루프 중단됨. 일반 대화 모드로 복귀.
```

### status

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/loop-state.sh" status
```

---

## Step A: Task 분석 (메인 세션이 직접)

1. `docs/specs/<task-id>.md`가 있으면 **반드시 읽기**
2. `.dev/tasks.json`에서 해당 task의 정보 추출:
   - `affected_packages` — 변경 대상 패키지/디렉토리
   - `acceptance_criteria` — 수락 조건
   - `test_scenarios` — 테스트 시나리오
   - `tags` — 도메인 키워드
3. 프로젝트 CLAUDE.md 읽어서 기술 스택·디렉토리 구조 파악
4. 변경 대상 파일을 Glob/Grep으로 빠르게 스캔 (내용은 읽지 않음 — 에이전트가 읽음)

---

## Step B: 에이전트 선택 — 규모·유형 판단 매트릭스

### B-1. 규모 판정

| 규모 | 기준 | 에이전트 전략 |
|------|------|-------------|
| **S (Small)** | 단일 패키지, 파일 1~3개 변경 예상 | 단독 에이전트 1개 |
| **M (Medium)** | 단일 패키지, 파일 4~10개 또는 테스트 포함 | 단독 에이전트 1개 + QA 리뷰 |
| **L (Large)** | 복수 패키지 또는 파일 10개+ | 팀 에이전트 (병렬) + QA 리뷰 |

### B-2. 유형별 에이전트 매핑

| 유형 키워드 | 주 에이전트 | subagent_type |
|------------|-----------|---------------|
| UI, 컴포넌트, 스토어, 애니메이션, CSS, 레이아웃 | `wj:frontend-dev` | `wj:frontend-dev` |
| API, WebSocket, DB, 세션, 인증, 라우트, 미들웨어 | `wj:backend-dev` | `wj:backend-dev` |
| 도메인 규칙, 타입 정의, 순수 함수, 엔진, 공유 로직 | `wj:engine-dev` | `wj:engine-dev` |
| 디자인 구현, 비주얼, 스타일링, CSS, 애니메이션, 색상, 타이포 | `wj:design-dev` | `wj:design-dev` |
| 디자인 리뷰, 시각 품질, Anti-Slop, 접근성 검증 | `wj:design-reviewer` | `wj:design-reviewer` |
| 보안 감사, OWASP, 취약점, XSS, 인젝션 | `wj:security-auditor` | `wj:security-auditor` |
| 테스트 설계, 커버리지 보강, 엣지케이스, E2E | `wj:test-engineer` | `wj:test-engineer` |
| 문서 동기화, LESSONS, progress 기록 | `wj:docs-keeper` | `wj:docs-keeper` |
| 코드 리뷰, 품질 검증, 회귀 체크 | `wj:qa-reviewer` | `wj:qa-reviewer` |

**판정 우선순위:**
1. `affected_packages`가 있으면 → 패키지명으로 매핑 (client→frontend, server→backend, shared/core/domain→engine)
2. `tags`가 있으면 → 키워드로 매핑
3. 둘 다 없으면 → spec/criteria 내용을 읽고 유형 판단

### B-3. 규모별 실행 전략

#### S/M — 단독 에이전트

```
메인 세션 → Agent(단독 에이전트) → 결과 수신 → [QA] → 커밋
```

- S: QA 생략 가능 (게이트만으로 충분)
- M: QA 에이전트로 리뷰 (`run_in_background: false` — 결과 기다림)

#### L — 팀 에이전트 (병렬)

```
메인 세션 (PM)
  ├→ Agent(engine-dev, isolation: "worktree", run_in_background: true)
  ├→ Agent(backend-dev, isolation: "worktree", run_in_background: true)
  └→ Agent(frontend-dev, isolation: "worktree", run_in_background: true)
       ↓ 전체 완료 대기
  └→ Agent(qa-reviewer) → 검수
       ↓ PASS
  └→ 커밋
```

**L 규모 필수 규칙:**
- 파일 소유권 엄격 분리 — 같은 파일을 2개 에이전트가 수정 금지
- `isolation: "worktree"` 필수 — 충돌 방지
- `run_in_background: true` — 병렬 실행
- 의존 순서가 있으면 (engine → backend → frontend) 순차 실행

---

## Step C: 에이전트 위임 실행

### 에이전트 프롬프트 템플릿

모든 에이전트에게 다음 구조의 프롬프트를 전달:

```
[{에이전트명}] task={task-id} 구현을 수행해줘.

## Task 정보
- task-id: {id}
- 수락 조건: {acceptance_criteria 전문}
- 테스트 시나리오: {test_scenarios 전문}

## Spec
{docs/specs/<task-id>.md 내용 또는 "spec 없음 — criteria 기준으로 구현"}

## 프로젝트 컨텍스트
- 기술 스택: {CLAUDE.md에서 추출}
- 디렉토리 구조: {관련 패키지 경로}

## 소유 파일 범위
{이 에이전트가 수정할 수 있는 파일/디렉토리 목록}

## 작업 지시
1. 소유 범위 내 파일을 읽고 현재 구조 파악
2. TDD: 테스트 먼저 작성 → 구현 → 테스트 통과 확인
3. 빌드 통과 확인
4. 변경된 파일 목록과 요약을 출력

## 하지 않을 일
- 소유 범위 밖 파일 수정 금지
- git commit 금지 (메인 세션이 커밋함)
- 불필요한 리팩토링 금지
```

### 에이전트 옵션

| 규모 | isolation | run_in_background | model |
|------|-----------|-------------------|-------|
| S 단독 | 없음 | `false` (결과 즉시 수신) | 기본 |
| M 단독 | 없음 | `false` | 기본 |
| L 팀 (구현) | `"worktree"` | `true` | 기본 |
| test-engineer | 없음 | `false` | 기본 |
| design-reviewer | 없음 | `true` (qa-reviewer와 병렬) | 기본 |
| security-auditor | 없음 | `true` (qa-reviewer와 병렬) | 기본 |
| QA 리뷰 | 없음 | `false` | 기본 |
| docs-keeper | 없음 | `true` | `sonnet` |

---

## Step D: 검수 — 테스트 보강 + 보안 감사 + QA + 게이트

### D-0. 테스트 보강 (M/L 규모)

구현 에이전트 완료 후, `wj:test-engineer`에게 테스트 보강 위임:
- 커버리지 갭 분석 + 엣지케이스 도출 + 누락 테스트 작성
- 구현 코드는 수정하지 않음 (테스트 파일만)
- 완료 후 D-1 QA 리뷰로 진행

### D-1. 디자인 리뷰 + 보안 감사 + QA 리뷰 (M/L 규모)

test-engineer 완료 후, 최대 3개 리뷰 에이전트를 **병렬 실행**:

**design-reviewer** (UI 관련 변경 시):
- `.tsx`, `.jsx`, `.vue`, `.svelte`, `.css`, `.scss` 파일 변경이 있을 때 투입
- DESIGN_QUALITY_STANDARDS.md + ANTI_SLOP_PATTERNS.md 기준 검증
- PASS/WARN/FAIL 판정

**security-auditor** (보안 관련 변경 시):
- 인증/API/입력처리/DB 쿼리 관련 파일 변경이 있을 때 투입
- PASS/WARN/FAIL 판정 (CRITICAL 발견 시 FAIL)

**qa-reviewer** (항상):

에이전트 구현 완료 후, `wj:qa-reviewer`에게 리뷰 위임:

```
[qa-reviewer] task={task-id} 리뷰를 수행해줘.

## 변경 파일
{구현 에이전트가 보고한 변경 파일 목록}

## 수락 조건
{acceptance_criteria}

## 검증 항목
1. 컨벤션 (네이밍, SRP, 크기 제한, 타입 안전성)
2. Acceptance Criteria 충족 여부
3. 빌드 + 테스트 통과
4. 회귀 없음 확인

판정: PASS 또는 FAIL + 이유
```

- **PASS** → Step E 커밋으로 진행
- **FAIL** → 해당 구현 에이전트에게 수정 재위임 (최대 2회 재위임, 총 3회 실패 시 루프 중단)
  - FAIL 원인이 컨벤션 위반 또는 반복 패턴이면 `/wj:learn` 호출하여 규칙에 반영

### D-2. 게이트 (Stop hook 자동)

Stop hook(`stop-loop.sh`)이 매 턴 종료 시 자동 실행:
- L1: 정적 감사 (lint/문법)
- L2: tsc 타입체크 (TS 파일 변경 시)
- L3: targeted test (task 관련 테스트)

---

## Step E: Task 완료 커밋

게이트 통과 + (M/L이면 QA PASS) 확인 후:

### E-1. tasks.json 업데이트

`.dev/tasks.json`에서 해당 task의 `status`를 `"done"`으로 변경.

### E-2. 자동 커밋

메인 세션이 직접 커밋 수행 (에이전트가 아님):

1. `git add` — 변경된 파일만 (`.dev/`는 제외 가능)
2. 커밋 메시지 — `/wj:commit` 스킬 규칙 적용:
   ```
   feat(task-id): 한글 요약 — 사용자 가치 명시
   ```
3. 커밋 실행

### E-3. docs-keeper 투입

다음 중 하나 이상이면 **필수 투입**:
- 새 공개 파일 3개+ 생성 또는 공개 API 시그니처 변경
- 아키텍처/디렉토리 구조 변경

다음이면 **생략 가능**:
- 기존 파일 내부 수정만 (구조 불변)
- 테스트 파일만 추가/수정

```
Agent(wj:docs-keeper, run_in_background: true, model: "sonnet")
→ 문서 동기화 + progress.md 기록
```

### E-4. 학습 피드백

Step D에서 QA FAIL이 발생했었으면, FAIL 원인을 분석하여 `/wj:learn` 호출:
- 컨벤션 위반 → devrule에 규칙 추가
- 반복 패턴 → references에 안티패턴 기록
- 프레임워크 특이사항 → TROUBLESHOOTING.md에 추가

### E-5. 다음 task 전진

Stop hook이 task `"done"` 감지 → 다음 eligible task 자동 선택 → Step A부터 반복.

---

## 전체 루프 흐름 요약

```
/wj:loop plan
  │  요구사항 분석 → PRD + tasks.json + specs 생성
  ▼
/wj:loop start
  │
  ▼
┌─────────────────────────────────────────┐
│ Step A: Task 분석 (메인 세션)             │
│   spec 읽기 + criteria 파악 + 스택 확인    │
├─────────────────────────────────────────┤
│ Step B: 규모·유형 판정                    │
│   S/M/L × frontend/backend/engine/...    │
├─────────────────────────────────────────┤
│ Step C: 에이전트 위임                     │
│   S/M → 단독 Agent                       │
│   L   → 팀 Agent (worktree + 병렬)       │
├─────────────────────────────────────────┤
│ Step D: 검수                             │
│   QA 리뷰 (M/L) + 게이트 (자동)           │
│   FAIL → 재위임 (최대 2회) + learn 호출    │
├─────────────────────────────────────────┤
│ Step E: 커밋 + 다음 task                  │
│   tasks.json done → git commit → 전진     │
│   docs-keeper (구조 변경 시 필수)           │
│   learn (QA FAIL 발생 시 교훈 축적)         │
└─────────────────────────────────────────┘
  │
  ▼ (Stop hook → 다음 eligible task → Step A)
```

---

## 하지 않을 일

- ❌ 메인 세션이 직접 코드 작성/수정
- ❌ 에이전트 없이 구현 진행
- ❌ 커밋 없이 다음 task 전진
- ❌ QA 생략 후 L 규모 task 커밋
- ❌ 같은 파일을 복수 에이전트에게 동시 위임

## ⚡ 즉시 실행
