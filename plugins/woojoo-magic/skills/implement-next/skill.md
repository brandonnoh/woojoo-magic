---
name: implement-next
description: tests.json에서 다음 eligible 기능을 선택하여 TDD로 구현
triggers:
  - "다음 기능"
  - "implement next"
  - "다음 작업"
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

# implement-next 스킬

tests.json 파일을 읽고 다음 규칙에 따라 구현할 기능을 선택하세요:

## 기능 선택 규칙
1. `status`가 `"failing"`인 기능만 대상
2. `depends_on`에 있는 모든 기능이 `"passing"`이어야 함 (또는 `depends_on`이 비어있음)
3. 위 조건을 만족하는 것 중 `priority`가 가장 낮은(= 가장 높은 우선순위) 것을 선택

## 구현 워크플로우

### 1. 맥락 파악
- `CLAUDE.md` 읽기 (코딩 규칙, MCP/스킬 필수 사용)
- `LESSONS.md` 읽기 (이전 실수 확인)
- `ARCHITECTURE.md` 읽기 (시스템 구조)
- 선택한 기능의 **전체 필드** 확인:
  - `acceptance_criteria` — Given-When-Then 검증 조건
  - `test_scenarios` — setup → action → assert 구조
  - `edge_cases` — 경계값, 동시성, 빈 상태 등
  - `regression_check` — 기존 기능 보호 항목
  - `affected_files` — 변경 대상 파일 (Serena로 검증)
- `affected_packages`의 관련 코드를 **Serena symbolic tools**로 탐색
- 라이브러리 API는 **Context7**로 최신 문서 조회

### 2. TDD 구현 (test_scenarios 기반)
- `test_scenarios`의 각 시나리오를 **Vitest 테스트로 변환**
- `edge_cases` 항목도 테스트에 포함
- 테스트가 실패하는지 확인 (Red)
- 테스트를 통과하는 **구현 코드 작성** (Green)
- `regression_check` 항목 검증 (기존 테스트 전체 통과 확인)
- 필요하면 리팩토링 (Refactor)

### 3. 검증
```bash
pnpm turbo build && pnpm turbo test
```
- shared 변경 시: `pnpm --filter shared build && pnpm --filter shared test`
- 타입 체크: `pnpm turbo typecheck`

### 4. 완료 처리
통과하면:
1. `tests.json` **전체** 파일을 Read 도구로 읽는다
2. `features` 배열에서 해당 기능의 `status`를 `"passing"`으로 변경
3. `summary`의 `passing`/`pending`/`failing` 카운트 재계산
4. **원본 배열 구조를 유지한 채** 전체 파일을 Write
5. ⛔ 단일 task 객체만 Write 금지 — features 배열이 1개로 파괴되는 사고 발생 이력 있음
6. `prd.md`에서 해당 task를 `[x]`로 체크
4. **커밋 (`commit` 스킬 규칙 필수 준수)**:
   - 형식: `type(scope): 한글 설명 (사용자 가치 포함)`
   - type: `feat`/`fix`/`game`/`ws`/`ui`/`ux`/`refactor`/`test`/`perf`/`chore`/`docs`
   - scope: task ID (예: `engine-001`)
   - 예시: `feat(engine-001): BET/RAISE 내부 이벤트 분리로 베팅 추적 정확도 향상`
   - 마침표 금지, 콜론 뒤 공백 필수
   - `git add` 시 변경된 파일만 명시적 추가 (`git add -A` 지양)

### 5. 실패 처리
- 3번 이상 같은 방식으로 실패하면 `LESSONS.md`에 교훈 기록
- 다른 접근법으로 재시도
- 해결 불가 시 `progress.md`에 시도 내용과 에러 기록 후 다음 기능으로 이동
