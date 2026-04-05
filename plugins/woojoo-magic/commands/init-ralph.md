---
description: 새 프로젝트에 Ralph v2 자율 개발 루프 셋업
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치한다.

절차:

1. `${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/` 전체를 현재 프로젝트 루트로 복사 (기존 파일 덮어쓰지 않음)
2. 다음 템플릿이 없으면 생성:
   - `prd.md` — 제품 요구 명세 (빈 스켈레톤)
   - `tests.json` — Ralph 작업 큐 (빈 `{ "tasks": [] }`)
   - `progress.md` — iteration 기록 (빈 파일)
3. 프로젝트 스택 자동 감지 (`templates/ralph-starter-kit/detect-stack.sh`가 있으면 실행)
4. `.ralph-state/` 디렉토리 생성 (내부 상태 저장)
5. 사용법 README 출력:
   - prd.md 작성 → tests.json에 태스크 추가 → Ralph 루프 실행

주의:
- 기존 `prd.md`, `tests.json`, `progress.md`가 존재하면 건드리지 말고 안내만 출력
- 복사 후 실행 권한이 필요한 스크립트는 `chmod +x` 적용
- 완료 후 생성된 파일/디렉토리 트리 요약 출력
