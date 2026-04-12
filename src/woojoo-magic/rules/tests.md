---
globs:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
---

## Test Rules

### MCP 필수
- 테스트 대상 코드 탐색: **Serena** symbolic tools 우선
- 테스트 프레임워크 API: **Context7** 조회 필수

### Framework
- Vitest / Jest 등 프로젝트가 채택한 러너 사용
- `describe`: 대상 함수/컴포넌트 이름
- `it`: `should [동작]` 또는 한글 `~해야 한다`

### Pattern
- AAA: Arrange → Act → Assert
- 1 test = 1 assert (관련 항목 예외)
- 팩토리 함수로 테스트 데이터 생성 (하드코딩 금지)
- 스냅샷 테스트 지양

### Scope
- 엔진/도메인: 순수 함수 단위 테스트
- 서버: 메시지 검증, 세션 라이프사이클
- `any` 타입 사용 금지

### Guardrails
- 가짜 테스트 금지 (assert 없는 테스트, 항상 pass하는 테스트)
- 테스트 파일 역시 300줄 이하 유지
