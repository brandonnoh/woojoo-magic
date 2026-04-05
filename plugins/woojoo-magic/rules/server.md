---
globs:
  - "**/server/**/*.ts"
  - "**/backend/**/*.ts"
  - "**/api/**/*.ts"
---

## Server Rules

### MCP 필수
- 코드 탐색/수정: **Serena** symbolic tools 우선
- Express/ws/Zod/Pino 등 라이브러리 API: **Context7** 조회 필수

### QA 필수
- 개발 완료 후: **`review-code`** 스킬로 변경사항 검증 필수

### Architecture
- 엔진 접근: 서버 측 runtime/adapter 경계 통과 필수 (공유 엔진 직접 import 지양)
- 메시지 스키마: 공유 타입 디렉터리 기준, Zod 등 런타임 검증
- 인메모리 상태 → 서버 재시작 시 데이터 소멸 (영속화 고려)
- 민감 로직(AI, 셔플, 밸런싱 등)은 서버 비공개 계층에 유지
- 서버 전용 상태 / 클라이언트 전송 상태 경계 유지

### Guardrails
- 존재하지 않는 파일/모듈 가상 생성 금지
- 가상 타입/인터페이스 복붙 금지 → 실제 공유 타입 파일 확인

### Quality Standards (woojoo-magic)
- 파일 300줄, 함수 20줄 이하
- `any`, `!.` 금지
- Result<T,E>로 실패 명시, throw 남발 금지
- Silent catch 금지 (반드시 로깅 또는 복구)
- Branded Types로 도메인 식별자 구분
