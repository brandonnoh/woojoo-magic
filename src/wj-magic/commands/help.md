---
description: 커맨드·스킬 전체 목록과 사용법 안내
---

# woojoo-magic (wj) v4.6 — 커맨드 레퍼런스

사용자에게 아래 내용을 그대로 출력하라.

## 커맨드

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 커맨드·스킬 전체 목록과 사용법 안내 |
| `/wj:init` | `[--with-prd]` | 프로젝트 최초 세팅 — docs/ + .dev/ + CLAUDE.md 구조 생성 |
| `/wj:loop` | `plan <요구사항> \| start [task-id] \| stop \| status` | 자율 개발 루프 — PRD 생성→에이전트 구현→검증 사이클 자동 반복 |
| `/wj:verify` | `[--smoke]` | 전체 빌드 + 테스트 수동 실행 — 커밋 전 최종 게이트 |
| `/wj:check` | — | 코드베이스 품질 전수 점검 — 파일 크기·복잡도·any·silent catch 위반 리포트 |
| `/wj:explain` | — | 코드·개념 해설 — 바이브코더 눈높이로 시스템 위치·이유·대안까지 설명 |

## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:investigate` | 이슈 심층 분석 — 5개 에이전트 병렬 투입으로 근본 원인 규명 후 자동 수정 |
| `/wj:devrule` | 코드 구현 — 규모(S/M/L)별 직접 작성 또는 전문 에이전트 위임 |
| `/wj:tdd` | 테스트 주도 구현 — Red→Green→Refactor 사이클 강제 |
| `/wj:design` | 새 UI 디자인 — 비주얼 방향 설정부터 컴포넌트 구현까지 (신규 제작) |
| `/wj:polish` | 기존 UI 개선 — 완성된 화면을 진단·처방해 시각적 완성도 향상 |
| `/wj:brainstorm` | 아이디어 → 스펙 문서 — 막연한 아이디어를 1:1 대화로 정제해 설계 문서 완성 |
| `/wj:plan` | 스펙 → 태스크 분해 — 완성된 요구사항을 단계별 구현 태스크 목록으로 변환 |
| `/wj:team` | 커스텀 에이전트 팀 조립 — 작업에 맞는 전문가를 직접 선별해 병렬 팀으로 실행 |
| `/wj:cto-review` | 코드베이스 리팩토링 — 아키텍처·성능·보안·접근성 전수 점검 후 Wave 전략으로 자동 수정 |
| `/wj:ideation` | 제품 전략 탐색 — PM·UX·사업·마케팅·데이터 5명 스쿼드가 병렬 리서치 후 통합 의견 도출 |
| `/wj:learn` | 교훈 → 규칙 반영 — 발견된 실수·패턴을 devrule에 영구 등록해 반복 방지 |
| `/wj:commit` | 한글 커밋 메시지 자동 생성 — feat/fix/ui/ux/docs/refactor/chore/test/perf 타입 분류 |
| `/wj:verify` | 완료 검증 — "됐어" 주장 전에 실행·통과 증거를 확보하도록 강제 |
| `/wj:explain` | 코드·개념 해설 — 바이브코더 눈높이로 시스템 위치·이유·대안까지 친절하게 설명 |

## 워크플로

```
1. /wj:init --with-prd      → 스캐폴딩 + PRD 템플릿
2. /wj:loop plan             → 요구사항 → PRD + tasks.json + specs 생성
3. /wj:loop start            → 자율 루프 시작
4. (자동) 테스트 + 디자인 리뷰 + 보안 감사 + QA + L1→L2→L3 게이트
5. /wj:loop stop             → 중단
6. /wj:verify                → 전체 빌드 최종 검증
7. /wj:commit                → 커밋
```

## 아키텍처

- `docs/` — 사람이 관리하는 비즈니스 문서
- `.dev/` — AI가 남기는 작업 흔적 (tasks.json, journal/, state/)
- `CLAUDE.md` — 프로젝트 지도 (~100줄)
- 전문 에이전트 13개 — frontend-dev, backend-dev, engine-dev, design-dev, design-reviewer, security-auditor, test-engineer, qa-reviewer, docs-keeper, web-researcher, code-analyst, perf-analyst, regression-hunter
- Stop hook — 매 턴 종료 시 L1(정적감사)/L2(타입체크)/L3(테스트) 게이트 자동 실행 (6개 언어)
- SubagentStop hook — 서브에이전트 L1 품질 게이트
- PreToolUse hook — 위험 명령 차단 + 민감 파일(.env/.pem) 보호
