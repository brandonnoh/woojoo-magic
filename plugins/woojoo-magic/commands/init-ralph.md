---
description: 새 프로젝트에 Ralph v2 자율 개발 루프 셋업
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치하라.

**실행 방법**: 다음 Bash 명령을 실행하라.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh"
```

이 스크립트가 자동으로 수행하는 작업:
- `ralph.sh`, `lib/`, `prompts/`, `schemas/` 복사 (기존 파일 스킵)
- `prd.md`, `tests.json`, `progress.md` 템플릿 생성 (없는 경우에만)
- `.ralph-state/` 디렉토리 생성
- 실행 권한 부여
- 프로젝트 스택 자동 감지 → `.ralph-state/stack.json`

**실행 후 할 일**:
- 설치 결과 요약 출력
- 사용자에게 `prd.md` 작성 가이드 제공
- 다음 단계 (tests.json 작성, `bash ralph.sh --dry-run`) 안내
