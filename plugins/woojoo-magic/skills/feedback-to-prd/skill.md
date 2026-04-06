---
name: feedback-to-prd
description: .feedback/ 폴더의 피드백 JSON과 스크린샷을 읽고 prd.md + tests.json에 task로 변환. 트리거 - 피드백 정리해줘, 피드백 추가해줘, 피드백 변환, feedback to prd, 피드백 처리, 피드백 등록, 피드백 반영
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

# 피드백 → PRD/tests.json 변환

`.feedback/` 폴더의 미처리 피드백(status: "open")을 읽어 prd.md와 tests.json에 task로 추가한다.

## 워크플로우

### 1. 미처리 피드백 수집

```
Glob: .feedback/fb-*.json
각 JSON Read → status가 "open"인 것만 수집
```

### 2. 스크린샷 분석

각 피드백의 `screenshotPath`로 PNG를 **Read 도구로 시각 확인** (Claude는 이미지를 볼 수 있다).
- 어떤 UI 문제가 보이는지
- 어떤 화면/컴포넌트인지
- description과 일치하는지

### 3. task ID 채번

prd.md `### Feedback QA` 섹션에서 기존 번호 확인 후 다음 번호:
- `"bug"` → `fb-bug-{N}`
- `"ux"` → `fb-ux-{N}`
- `"feature"` → `fb-feat-{N}`

### 4. prd.md에 추가

`### Feedback QA` 섹션 마지막 항목 아래에 Edit:
```
- [ ] fb-{sev}-{N}: {스크린샷 분석 반영한 한줄 설명}
```

### 5. tests.json에 추가 (QA Grade)

`features` 배열 마지막에 새 항목. **init-prd 스킬의 QA 기준을 동일 적용**:

```json
{
  "id": "fb-bug-006",
  "category": "Feedback/Bug",
  "description": "피드백 원문 description",
  "status": "failing",
  "priority": 70,
  "depends_on": [],
  "test_command": "pnpm --filter {package} test -- --grep '{pattern}'",
  "acceptance_criteria": [
    "Given-When-Then 형식의 구체적 조건 (최소 3개)"
  ],
  "test_scenarios": [
    {
      "name": "시나리오명",
      "type": "unit|integration|e2e|visual",
      "setup": "초기 상태",
      "action": "트리거 액션",
      "assert": ["검증 조건 1", "검증 조건 2"]
    }
  ],
  "affected_packages": ["client"],
  "affected_files": ["변경 대상 파일 경로"],
  "spec": "specs/fb-bug-006.md",
  "edge_cases": ["엣지 케이스 최소 3개"],
  "regression_check": ["기존 기능 보호 항목 최소 2개"],
  "notes": "피드백: .feedback/fb-XXXX.json, 스크린샷: .feedback/fb-XXXX-screenshot.png"
}
```

**severity별 매핑:**

| severity | category | priority |
|----------|----------|----------|
| bug | Feedback/Bug | 70 |
| ux | Feedback/UX | 60 |
| feature | Feedback/Feature | 50 |

**affected_packages 판단:**
- route `/play/` → `["client"]`
- route `/room/` → `["client", "server"]`
- 그 외 → `["client"]`

**acceptance_criteria 금지 패턴:**
```
❌ "에러가 표시되지 않음"
❌ "정상 반영됨"
❌ "UI가 깨지지 않음"
```

**acceptance_criteria 필수 패턴 (Given-When-Then):**
```
✅ "6인 테이블에서 이모티콘 피커 열기 시, 버튼 4열 grid가 컨테이너 내부에 수렴하고 overflow-x가 발생하지 않는다"
✅ "대기실에서 방장이 준비완료 클릭 시, roomStore.readyUp()이 호출되고 서버에 READY 메시지가 전송된다"
```

**notes**: JSON 경로 + 스크린샷 경로 **반드시** 둘 다 포함.

### 6. 테스트 파일 작성

각 피드백 task에 대해 **실제 런타임 동작을 검증하는 테스트**를 작성한다.

**테스트 위치**: 수정 대상 파일과 같은 패키지의 `__tests__/` 또는 파일 옆 `.test.ts`

**절대 하지 말 것 (가짜 테스트 금지)**:
```typescript
// ❌ 소스 파일을 readFileSync로 읽어서 문자열 존재 여부만 확인
const source = readFileSync('some-file.tsx', 'utf-8');
expect(source).toContain('overflow-hidden');
```
이런 테스트는 리팩토링하면 깨지고 실제 버그를 잡지 못한다. 절대 작성 금지.

**올바른 테스트 패턴**:

Bug (UI): 컴포넌트를 실제로 렌더하거나, 문제가 되는 로직 함수를 직접 호출하여 출력을 검증
```typescript
// ✅ 실제 로직 호출 + 결과 검증
it('좌석 배정 시 human은 SEAT #5에 고정된다', () => {
  const result = assignSeats(players, humanPlayerId);
  expect(result.seatMap[humanPlayerId]).toBe(5);
});
```

Bug (서버): API 핸들러나 세션 메서드를 직접 호출하여 응답 검증
```typescript
// ✅ 서버 메서드 직접 호출 + 상태 검증
it('startSession 후 status는 playing이다', () => {
  const session = new TrainingSession(config);
  const result = session.startSession();
  expect(session.getStatus()).toBe('playing');
  expect(result.gameState).toBeDefined();
});
```

UX/Feature: 상태 변화나 데이터 흐름을 검증
```typescript
// ✅ 상태 흐름 검증
it('에러 발생 시 status가 error로 전환된다', () => {
  // ... 에러 유발 ...
  expect(store.getState().status).toBe('error');
});
```

**테스트 작성 규칙** (.claude/rules/tests.md 준수):
- Vitest 2 사용
- describe: 테스트 대상 함수/컴포넌트 이름
- it: "should [동작]" 또는 한글 "~해야 한다"
- AAA 패턴: Arrange → Act → Assert
- 한 테스트에 assert 하나 (관련된 건 예외)
- `any` 타입 금지

**test_command**: tests.json에 해당 테스트를 실행하는 명령어 기입
```json
"test_command": "pnpm --filter server test -- --grep 'assignSeats'"
```

### 7. specs/ 상세 기획 파일 생성

각 피드백 task에 대해 `specs/{task-id}.md` 파일을 생성한다:

```markdown
# {task-id}: {title}

## 배경
피드백 원문 + 스크린샷 분석 결과.

## 설계
- 문제 원인 분석
- 수정 방향

## 구현 가이드
- 수정할 로직/컴포넌트
- 사용할 패턴

## UI/UX (해당 시)
- 현재 상태 vs 기대 상태

## 의존성
- 관련 피드백 또는 선행 task
```

### 8. 피드백 status 업데이트

JSON의 `"status": "open"` → `"done"`으로 Edit.

### 9. tests.json summary 업데이트

`summary.total` + `summary.failing` 카운트 증가.

### 10. 결과 보고

```
피드백 {N}건 처리:
- fb-bug-006: {설명}
- fb-feat-005: {설명}
prd.md + tests.json 업데이트 완료
```

## RALF 루프 완료 시 피드백 파일 정리

RALF 루프가 피드백 task(`fb-*`)를 구현 완료하면 (`prd.md` `[x]` + `tests.json` `"passing"`):
- `.feedback/` 내 해당 JSON 파일과 스크린샷 PNG 파일을 삭제한다
- `tests.json` 항목의 `notes` 필드에서 원본 파일 경로를 확인하여 삭제
- 예: `notes: "피드백: .feedback/fb-1234.json, 스크린샷: .feedback/fb-1234-screenshot.png"` → 두 파일 삭제
- 삭제된 파일은 커밋에 포함 (git rm)

## 주의

- **스크린샷을 반드시 Read로 시각 확인** — description만으로 판단 금지
- tests.json `notes`에 스크린샷 경로 **필수** 포함
- `"done"` 피드백은 건너뜀
- 기존 task와 중복이면 추가하지 않음
