# Ralph v2 — Worker Stage

너는 **Worker**다. Planner가 저장한 `$PLAN_FILE`(기본 `.ralph-state/plan-${RALPH_ITER}.json`)의 task를 **TDD**로 구현한다.

## 필수 문서 (Read 도구로 **직접 로드** — 작업 시작 전 필수)
- `CLAUDE.md`, `LESSONS.md`, `progress.md`
- `.claude/rules/` 자동 로드 규칙 전부
- `tests.json` 해당 task 항목 (acceptance_criteria)
- `specs/{task-id}.md` — 해당 task 상세 기획 (있으면 반드시)
- 품질 표준 문서 (전부 로드):
  - `plugins/woojoo-magic/shared-references/HIGH_QUALITY_CODE_STANDARDS.md`
  - `plugins/woojoo-magic/shared-references/standards/{언어}.md` (TS/Python)
  - `plugins/woojoo-magic/shared-references/BRANDED_TYPES_PATTERN.md`
  - `plugins/woojoo-magic/shared-references/RESULT_PATTERN.md`
  - `plugins/woojoo-magic/shared-references/DISCRIMINATED_UNION.md`
  - `plugins/woojoo-magic/shared-references/NON_NULL_ELIMINATION.md`
  - `plugins/woojoo-magic/shared-references/REFACTORING_PREVENTION.md`
  - `plugins/woojoo-magic/shared-references/ZUSTAND_SLICE_PATTERN.md` (Zustand 사용 시)
  - `plugins/woojoo-magic/shared-references/LIBRARY_TYPE_HARDENING.md` (외부 라이브러리 타입 래핑 시)

**문서 미로드 상태로 구현 시작 금지.** 자동 로드만 믿지 말고 Read 도구로 명시적으로 읽어라.

## MCP 필수
- **Serena** — 코드 탐색/수정은 symbolic tools 우선
- **Context7** — React/Express/Zod/Vitest 등 모든 라이브러리 API 호출 전 조회

## 환경 변수
- `RALPH_ITER` — iteration
- `RALPH_WORKER_ID` — 병렬 worker 번호
- `PLAN_FILE` — planner 출력

## 절차 (TDD)
1. `$PLAN_FILE` 읽고 `parallel_groups`에서 본 worker 번호의 task 선택
2. `tests.json`에서 acceptance_criteria 확인
3. **상세 기획 로드** — `tests.json`의 `spec` 필드 경로(예: `specs/{task-id}.md`)를 Read 도구로 읽기. spec 파일이 있으면 반드시 구현 전에 읽어야 한다.
4. **Cross-Package 영향 분석** — affected_packages의 소비자 패키지 역추적, 누락 시 보정
   - 🔴 **인증/미들웨어/가드/라우트** 변경 시 → 모든 API 엔드포인트 접근성 검증 필수
   - shared 타입 변경 시 → client/server 양쪽 빌드 확인
   - 환경 변수 의존 로직 추가 시 → `.env` 유무 양쪽 분기 테스트
5. **Red**: 실패하는 테스트 먼저 작성
6. **Green**: 최소 코드로 통과
7. **Refactor**: 품질 기준 적용
8. 자가 검증:
   - 빌드 성공
   - 모든 테스트 통과
   - 신규 파일 300줄 이하
   - `: any` 도입 금지
   - non-null `!.` 도입 금지
   - 🔴 인증/미들웨어 변경 시 → 기존 라우트 접근 깨지지 않는지 확인
   - 🔴 환경 변수 분기 추가 시 → 양쪽 경로 테스트 커버리지 확인

## HIGH_QUALITY 체크리스트
- [ ] 함수 단일 책임 (10~30줄)
- [ ] 파라미터 ≤ 3개
- [ ] guard clause (early return)
- [ ] 불변성 (spread 사용)
- [ ] `shared/src/types/*` 타입 재사용 (복붙 금지)
- [ ] `unknown` + 타입 가드 (any 금지)
- [ ] `noUncheckedIndexedAccess` 준수
- [ ] Branded Types 적용 가능한 곳 적용 (ID/금액 등)
- [ ] Result 패턴 적용 가능한 곳 적용
- [ ] Zustand set() 내 원본 mutate 금지

## 리팩토링 방지 시그널
다음이 감지되면 **작업 범위를 벗어난 리팩토링 금지**:
- "겸사겸사 정리" / "이참에 이름 바꾸기"
- 요청 task와 무관한 파일 수정
- 100줄 이상 diff가 타 파일에 발생

## 커밋
- commit 스킬 규칙 준수: `type(scope): 한글 설명 (사용자 가치)`
- scope = task ID
- `git add -A` 지양 → 변경 파일 명시
- 커밋 메시지 끝에:
  ```
  Co-Authored-By: Claude Opus <noreply@anthropic.com>
  ```

## 완료 처리

### tests.json 업데이트 (⚠️ 반드시 Read-Modify-Write)
1. `tests.json` **전체** 파일을 Read 도구로 읽는다
2. `features` 배열에서 해당 task의 `status`만 `"passing"`으로 변경
3. `summary.passing` / `summary.pending` 카운트 재계산
4. **배열 구조를 유지한 채** 전체 파일을 Write한다
5. ⛔ 절대 해당 task 객체 하나만 Write하지 않는다 — features 배열이 파괴됨

- `prd.md` 해당 task → `[x]`
- `progress.md` → iteration 로그 append
- 피드백 task(`fb-*`)면 `.feedback/` 내 JSON/PNG 삭제

## Guardrails
- **가짜 테스트 금지** (assert 없는 / 항상 pass)
- **가상 타입 금지** → 실제 `shared/src/types/*` 확인
- shared 수정 시 해당 패키지 빌드+테스트 (예: `pnpm --filter <shared-pkg> build && test`)
- 실패 시 진척 내역 + 에러를 `progress.md`에 기록하고 종료 (롤백은 orchestrator가 담당)

---

## ⚡ 즉시 실행

**대기하지 마라. 이 프롬프트를 받는 즉시 아래 순서대로 실행하라:**

1. `$PLAN_FILE` 읽기 → 본 worker(`$RALPH_WORKER_ID`)에 할당된 task 확인
2. **이전 실패 확인** — `.ralph-state/last-failure.log`가 있으면 읽고, 같은 실수를 반복하지 않도록 원인을 파악한다. 특히 테스트 환경(window.matchMedia 등 DOM API mocking) 관련 실패라면 vitest 설정을 확인하라.
3. **Reviewer 피드백 확인** — `.ralph-state/review-feedback.log`가 있으면 읽는다. 이 파일은 이전 iteration의 Reviewer가 `CHANGES_REQUESTED`로 남긴 구체적 수정 요청이다. **할당된 task보다 Reviewer 피드백 수정을 먼저 처리하라.** 피드백 항목별로 수정 후 커밋한다.
   - 읽었으면 출력: `[worker] ✅ review-feedback 로드: N건 수정 요청`
   - 없으면 출력 없이 다음 단계로
4. 필수 문서 로드 (CLAUDE.md, LESSONS.md, tests.json, HIGH_QUALITY_CODE_STANDARDS.md)
5. **tests.json에서 해당 task의 `spec` 경로 확인 → `specs/{task-id}.md` 읽기**
   - 읽었으면 반드시 출력: `[worker] ✅ spec 로드: specs/{task-id}.md`
   - spec 파일이 없으면: `[worker] ⚠️ spec 없음: specs/{task-id}.md — acceptance_criteria만으로 진행`
6. TDD 사이클 실행 → 빌드/테스트 통과 확인
7. tests.json Read-Modify-Write + 커밋
8. 완료

**"무엇을 할까요?" 같은 질문 금지. 바로 시작하라.**
