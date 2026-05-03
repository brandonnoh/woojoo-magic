# s1-scaffold: wj-studybook 플러그인 스캐폴딩 + 마켓플레이스 등록

## 배경
신규 플러그인 `wj-studybook`을 woojoo-magic 마켓플레이스에 추가한다. 기존 `wj` 플러그인과 같은 리포에 공존하며, 설치 사용자는 두 플러그인을 독립적으로 켜고 끌 수 있다.

## 현재 코드 구조

- `src/wj-magic/` (기존 wj 플러그인) — 변경하지 않음
- `.claude-plugin/marketplace.json` (15줄)
  - 줄 8-15: `plugins[]` 배열에 wj 플러그인 1개만 등록됨

## 변경 범위

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `src/wj-studybook/` | 신규 디렉토리 | 플러그인 루트 |
| `src/wj-studybook/.claude-plugin/plugin.json` | 신규 | 플러그인 메타 |
| `src/wj-studybook/commands/studybook.md` | 신규 | 명령어 라우터 (골격) |
| `src/wj-studybook/hooks/hooks.json` | 신규 | 훅 등록 자리 (Stop/SessionEnd, 비어있어도 OK) |
| `src/wj-studybook/lib/.gitkeep` | 신규 | 빈 디렉토리 보존 |
| `src/wj-studybook/references/.gitkeep` | 신규 | 빈 디렉토리 보존 |
| `.claude-plugin/marketplace.json` | 수정 | `plugins[]`에 wj-studybook 항목 추가 |

## 구현 방향

### plugin.json

```json
{
  "name": "wj-studybook",
  "version": "0.1.0",
  "description": "Claude Code 세션의 어시스턴트 설명을 자동 수집·분류하여 학습자 맞춤 마크다운 책으로 발간하는 플러그인",
  "author": { "name": "woojoo" },
  "keywords": ["learning", "notes", "passive-learning", "study", "markdown", "session-capture", "obsidian-compatible"]
}
```

### marketplace.json (After 추가 후)

```json
{
  "name": "wj-tools",
  "owner": { "name": "woojoo" },
  "metadata": {
    "description": "Silicon Valley 수준 개발 환경 — 리팩토링이 필요 없도록 처음부터 고품질 코딩을 강제하는 플러그인",
    "version": "3.2.2"
  },
  "plugins": [
    {
      "name": "wj",
      "source": "./src/wj-magic",
      "description": "...",
      "version": "3.2.2"
    },
    {
      "name": "wj-studybook",
      "source": "./src/wj-studybook",
      "description": "Claude Code 세션의 어시스턴트 설명을 자동 수집·분류하여 학습자 맞춤 마크다운 책으로 발간",
      "version": "0.1.0"
    }
  ]
}
```

### studybook.md (명령어 라우터 골격)

```markdown
---
description: 세션 자동 학습 노트화 — config/digest/publish/similar/merge/backfill/tree/sync
argument-hint: "config init | digest | publish weekly | similar <쿼리> | tree"
---

`$ARGUMENTS`를 파싱해 첫 단어로 분기:

| 명령 | 동작 | 구현 task |
|------|------|----------|
| config init | 프로필 마법사 | s6 |
| config | 현재 설정 표시 | s8 |
| digest | inbox → topics 분류 | s10 |
| publish weekly | 주간 책 발간 | s13 |
| similar <쿼리> | 유사 노트 검색 | s11 |
| merge | 주제 병합 | s12 |
| backfill --since <날짜> | 과거 세션 소급 | s14 |
| tree | 분류 트리 시각화 | s15 |
| sync | 동기화 경로 안내 | s16 |

각 서브커맨드는 `${CLAUDE_PLUGIN_ROOT}/lib/<feature>.sh`로 위임.

(이 task에서는 골격만 제공, 실제 구현은 이후 task에서)
```

### hooks.json (빈 골격)

```json
{
  "Stop": [],
  "SessionEnd": []
}
```

(s3, s9에서 채워짐)

## 의존 관계

- 이 task의 산출물을 사용하는 곳: 모든 후속 task (s2~s16)
- 이 변경에 영향받는 외부 파일: `.claude-plugin/marketplace.json` 1개
- wj 플러그인과의 격리: 디렉토리 별도, 의존 없음

## 수락 조건
tasks.json의 acceptance_criteria와 동일.

## 검증 명령

```bash
# 디렉토리 존재
test -d src/wj-studybook/.claude-plugin
test -d src/wj-studybook/commands
test -d src/wj-studybook/hooks
test -d src/wj-studybook/lib

# JSON 파싱
jq '.' src/wj-studybook/.claude-plugin/plugin.json
jq '.' src/wj-studybook/hooks/hooks.json
jq '.plugins | length' .claude-plugin/marketplace.json   # 2 출력

# wj 플러그인 회귀 0
jq '.plugins[0].name' .claude-plugin/marketplace.json    # "wj" 출력
jq '.plugins[0].version' .claude-plugin/marketplace.json # "3.2.2" 출력
```
