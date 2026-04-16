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
