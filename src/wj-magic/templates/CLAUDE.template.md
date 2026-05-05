# {프로젝트 이름}

> 이 파일은 ~100줄 이내 프로젝트 지도. 상세는 docs/와 .claude/rules/를 참조.

## MCP 필수 사용 규칙 (HARD RULE — 위반 시 품질 결함)

코드를 탐색·분석·수정할 때 아래 도구를 **반드시** 사용한다. 추측 기반 작업은 2차 버그를 만든다.

### Serena MCP (심볼 추적) — 코드 수정 전 필수
- `find_symbol` — 심볼 위치 탐색
- `find_referencing_symbols` — 해당 심볼을 참조하는 모든 곳
- `find_declaration` / `find_implementations` — 선언부·구현체 찾기

**사용 시점**: Edit/Write로 코드를 수정하기 **전에** 반드시 Serena로 참조 관계를 확인한다.

### Context7 MCP (라이브러리 문서) — 외부 API 사용 시 필수
- `resolve-library-id` → `query-docs` 순서로 호출

**사용 시점**: 라이브러리 API 호출 코드를 작성하거나 에러를 디버깅할 때.

### 금지 사항
- Serena/Grep 증거 없이 "이 파일인 것 같다"고 추측하여 수정 금지
- 라이브러리 API를 기억에 의존하여 작성 금지 (Context7로 현재 문서 확인 필수)

---

## 개요
- 한 줄 설명:
- 기술 스택:
- 패키지 매니저:

## 구조
- `src/` — 비즈니스 로직
- `docs/` — 사람이 관리하는 문서 (PRD, specs, ADR)
- `.dev/` — AI 작업 흔적 (tasks.json, journal, learnings)
- `tests/` — 테스트

## 규칙 포인팅
- 코딩 표준: `.claude/rules/` 참조
- 비즈니스 룰: `docs/` 참조

## 빠른 참조
- 빌드: `npm run build`
- 테스트: `npm test`
- 린트: `npm run lint`
