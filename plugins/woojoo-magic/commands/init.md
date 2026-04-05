---
description: Ralph v2 자율 개발 루프 설치 (--force로 강제 재설치)
argument-hint: "[--force] [--no-backup]"
---

현재 프로젝트에 woojoo-magic의 Ralph v2 자율 개발 루프를 설치하라.

## 사용자 인자

`$ARGUMENTS` — 다음 옵션 해석:
- `--force` : 기존 파일을 `.wj-backup-<timestamp>/`로 백업 후 덮어쓰기
- `--no-backup` : 백업 없이 덮어쓰기 (`--force`와 함께 사용, 권장 안 함)
- 아무 인자 없음 : 기존 파일 보존 (safe 모드, 기본값)

## 실행 방법

사용자 인자를 그대로 전달해서 install.sh를 Bash 도구로 실행하라:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/templates/ralph-starter-kit/install.sh" $ARGUMENTS
```

## install.sh가 수행하는 작업

1. `ralph.sh`, `lib/`, `prompts/`, `schemas/` 복사
2. `prd.md`, `tests.json`, `progress.md` 템플릿 생성
3. `.ralph-state/logs/` 디렉토리 생성
4. 실행 권한 부여 (chmod +x)
5. 프로젝트 스택 자동 감지 → `.ralph-state/stack.json`

## 동작 모드

| 모드 | 기존 파일 | 백업 |
|------|----------|------|
| 기본 (인자 없음) | 스킵 (보존) | N/A |
| `--force` | 백업 후 덮어쓰기 | `.wj-backup-<timestamp>/` 자동 생성 |
| `--force --no-backup` | 바로 덮어쓰기 | 없음 (복구 불가) |

## 실행 후 할 일

- 설치 결과 요약 출력 (복사/스킵/백업 개수)
- 백업이 생성됐다면 백업 경로 명시
- `prd.md` 작성 가이드 제공
- 다음 단계 (`bash ralph.sh --dry-run`) 안내

## 주의

- `--force` 모드는 기존 Ralph 설정을 덮어쓰므로 확인 후 실행
- 백업은 `.gitignore`에 추가하는 것을 권장 (백업 파일이 git 추적되지 않도록)
