---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) v3 — 커맨드 레퍼런스

사용자에게 아래 내용을 그대로 출력하라.

## 커맨드

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 이 가이드 출력 |
| `/wj:init` | `[--with-prd]` | 클린 스캐폴딩 (docs/ + .dev/ + CLAUDE.md) |
| `/wj:loop` | `start [id] \| stop \| status` | 세션 내 자율 루프 |
| `/wj:verify` | `[--smoke]` | 전체 빌드+테스트 최종 검증 |
| `/wj:check` | — | 품질 전수 점검 (TS/Python 자동 감지) |

## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:commit` | 한글 커밋 메시지 자동 생성 |
| `/wj:devrule` | 프로젝트 구조 적용 개발 |
| `/wj:learn` | 교훈 → 규칙에 반영 |
| `/wj:standards` | 고품질 코드 표준 강제 참조 |
| `/wj:cto-review` | 코드베이스 전수 점검 |
| `/wj:ideation` | 전문가 스쿼드 기획 논의 |
| `/wj:team` | 에이전트 팀 구성 병렬 작업 |

## 워크플로

```
1. /wj:init --with-prd      → 스캐폴딩 + PRD 템플릿
2. docs/prd.md 편집          → task 정의
3. .dev/tasks.json 작성      → acceptance criteria 정의
4. /wj:loop start            → 자율 루프 시작
5. (자동) L1→L2→L3 게이트    → 품질 통과 시 다음 task
6. /wj:loop stop             → 중단
7. /wj:verify                → 전체 빌드 최종 검증
8. /wj:commit                → 커밋
```

## 아키텍처

- `docs/` — 사람이 관리하는 비즈니스 문서
- `.dev/` — AI가 남기는 작업 흔적 (tasks.json, journal/, state/)
- `CLAUDE.md` — 프로젝트 지도 (~100줄)
- Stop hook — 매 턴 종료 시 L1(grep)/L2(tsc)/L3(test) 게이트 자동 실행
