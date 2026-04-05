---
description: woojoo-magic 플러그인 전체 커맨드 목록과 사용법
---

# woojoo-magic (wj) — 전체 커맨드 가이드

사용자에게 다음 정보를 출력하라. 표 형식 + 그 외 핵심 기능 요약.

## 커맨드 7개

| 커맨드 | 역할 |
|--------|------|
| `/wj:help` | 이 가이드 출력 |
| `/wj:init` | Ralph v2 재설치 (첫 세션에 자동 부트스트랩되므로 수동은 거의 불필요) |
| `/wj:check` | 프로젝트 전체 품질 전수 점검 — 300줄 초과, any, !., Silent catch, 중복 |
| `/wj:harness` | 하네스 건강 진단 — 스킬/에이전트/MCP/규칙 로드 상태 |
| `/wj:brand` | Branded Types 점진 마이그레이션 — PlayerId, ChipAmount 등 |
| `/wj:result` | Result<T,E> 패턴 점진 도입 — throw → Result 전환 |
| `/wj:plan` | God Class / 300줄 초과 파일 리팩토링 계획 자동 생성 |

## 자동 동작 (수동 호출 불필요)

- **SessionStart 부트스트랩** — 첫 세션 시 MCP + Ralph v2 자동 설치
- **PreToolUse (Bash)** — `rm -rf /`, `sudo`, force push 등 위험 명령 자동 차단
- **PostToolUse (Edit/Write)** — 편집한 파일의 any, !., 300줄 초과, Silent catch 자동 감지

## Skills (13개)

`/devrule`, `/senior-frontend`, `/backend-dev-rules`, `/commit`, `/learn`, `/team`, `/ui-ux-pro-max`, `/cto-review`, `/init-prd`, `/ideation`, `/feedback-to-prd`, `/implement-next`, `/seo-optimizer`

## Agents (5개)

Agent tool에서 호출 가능:
- `frontend-dev` — React/Vue/Svelte UI 전문
- `backend-dev` — Express/Fastify/NestJS 서버 전문
- `engine-dev` — 순수 함수/비즈니스 로직 (IO 금지)
- `qa-reviewer` — Creator-Reviewer 패턴의 Reviewer
- `docs-keeper` — 코드 변경 시 문서 자동 동기화

## Shared References (8개 품질 가이드)

플러그인 내 `shared-references/`:
- `HIGH_QUALITY_CODE_STANDARDS.md` — 파일/함수 크기, 타입 안전, 성능
- `BRANDED_TYPES_PATTERN.md` — PlayerId/ChipAmount 경계 캐스트
- `RESULT_PATTERN.md` — throw → Result + tryAsync
- `DISCRIMINATED_UNION.md` — wrapSetWithPhase 무침습 패턴
- `NON_NULL_ELIMINATION.md` — guard clause + 로컬 변수
- `LIBRARY_TYPE_HARDENING.md` — viem 등 any 제거 (Context7 필수)
- `ZUSTAND_SLICE_PATTERN.md` — 도메인 슬라이스 + actions
- `REFACTORING_PREVENTION.md` — 리팩토링 방지 시그널

## Ralph v2 — 자율 개발 루프

첫 세션에 자동 설치됨:
```bash
bash ralph.sh --dry-run        # 5-stage 파이프라인 미리보기
bash ralph.sh --iter 10        # 자율 루프 시작
bash ralph.sh --parallel 2     # 워커 2개 병렬
bash ralph.sh --strict         # 품질 회귀 시 즉시 중단
```

## 철학

> "리팩토링은 실패의 신호다. 처음부터 제대로 짜면 리팩토링이 필요 없다."

repo: https://github.com/brandonnoh/woojoo-magic
