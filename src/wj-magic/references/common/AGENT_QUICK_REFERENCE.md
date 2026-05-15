# Agent Quick Reference

> 모든 에이전트가 작업 시작 전 Read로 로드하는 단일 진실 공급원.
> 상세 규칙은 `HIGH_QUALITY_CODE_STANDARDS.md` 및 `references/typescript/` 참조.

---

## Hard Limits (파일/함수 크기)

| 언어 | 파일 최대 | 함수 최대 |
|------|----------|----------|
| TypeScript / JavaScript | 300줄 | 20줄 |
| Python | 600줄 | 50줄 |
| Go / Rust | 500줄 | — |
| Swift / Kotlin | 400줄 | — |

**소프트 경고:** 파일이 2/3(TS: 200줄, Python: 400줄)을 넘으면 즉시 분할 계획 수립.

---

## Forbidden Patterns (언어 불문 금지)

| 패턴 | 대안 |
|------|------|
| `any` / `Any` / `unknown` 도피 | `unknown` + 타입 가드 / `TypeGuard` |
| `!.` non-null assertion | guard clause / `?? defaultValue` |
| silent catch (`catch {}` / `except: pass` / `catch (_) {}`) | 최소 로깅 + 에러 체인 보존 |
| 4단 이상 중첩 | 가드 클로즈 + 함수 분리 |
| Cyclomatic Complexity > 10 | 즉시 분할 |
| 전역 가변 상태 | DI 또는 불변 업데이트 패턴 |

---

## Required Patterns (TypeScript)

| 패턴 | 용도 | 레퍼런스 |
|------|------|---------|
| Branded Types | 도메인 식별자 타입 구분 | `references/typescript/BRANDED_TYPES_PATTERN.md` |
| `Result<T, E>` | 실패 명시적 처리, throw 최소화 | `references/typescript/RESULT_PATTERN.md` |
| Discriminated Union + exhaustive switch | 상태 모델링 | `references/typescript/DISCRIMINATED_UNION.md` |

---

## Key Principles

1. **SRP** — 파일/함수/클래스는 한 가지 책임만
2. **타입 안전성** — strict 모드, 경계에서만 검증 후 도메인 타입으로 승격
3. **불변성** — 기본값은 불변, 가변은 명시적 선택
4. **레이어 분리** — domain은 I/O 없는 순수 함수
5. **DRY** — 같은 패턴 2곳 → 추출. 3곳 → 반드시 추출 (리뷰 거부 사유)
6. **검증 전 완료 주장 금지** — 빌드/테스트/린트 통과 확인 후 "완료" 보고

---

## ⛔ MCP 필수 사용 (HARD RULE — 위반 시 품질 결함)

모든 에이전트는 작업 중 아래 MCP 도구를 **반드시** 사용한다. 추측 기반 작업은 2차 버그를 만든다.

### Sequential-thinking — 복잡한 task 시작 시 필수
- 도구: `mcp__sequential-thinking__sequentialthinking`
- 요구사항·제약·의존성을 단계별로 분해
- task의 `acceptance_criteria` 각 항목을 사고 체인에 명시

### Serena — 코드 수정 전 필수
- `find_symbol` — 수정 대상 심볼 위치 확인
- `find_referencing_symbols` — 영향 범위 파악
- `get_symbols_overview` — 파일 구조 조망 (Edit/Write 전)
- `search_for_pattern` — 패턴 기반 탐색
- ⚠️ Serena 증거 없는 수정 시도는 PreToolUse 훅이 차단

### Context7 — 라이브러리 API 사용 시 필수
- 순서: `resolve-library-id` → `query-docs`
- React / Next.js / Tailwind / Prisma 등 모든 외부 라이브러리 API 코드 작성·디버깅 전

### 금지 사항
- ❌ Serena/Grep 증거 없이 "이 파일인 것 같다" 추측 수정
- ❌ 라이브러리 API를 기억에 의존해 작성 (Context7 현재 문서 확인 필수)
- ❌ 함수명·파일명·심볼명을 추측으로 지목

---

## 리팩토링 방지 신호

코드 작성 **중** 아래가 보이면 즉시 멈추고 재설계:

- 파일 200줄+ 돌파 → 300줄 전에 SRP 기준 분리
- 함수가 3가지 이상 책임
- 같은 로직 2곳 반복 → 공통 유틸 추출
- 매개변수 5개 초과 → config 객체로 묶기
- `any` / `!.` 등장 → 타입 설계 재고

→ 상세: `references/common/REFACTORING_PREVENTION.md`

---

## Full Reference

- `references/common/HIGH_QUALITY_CODE_STANDARDS.md` — 전체 품질 기준 + 언어별 상세
- `references/typescript/` — TS 패턴 심화
- `references/design/` — UI/디자인 품질 기준
