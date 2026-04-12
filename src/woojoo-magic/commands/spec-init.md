---
description: 기존 tests.json 기반으로 누락 spec 일괄 생성 + 기존 spec 정합성 검증. 트리거 - spec 생성, spec 보충, spec 검증, specs 만들어줘, spec 없는 것 채워줘
---

# Spec 일괄 생성/검증

tests.json의 features를 순회하여 `specs/{task-id}.md` 파일을 **실제 코드 분석 기반으로** 생성하거나, 기존 spec의 정합성을 검증한다.

**spec은 tests.json의 복붙이 아니다.** Worker가 읽고 바로 구현할 수 있는 수준의 **상세 기획 문서**다.

## MCP 필수
- **Serena** — 관련 파일/심볼 탐색, 현재 코드 구조 분석
- **Context7** — 사용할 라이브러리 API 확인

## 절차

### 1. tests.json 읽기
- tests.json이 없으면 → `⚠️ tests.json이 없습니다. /wj:init-prd를 먼저 실행하세요.` → 종료
- `features[]` 배열 전체를 읽는다

### 2. task별 spec 생성/검증

`features[]`를 순회하며 각 task에 대해:

#### 2-a. `specs/{task-id}.md`가 없으면 → 생성

**반드시 아래 순서를 따른다. tests.json 복붙 금지.**

1. **affected_files/affected_packages 기반 코드 분석** (Serena)
   - `affected_files`의 각 파일을 Serena로 심볼 탐색
   - 해당 파일의 현재 구조, 관련 함수/타입/컴포넌트 파악
   - 버그 수정 task라면: 버그가 있는 정확한 라인 + 현재 로직 설명
   - 신규 기능 task라면: 새 코드가 들어갈 위치 + 기존 코드와의 연결점
2. **구현 방향 구체화**
   - 어떤 파일을 어떻게 변경할지 (Before/After 수준)
   - 새로 만들 파일/함수/타입 이름
   - 사용할 패턴 (Result, Branded Types, DU 등)
   - 의존하는 외부 라이브러리 API (Context7로 확인)
3. **테스트 시나리오 구체화**
   - 단위 테스트 케이스 목록 (파일명 + describe/it 구조)
   - 모킹이 필요한 부분
   - Edge case별 예상 입출력
4. **spec 파일 작성** (아래 템플릿)

#### 2-b. `specs/{task-id}.md`가 있으면 → 검증

- tests.json의 `acceptance_criteria`가 spec에 전부 반영됐는지 대조
- "## 설계" 섹션이 비어있거나 placeholder만 있으면 → 코드 분석 후 채움
- "## 구현 가이드" 섹션에 구체적 파일/함수명이 없으면 → 보충
- 누락 항목 있으면 append

### 3. 결과 요약
```
[spec-init] 생성: N개, 검증OK: M개, 업데이트: K개
```

## Spec 템플릿

```markdown
# {task-id}: {title}

## 배경
왜 이 기능이 필요한지. 현재 코드에서 어떤 부분이 문제/부재인지.

## Acceptance Criteria
- [ ] {acceptance_criteria — tests.json에서 가져옴}

## 현재 코드 분석
- **관련 파일**: {Serena로 탐색한 실제 파일 경로 + 역할}
- **현재 동작**: {기존 로직이 어떻게 작동하는지}
- **문제점/부재**: {버그라면 정확한 라인과 원인, 신규 기능이라면 어디에 추가해야 하는지}

## 설계
- **데이터 흐름**: {입력 → 처리 → 출력 구체적으로}
- **API 변경** (해당 시): 엔드포인트, 요청/응답 형식
- **컴포넌트 구조** (UI 해당 시): 컴포넌트 트리, props
- **타입 정의**: 새로 추가하거나 수정하는 타입 (코드 수준)

## 구현 가이드
- **변경 파일별 상세**:
  - `{파일경로}`: {무엇을 어떻게 변경}
  - `{파일경로}`: {무엇을 어떻게 변경}
- **새로 생성할 파일**: {파일명 + 역할}
- **사용 패턴**: Result / Branded Types / DU 등
- **주의사항**: {함정, 놓치기 쉬운 부분}

## 테스트 계획
- **테스트 파일**: `{경로}/{task-id}.test.ts`
- **케이스**:
  - `describe('{기능}')` → `it('{시나리오}')`: 예상 입출력
  - `describe('{기능}')` → `it('{엣지 케이스}')`: 예상 입출력
- **모킹**: {모킹 필요한 의존성}

## Edge Cases
- {구체적 엣지 케이스 + 예상 동작}

## 회귀 체크
- {이 변경으로 깨질 수 있는 기존 기능 + 확인 방법}

## 의존성
- depends_on: {선행 task}
- affected_packages: {영향 패키지}
```

## Guardrails
- **tests.json 복붙 금지** — acceptance_criteria를 그대로 복사해서 끝내는 것은 spec이 아니다
- **모든 설계/구현 섹션은 Serena 코드 분석 기반** — 추측으로 채우지 마라
- **파일 경로는 실제 존재하는 경로만** — Serena로 검증
- status가 `passing`인 task의 spec도 검증 대상
- task 1개당 spec 작성에 충분한 시간을 써라 — 빠르게 양산하지 말고 정확하게 작성

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 위 절차대로 실행하라.**

**각 spec은 반드시 Serena로 코드를 분석한 후 작성하라. tests.json을 복붙한 spec은 미완료로 간주한다.**
