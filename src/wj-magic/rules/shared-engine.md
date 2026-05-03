---
globs:
  - "**/shared/**/*.ts"
  - "**/core/**/*.ts"
  - "**/domain/**/*.ts"
  - "**/engine/**/*.ts"
---

## Shared Engine Rules

### MCP 필수
- 코드 탐색/수정: **Serena** symbolic tools 우선
- 라이브러리 API: **Context7** 조회 필수

### QA 필수
- 개발 완료 후: **`review-code`** 스킬로 변경사항 검증 필수

### Core Principles
- Single source of truth (도메인 규칙)
- 순수 함수만 — IO 금지 (네트워크, 파일, 로깅)
- 불변성: spread operator로 새 객체 반환
- 변경 후 필수: 엔진 패키지 빌드 + 테스트 통과

### Type Contract
- 타입 기준: 공유 타입 디렉터리(예: `src/types/*`)
- client/server 동일 개념 중복 계산 금지

### Quality Standards

→ `references/common/AGENT_QUICK_REFERENCE.md` (파일/함수 크기, forbidden patterns, Branded Types, Result, DU)
