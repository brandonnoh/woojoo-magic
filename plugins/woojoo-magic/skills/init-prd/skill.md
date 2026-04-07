---
name: init-prd
description: prd.md + tests.json + specs/ 초기 생성, 전면 재작성, 또는 기존에 부분 추가. 기획 문서, 요구사항, 아이디어를 RALF 루프용 task 목록으로 변환. 전문 QA 수준의 acceptance criteria 작성. 트리거 - PRD 만들어줘, tests.json 생성, 태스크 정의, task 목록 만들어, RALF 준비, 태스크 분해, 기능 정의, backlog 생성, prd 초기화, prd 재작성, 태스크 추가, 기능 추가, task 추가해줘, 새 기능 넣어줘, 이거 task로 만들어줘
---

## 품질 기준 (woojoo-magic 표준)

**반드시 참조: `../../shared-references/HIGH_QUALITY_CODE_STANDARDS.md`**

### 핵심 규칙
- 파일 300줄 / 함수 20줄 / JSX 100줄 / Props 5개 / 클래스 300줄
- `any` 금지, `as` 최소화, `!` 금지 → `unknown` + 타입 가드 + guard clause
- Branded Types 적용 (도메인 식별자 타입 안전화) — `../../shared-references/BRANDED_TYPES_PATTERN.md`
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
      "spec": "specs/engine-001.md",
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
✅ "장바구니에 3개 상품이 담긴 상태에서 쿠폰 적용 시 할인 금액이 총액의 10%로 계산되고, 최소 주문 금액 미달 시 쿠폰이 적용되지 않는다"
✅ "createOrder 호출 후 orderStatus === 'pending'이고, orderItems 배열 길이가 장바구니 상품 수와 일치한다"
✅ "관리자 권한 사용자가 대시보드에서 주문 상태를 'shipped'로 변경 시 구매자에게 알림이 발송된다"
✅ "WebSocket 연결 끊김 후 5초 내 재접속 시 대시보드 상태 snapshot이 복원되고, 실시간 알림 큐가 유실 없이 재전송된다"
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
    "name": "쿠폰 적용 시 할인 금액 계산",
    "type": "unit",
    "setup": "3개 상품, 가격: [10000, 30000, 50000], 10% 할인 쿠폰",
    "action": "applyDiscount(cart, coupon) 호출",
    "assert": [
      "totalBeforeDiscount === 90000",
      "discountAmount === 9000",
      "totalAfterDiscount === 81000",
      "coupon.isApplied === true",
      "최소 주문 금액 미달 시 discountAmount === 0"
    ]
  },
  {
    "name": "주문 생성 후 결제 처리 정확성",
    "type": "integration",
    "setup": "사용자 인증 완료, 장바구니에 상품 3개",
    "action": "POST /orders → POST /payments/process",
    "assert": [
      "order.status === 'pending'",
      "order.items.length === 3",
      "payment.amount === order.totalAmount",
      "재고 부족 시 order.status === 'failed'"
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
  "장바구니에 상품 1개만 있는 상태에서 최소 주문 금액 미달",
  "동일 상품을 수량 999개로 추가 (재고 초과)",
  "결제 도중 세션 만료 시 주문 상태 정합성",
  "동시에 같은 상품에 대해 2건의 주문 요청 (레이스 컨디션)"
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
| **상태 전이** | 잘못된 상태에서의 액션 (결제 완료 후 재결제 시도 등) |

---

## regression_check 작성 규칙 (NEW)

이 feature가 기존 기능을 깨뜨리지 않는지 확인할 항목:

```json
"regression_check": [
  "기존 주문 생성/결제 플로우 정상 작동",
  "실시간 알림 WebSocket 재접속 영향 없음",
  "shared 패키지 기존 테스트 전체 통과"
]
```

---

## affected_files 작성 규칙 (NEW)

변경 대상 파일을 사전에 특정:

```json
"affected_files": [
  "shared/src/services/order.ts",
  "shared/src/types/order.ts",
  "client/src/components/checkout/OrderSummary.tsx",
  "server/src/api/orders.ts"
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
| `spec` | string | ✅ | 상세 기획 문서 경로 (`specs/{id}.md`) |
| `notes` | string | ○ | 구현 메모 |
| `summary` | string | ○ | 완료 후 요약 |

---

## Procedure

### 모드 판별 (자동)

기존 `prd.md` + `tests.json`이 **존재하면 → 추가 모드**, 없으면 → 초기 생성 모드.
사용자가 "재작성", "초기화", "처음부터" 명시하면 초기 생성 모드.

### 초기 생성 모드

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
11. `tests.json` 생성 (1:1 매칭 검증, `spec` 필드에 경로 포함)
12. **`specs/` 디렉토리에 task별 상세 기획 파일 생성** (아래 형식)
13. summary 계산

### 추가 모드 (기존 prd.md + tests.json이 있을 때)

1. 기존 `prd.md` 읽기 → 현재 task ID 목록 파악 (중복 방지)
2. 기존 `tests.json` 읽기 → features 배열 + summary 확인
3. 입력 소스 수집 + Serena로 코드 분석
4. **새 task만** 분해 (기존 ID와 충돌하지 않는 번호 채번)
5. 각 새 task별 acceptance_criteria / test_scenarios / edge_cases / regression_check / affected_files 작성
6. `prd.md`에 해당 Phase/Category 섹션 끝에 **append** (기존 항목 수정 금지)
7. `tests.json`의 `features` 배열 끝에 새 항목 **append** + summary 재계산
8. `specs/{new-task-id}.md` 파일 생성
9. 결과 요약 출력: 추가된 task 수, ID 목록

## specs/{id}.md 형식

각 task마다 `specs/{task-id}.md` 파일을 생성한다. Worker가 구현 전 읽는 상세 기획 문서:

```markdown
# {task-id}: {title}

## 배경
왜 이 기능이 필요한지, 어떤 문제를 해결하는지.

## 설계
- 데이터 흐름 / 상태 변화
- API 엔드포인트 (해당 시)
- 컴포넌트 구조 (UI 해당 시)
- 타입 정의 (새로 추가하거나 수정하는 타입)

## 구현 가이드
- 핵심 로직 설명
- 사용할 패턴 (Result, Branded Types 등)
- 주의사항 / 함정

## UI/UX (해당 시)
- 와이어프레임 또는 레이아웃 설명
- 인터랙션 흐름
- 반응형 고려사항

## 의존성
- 선행 task와의 관계
- 외부 라이브러리 (있으면)
```

## Guardrails

- prd.md ↔ tests.json 1:1 매칭 필수
- acceptance_criteria에 "~됨", "~존재함", "~동작함" 단독 사용 금지
- test_scenarios 없는 feature 생성 금지
- edge_cases 없는 feature 생성 금지
- depends_on 순환 참조 금지
- affected_files에 존재하지 않는 파일 경로 금지 (Serena로 검증)
- 추가 모드에서 기존 task 수정/삭제 금지 — 새 task만 append
- 추가 모드에서 기존 ID와 중복되는 번호 채번 금지
- tests.json의 모든 feature에 `spec` 필드 필수 — `specs/{id}.md` 경로
- specs/ 파일 없는 feature 생성 금지
