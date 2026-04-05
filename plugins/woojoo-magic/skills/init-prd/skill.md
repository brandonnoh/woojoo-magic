---
name: init-prd
description: prd.md + tests.json 초기 생성 또는 전면 재작성. 기획 문서, 요구사항, 아이디어를 RALF 루프용 task 목록으로 변환. 전문 QA 수준의 acceptance criteria 작성. 트리거 - PRD 만들어줘, tests.json 생성, 태스크 정의, task 목록 만들어, RALF 준비, 태스크 분해, 기능 정의, backlog 생성, prd 초기화, prd 재작성
---

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (PlayerId, ChipAmount 등) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
- Result<T,E> 패턴으로 에러 처리 — `../../shared-references/RESULT_PATTERN.md`
- Discriminated Union으로 상태 모델링 — `../../shared-references/DISCRIMINATED_UNION.md`
- 같은 패턴 2곳 이상 → 공통 유틸 추출
- CSS animation > JS animation (성능)
- Silent catch 금지

### MCP 필수 사용
- **serena**: 코드 탐색/수정 (symbolic tools)
- **context7**: 라이브러리 API 문서 조회
- **sequential-thinking**: 복잡한 리팩토링 계획

### 리팩토링 방지 시그널
파일 작성 중 다음 징후가 보이면 즉시 분할:
- 파일 200줄 돌파 → 300줄 넘기 전에 SRP 기준 분리
- 함수가 3가지 이상 책임 → 분해
- 같은 패턴 2곳 반복 → 공통 유틸
- Props 5개 초과 → 객체 그룹핑

**상세: `../../shared-references/REFACTORING_PREVENTION.md`**

# PRD + tests.json Generator

RALF 루프(`ralf.sh`) 입력 파일 `prd.md` + `tests.json` 생성.

## Input Sources (우선순위)

1. 사용자 제공 요구사항/기능 목록
2. `docs/` 기획 문서
3. `.feedback/` 피드백 파일
4. 현재 코드 갭 분석 (Serena)

## prd.md Format

```markdown
# {프로젝트명} PRD — 자율 개발 태스크

## 참조 문서
- CLAUDE.md: 코딩 규칙
- LESSONS.md: 이전 실수
- ARCHITECTURE.md: 시스템 구조
- tests.json: 상세 기능 정의

## Tasks

### {Category}
- [ ] {id}: {한줄 설명}
```

### ID Convention
- `{category}-{3자리}` (예: `engine-001`, `ui-012`)
- category: `engine`, `ui`, `ux`, `server`, `ws`, `auth`, `db`, `deploy`, `test`, `docs`, `perf`, `security`

---

## tests.json Format

```json
{
  "summary": {
    "total": 0,
    "passing": 0,
    "failing": 0,
    "last_updated": "YYYY-MM-DD"
  },
  "features": [
    {
      "id": "engine-001",
      "category": "Engine/Rules",
      "description": "한줄 설명",
      "status": "failing",
      "priority": 1,
      "depends_on": [],
      "test_command": "pnpm --filter {package} test -- --grep '{test-pattern}'",
      "acceptance_criteria": [],
      "test_scenarios": [],
      "affected_packages": ["shared"],
      "affected_files": [],
      "edge_cases": [],
      "regression_check": [],
      "notes": "",
      "summary": ""
    }
  ]
}
```

---

## acceptance_criteria 작성 규칙 (QA Grade)

### 금지 패턴 (이렇게 쓰면 REJECT)

```
❌ "기능이 동작함"
❌ "UI가 정상 표시됨"
❌ "에러 없이 처리됨"
❌ "기존 동작이 유지됨"
❌ "~가 존재함"
❌ "~가 올바르게 작동함"
```

### 필수 패턴 (Given-When-Then 형식)

각 criterion은 반드시 **검증 가능한 구체적 조건**으로 작성:

```
✅ "6인 테이블에서 3명 올인 시 메인팟 + 2개 사이드팟이 생성되고, 각 팟의 eligible 플레이어가 올인 금액 기준으로 정확히 분리된다"
✅ "stepCreateAndAssign 호출 후 openingStep === 'seated'이고, openingPlayers 배열 길이가 config.numAI + 1(human)과 일치한다"
✅ "BB 포지션 플레이어가 프리플랍에서 모든 플레이어 콜 시 옵션(check/raise) 선택권을 가진다"
✅ "WebSocket 연결 끊김 후 5초 내 재접속 시 gameState snapshot이 복원되고, 현재 턴이 올바른 플레이어를 가리킨다"
```

### Criterion 구조 (각 항목에 포함)

| 요소 | 필수 | 설명 |
|------|------|------|
| **상태 전제** | ✅ | 어떤 상태에서 시작하는지 (Given) |
| **트리거** | ✅ | 어떤 행위/이벤트가 발생하는지 (When) |
| **검증 조건** | ✅ | 어떤 결과가 되어야 하는지 (Then) |
| **수치/경계값** | 해당 시 | 정확한 숫자, 범위, 타임아웃 |
| **영향 범위** | 해당 시 | 다른 컴포넌트/상태에 미치는 영향 |

---

## test_scenarios 작성 규칙 (NEW)

`acceptance_criteria`는 "무엇을 검증하는가"이고, `test_scenarios`는 "어떻게 테스트하는가":

```json
"test_scenarios": [
  {
    "name": "올인 3명 사이드팟 분배",
    "type": "unit",
    "setup": "3명 플레이어, 칩: [100, 300, 500], 전원 올인",
    "action": "determineShowdownWinners() 호출",
    "assert": [
      "mainPot.amount === 300 (100 * 3)",
      "sidePots[0].amount === 400 (200 * 2)",
      "sidePots[1].amount === 200 (200 * 1)",
      "mainPot.eligiblePlayerIds.length === 3",
      "sidePots[0].eligiblePlayerIds에 100칩 플레이어 미포함"
    ]
  },
  {
    "name": "딜러 드로우 후 SB/BB 포지션 정확성",
    "type": "integration",
    "setup": "6인 테이블, 서버 세션 생성 완료",
    "action": "POST /draw-dealer → POST /resolve-positions",
    "assert": [
      "dealerPlayerId가 draws 중 최고 카드 소유자",
      "sbPlayerId === dealer 다음 활성 플레이어",
      "bbPlayerId === sb 다음 활성 플레이어",
      "3인 이하 시 dealer === sb (heads-up rule)"
    ]
  }
]
```

### Scenario Types

| type | 설명 | test_command 패턴 |
|------|------|-------------------|
| `unit` | 순수 함수 단위 | `pnpm --filter shared test -- --grep '{pattern}'` |
| `integration` | API 엔드포인트 / 스토어 액션 | `pnpm --filter server test -- --grep '{pattern}'` |
| `e2e` | 브라우저 전체 플로우 | `pnpm --filter client test -- --grep '{pattern}'` |
| `visual` | UI 렌더링 / 레이아웃 | 스크린샷 비교 또는 수동 검증 |
| `stress` | 동시성 / 대량 데이터 | 커스텀 스크립트 |

---

## edge_cases 작성 규칙 (NEW)

각 feature에 대해 반드시 edge case 목록 작성:

```json
"edge_cases": [
  "플레이어 2명만 남은 상태에서 올인 (heads-up all-in)",
  "모든 플레이어가 동시에 올인 (칩 전부 동일)",
  "빅블라인드보다 적은 칩으로 올인 (short stack)",
  "딜러가 fold한 후 포지션 로테이션"
]
```

### Edge Case 카테고리 (반드시 검토)

| 카테고리 | 검토 항목 |
|----------|-----------|
| **경계값** | 0, 1, max, max+1, 음수 |
| **빈 상태** | 빈 배열, null, undefined, 빈 문자열 |
| **동시성** | 동시 요청, 중복 클릭, 레이스 컨디션 |
| **연결** | 끊김, 타임아웃, 재접속 |
| **권한** | 비인가 요청, 만료된 토큰 |
| **순서** | 역순 실행, 단계 스킵, 중복 실행 |
| **상태 전이** | 잘못된 상태에서의 액션 (fold 후 raise 시도 등) |

---

## regression_check 작성 규칙 (NEW)

이 feature가 기존 기능을 깨뜨리지 않는지 확인할 항목:

```json
"regression_check": [
  "기존 2인 게임 베팅 플로우 정상 작동",
  "프렌드 모드 WebSocket 재접속 영향 없음",
  "shared 엔진 기존 434개 테스트 전체 통과"
]
```

---

## affected_files 작성 규칙 (NEW)

변경 대상 파일을 사전에 특정:

```json
"affected_files": [
  "shared/src/engine/game.ts",
  "shared/src/types/game.ts",
  "client/src/components/game/PotDisplay.tsx",
  "server/src/training/TrainingSession.ts"
]
```

---

## Field Reference

| 필드 | 타입 | 필수 | 규칙 |
|------|------|------|------|
| `id` | string | ✅ | prd.md task ID와 1:1 |
| `category` | string | ✅ | 카테고리명 |
| `description` | string | ✅ | 한줄 설명 |
| `status` | enum | ✅ | `"failing"` / `"passing"` |
| `priority` | 1-5 | ✅ | 1=최고 |
| `depends_on` | string[] | ✅ | 선행 feature ID (없으면 `[]`) |
| `test_command` | string | ✅ | 테스트 실행 명령어 (`--grep` 패턴 포함) |
| `acceptance_criteria` | string[] | ✅ | Given-When-Then 형식, 최소 3개 |
| `test_scenarios` | object[] | ✅ | setup → action → assert 구조, 최소 2개 |
| `affected_packages` | string[] | ✅ | `["client"]`, `["server"]`, `["shared"]` 등 |
| `affected_files` | string[] | ✅ | 변경 대상 파일 경로 |
| `edge_cases` | string[] | ✅ | 엣지 케이스 최소 3개 |
| `regression_check` | string[] | ✅ | 회귀 체크 항목 최소 2개 |
| `notes` | string | ○ | 구현 메모 |
| `summary` | string | ○ | 완료 후 요약 |

---

## Procedure

1. 입력 소스 수집
2. Serena로 코드 구조 + 기존 테스트 파악
3. Task 분해 (1 task = 1 구현 단위)
4. **각 task별 acceptance_criteria 작성** (Given-When-Then, 최소 3개)
5. **각 task별 test_scenarios 작성** (setup-action-assert, 최소 2개)
6. **각 task별 edge_cases 도출** (경계값, 빈 상태, 동시성 등 최소 3개)
7. **각 task별 regression_check 정의** (기존 기능 보호 최소 2개)
8. **affected_files 특정** (Serena로 실제 파일 경로 확인)
9. 의존성 그래프 (`depends_on`) + priority 할당
10. `prd.md` 생성
11. `tests.json` 생성 (1:1 매칭 검증)
12. summary 계산

## Guardrails

- prd.md ↔ tests.json 1:1 매칭 필수
- acceptance_criteria에 "~됨", "~존재함", "~동작함" 단독 사용 금지
- test_scenarios 없는 feature 생성 금지
- edge_cases 없는 feature 생성 금지
- depends_on 순환 참조 금지
- affected_files에 존재하지 않는 파일 경로 금지 (Serena로 검증)
- 기존 prd.md/tests.json 존재 시 사용자 확인 후 처리
