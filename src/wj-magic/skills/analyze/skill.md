---
name: analyze
description: >
  코드베이스 맥락 분석 — Serena 심볼 추적 + Context7 문서 조회 + Explore 에이전트로
  수정 대상 파일·함수·의존 관계를 정확히 특정한 뒤 구조화된 분석 리포트를 반환하는 스킬.
  코드를 직접 수정하지 않는다. 수정은 /wj:devrule로 이어간다.
  "분석해줘", "analyze", "관련 코드 찾아줘", "어디 고쳐야 해", "영향 범위",
  "이거 어디서 쓰여", "호출 관계", "의존성 파악", "임팩트 분석", "코드 추적",
  "어디 건드려야 돼", "연관 파일", "레퍼런스 찾아줘", "구조 파악",
  "이 함수 누가 쓰는지", "변경하면 어디 깨져" 요청에 트리거.
---

# /wj:analyze — 코드베이스 맥락 분석

수정 전에 "뭘 건드려야 하는지"를 정확히 파악하는 스킬.
Serena 심볼 추적 + Context7 라이브러리 문서 + Explore 에이전트 3종을 조합해
관련 코드를 빠짐없이 찾고, 수정 임팩트를 구조화된 리포트로 정리한다.

**이 스킬은 코드를 수정하지 않는다.** 분석 결과를 기반으로 `/wj:devrule`로 이어간다.

<HARD-GATE>
"대충 이 파일인 것 같다"는 금지.
Serena 심볼 추적 또는 Grep 증거 없이 파일을 지목하지 않는다.
</HARD-GATE>

---

## Phase 0: 분석 요청 파악 (Claude PM)

### 분석 유형 자동 감지

```
키워드 → 유형 매핑:
"어디 고쳐야|어디 건드려|변경 범위|영향 범위|임팩트" → impact (변경 영향 분석)
"호출 관계|의존성|누가 쓰는지|레퍼런스|참조" → trace (심볼 추적)
"구조|아키텍처|패턴|설계|전체 흐름" → structure (구조 파악)
"라이브러리|API|사용법|문서|마이그레이션" → docs (외부 문서 조회)
그 외 → impact (기본값)
```

### 입력 정보 수집

```
□ 분석 대상 특정 (파일명, 함수명, 기능명, 에러 메시지 등)
□ 분석 유형 결정 (impact / trace / structure / docs / 복합)
□ 프로젝트 언어·프레임워크 감지
```

---

## Phase 1: 3종 병렬 탐색

분석 유형에 따라 아래 도구를 조합한다. **최소 2종 이상 병렬 실행.**

### 1-A: Serena 심볼 추적 (trace / impact 유형 필수)

```javascript
// 1. 심볼 찾기
mcp__serena__find_symbol({ symbolName: "<대상>" })

// 2. 선언부 확인
mcp__serena__find_declaration({ symbolName: "<대상>", file: "<파일>" })

// 3. 참조 추적 — 이 심볼을 사용하는 모든 곳
mcp__serena__find_referencing_symbols({ symbolName: "<대상>", file: "<파일>" })

// 4. 구현체 추적 (인터페이스/추상 클래스인 경우)
mcp__serena__find_implementations({ symbolName: "<대상>", file: "<파일>" })

// 5. 파일 전체 심볼 개요
mcp__serena__get_symbols_overview({ file: "<파일>" })
```

### 1-B: Explore 에이전트 (structure / impact 유형 필수)

```javascript
Agent({
  subagent_type: "Explore",
  run_in_background: true,
  description: "코드베이스 구조 탐색",
  prompt: `
    분석 대상: <대상>
    프로젝트 루트: <경로>

    다음을 조사하라:
    1. 대상과 관련된 모든 파일 (Glob + Grep)
    2. import/export 의존 그래프 (1단계 + 2단계)
    3. 테스트 파일 존재 여부 및 커버리지 범위
    4. 최근 변경 이력 (git log --oneline -10 <관련파일>)

    결과를 파일별로 정리하되, 각 파일이 왜 관련되는지 근거를 명시하라.
    코드를 수정하지 마라.
  `
})
```

### 1-C: Context7 라이브러리 문서 (docs 유형 필수, 기타 유형은 필요 시)

```javascript
// 외부 라이브러리 API가 관련된 경우
mcp__context7__resolve-library-id({ libraryName: "<라이브러리명>" })
mcp__context7__query-docs({ context7CompatibleLibraryID: "<ID>", topic: "<주제>" })
```

### 유형별 도구 조합

| 유형 | Serena | Explore | Context7 | Grep/Glob |
|------|:---:|:---:|:---:|:---:|
| impact | 필수 | 필수 | 선택 | 필수 |
| trace | 필수 | 선택 | 선택 | 보조 |
| structure | 선택 | 필수 | 선택 | 필수 |
| docs | 선택 | 선택 | 필수 | 보조 |

---

## Phase 2: 분석 결과 종합

Phase 1 결과를 수집한 뒤, 아래 구조로 정리한다.

### 출력 포맷: 분석 리포트

```markdown
## 분석 요약

**대상**: <분석 대상>
**유형**: <impact | trace | structure | docs>
**관련 파일**: N개

## 핵심 파일 (수정 필요)

| 파일 | 라인 | 역할 | 근거 |
|------|------|------|------|
| `src/foo.ts` | 42-58 | 대상 함수 선언부 | Serena find_declaration |
| `src/bar.ts` | 15 | 대상 호출부 | Serena find_referencing_symbols |

## 연관 파일 (영향받을 수 있음)

| 파일 | 관계 | 위험도 |
|------|------|--------|
| `src/baz.ts` | 간접 의존 | LOW |
| `tests/foo.test.ts` | 테스트 | 수정 시 업데이트 필요 |

## 의존 그래프

```
<대상> ← bar.ts (호출)
       ← baz.ts (간접, qux 경유)
       → db.ts (의존)
```

## 외부 라이브러리 참고 (해당 시)

- <라이브러리>: <관련 API/패턴> (Context7 출처)

## 수정 가이드

- 예상 규모: S / M / L
- 권장 접근: <구체적 수정 방향>
- 주의사항: <깨질 수 있는 부분>
```

---

## Phase 3: 후속 연결

분석 완료 후 사용자에게 다음 액션을 제안한다:

```
분석 완료. 다음 중 선택하세요:
1. `/wj:devrule` — 분석 결과 기반으로 바로 구현
2. `/wj:plan` — 수정 태스크를 단계별로 분해
3. `/wj:tdd` — 테스트부터 작성 후 구현
4. 추가 분석 — 특정 파일/함수 더 깊이 추적
```

---

## Serena 사용 불가 시 폴백

Serena MCP가 설치되지 않은 환경에서는 아래로 대체한다:

| Serena 기능 | 폴백 |
|------------|------|
| find_symbol | `Grep` (함수명/클래스명 검색) |
| find_declaration | `Grep` (export/def/func/class 패턴) |
| find_referencing_symbols | `Grep` (import + 호출 패턴) |
| find_implementations | `Grep` (implements/extends 패턴) |
| get_symbols_overview | `Grep` + `Read` (파일 상단 export 목록) |

폴백 시에도 **증거 기반 원칙은 동일** — 추측으로 파일을 지목하지 않는다.

---

## 위험 신호

| 위험 신호 | 현실 |
|---------|------|
| "이 파일인 것 같다" | 추측이다. Serena/Grep으로 증명하라 |
| "관련 파일 3개 정도" | 실제로는 더 많을 수 있다. referencing_symbols를 끝까지 추적하라 |
| "테스트는 없는 것 같다" | Glob으로 `*.test.*`, `*.spec.*` 패턴을 반드시 확인하라 |
| "빨리 수정부터 하자" | 분석 없는 수정은 2차 버그를 만든다 |
