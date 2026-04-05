---
name: release
description: 플러그인 버전업 + 마켓플레이스 배포. 트리거 - 배포, 릴리스, release, 버전업, 버전 올려, 마켓 배포, marketplace deploy, bump version, publish. CHANGELOG.md + marketplace.json 버전 업데이트 + 커밋 + 푸쉬를 한번에 처리.
---

# 릴리스 워크플로우

## 절차

1. **변경 내역 수집** — `git log --oneline` 최근 커밋 + `git diff` 확인
2. **시맨틱 버전 결정** — 사용자가 명시하지 않으면 변경 내용으로 추론:
   - `MAJOR` — breaking change
   - `MINOR` — 신규 기능 (feat)
   - `PATCH` — 버그 수정 (fix), 하우스키핑 (chore)
3. **CHANGELOG.md 업데이트** — 새 버전 섹션을 기존 최상단 버전 바로 위에 추가
4. **버전 3곳 동시 업데이트** — 아래 세 파일의 version을 모두 동일한 새 버전으로 교체:
   - `.claude-plugin/marketplace.json` — `metadata.version` + 모든 `plugins[].version`
   - `plugins/woojoo-magic/.claude-plugin/plugin.json` — `version` (Claude Code UI가 읽는 실제 버전)
5. **description 동기화** — 스킬 수 등이 바뀌었으면 marketplace.json과 plugin.json의 description도 맞출 것
6. **커밋** — `chore: marketplace.json + CHANGELOG vX.Y.Z 반영` 포맷
7. **푸쉬** — `git push origin <current-branch>`
8. **설치된 클론 동기화** — `cd ~/.claude/plugins/marketplaces/wj-tools && git pull origin main` 실행. 소스 repo push만으로는 설치된 플러그인 클론이 자동 갱신되지 않음. 이 단계를 빠뜨리면 Claude Code UI에 옛 버전이 표시됨

## 파일 위치

- `CHANGELOG.md` — 프로젝트 루트
- `.claude-plugin/marketplace.json` — 마켓플레이스 메타데이터 (원격 배포용)
- `plugins/woojoo-magic/.claude-plugin/plugin.json` — 플러그인 메타데이터 (Claude Code UI 표시용, **이걸 빠뜨리면 UI 버전이 안 바뀜**)

## CHANGELOG 포맷

```markdown
## X.Y.Z — YYYY-MM-DD

### Fixed / Added / Changed
- **제목**: 설명
```

## 주의사항

- 커밋 안 된 변경이 있으면 먼저 커밋 또는 사용자에게 확인
- 버전 번호는 반드시 세 자리 (X.Y.Z)
- marketplace.json 내 버전이 2곳 이상이면 전부 동일하게 맞출 것
- description 필드도 변경이 필요하면 (스킬 수 변경 등) 같이 업데이트
