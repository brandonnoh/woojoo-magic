# v2 → v3 마이그레이션 가이드

## Breaking Changes

1. 외부 Ralph 루프 삭제 (ralph.sh, lib/, prompts/, schemas/)
2. 유저 프로젝트 루트의 Ralph 파일 더 이상 자동 생성 안 됨
3. 커맨드 7개 삭제 (brand, harness, plan, result, smoke-init, spec-init, standards)
4. 스킬 7개 삭제 (init-prd, implement-next, feedback-to-prd, seo-optimizer, ui-ux-pro-max, senior-frontend, backend-dev-rules)

## 마이그레이션 순서

기존 v2 프로젝트에서:

1. 플러그인 업데이트 (v3.0.0 설치)
2. `/wj:init` 실행 → 새 docs/, .dev/ 구조 생성
3. 기존 파일 이동:

| 기존 위치 | 새 위치 | 명령 |
|---|---|---|
| `prd.md` | `docs/prd.md` | `mv prd.md docs/` |
| `specs/` | `docs/specs/` | `mv specs docs/` |
| `tests.json` | `.dev/tasks.json` | `mv tests.json .dev/tasks.json` |
| `progress.md` | `.dev/journal/` | `mv progress.md .dev/journal/legacy-progress.md` |
| `LESSONS.md` | `.dev/learnings.md` | `mv LESSONS.md .dev/learnings.md` |
| `.ralph-state/` | `.dev/state/` | `mv .ralph-state .dev/state` 또는 삭제 |

4. 삭제 대상:

```bash
rm -f ralph.sh smoke-test.sh
rm -rf lib/ prompts/ schemas/
```

5. `.gitignore`에서 Ralph 관련 블록 정리, `.dev/` 추가:

```gitignore
.dev/
!.dev/tasks.json
```

6. 커밋
