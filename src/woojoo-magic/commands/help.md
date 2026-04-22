---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) v4.4 — 커맨드 레퍼런스

사용자에게 아래 내용을 그대로 출력하라.

## 커맨드

| 커맨드 | 인자 | 역할 |
|--------|------|------|
| `/wj:help` | — | 이 가이드 출력 |
| `/wj:init` | `[--with-prd]` | 클린 스캐폴딩 (docs/ + .dev/ + CLAUDE.md) |
| `/wj:loop` | `plan <요구사항> \| start [task-id] \| stop \| status` | PRD/task 생성 + 세션 내 자율 루프 |
| `/wj:verify` | `[--smoke]` | 전체 빌드+테스트 최종 검증 |
| `/wj:check` | — | 품질 전수 점검 (TS/Python/Go/Rust/Swift/Kotlin) |

## 스킬

| 스킬 | 역할 |
|------|------|
| `/wj:investigate` | 버그·성능·보안·아키텍처 심층 조사 (5 에이전트 팀 + 웹 리서치 + 자동 수정) |
| `/wj:devrule` | 프로젝트 구조 적용 개발 (S/M/L 규모별 전략) |
| `/wj:tdd` | Red-Green-Refactor TDD 프로세스 강제 |
| `/wj:design` | 디자인 기획 + 구현 (방향 설정 → 구현 → 리뷰) |
| `/wj:polish` | 기존 UI 디자인 개선 (진단 → 처방 → 검증) |
| `/wj:brainstorm` | 아이디어 → 설계 문서 1:1 대화 |
| `/wj:plan` | 스펙 → 구현 계획 (태스크 분해) |
| `/wj:team` | 에이전트 팀 구성 병렬 작업 |
| `/wj:cto-review` | 코드베이스 전수 점검 |
| `/wj:ideation` | 전문가 스쿼드 기획 논의 |
| `/wj:learn` | 교훈 → 규칙에 반영 |
| `/wj:commit` | 한글 커밋 메시지 자동 생성 |

## 워크플로

```
1. /wj:init --with-prd      → 스캐폴딩 + PRD 템플릿
2. /wj:loop plan             → 요구사항 → PRD + tasks.json + specs 생성
3. /wj:loop start            → 자율 루프 시작
5. (자동) 테스트 + 디자인 리뷰 + 보안 감사 + QA + L1→L2→L3 게이트
6. /wj:loop stop             → 중단
7. /wj:verify                → 전체 빌드 최종 검증
8. /wj:commit                → 커밋
```

## 아키텍처

- `docs/` — 사람이 관리하는 비즈니스 문서
- `.dev/` — AI가 남기는 작업 흔적 (tasks.json, journal/, state/)
- `CLAUDE.md` — 프로젝트 지도 (~100줄)
- 전문 에이전트 13개 — frontend-dev, backend-dev, engine-dev, design-dev, design-reviewer, security-auditor, test-engineer, qa-reviewer, docs-keeper, web-researcher, code-analyst, perf-analyst, regression-hunter
- Stop hook — 매 턴 종료 시 L1(정적감사)/L2(타입체크)/L3(테스트) 게이트 자동 실행 (6개 언어)
- SubagentStop hook — 서브에이전트 L1 품질 게이트
- PreToolUse hook — 위험 명령 차단 + 민감 파일(.env/.pem) 보호
