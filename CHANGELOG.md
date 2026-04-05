# Changelog

## 1.0.0 — 2026-04-05

### 초기 릴리스

crypto-holdem 프로젝트의 Phase 1-7 리팩토링 여정에서 축적된 실전 패턴을 플러그인화.

#### Added
- **Skills (13개)**: devrule, senior-frontend, backend-dev-rules, commit, learn, team, ui-ux-pro-max, cto-review, init-prd, ideation, feedback-to-prd, implement-next, seo-optimizer
- **Agents (5개)**: frontend-dev, backend-dev, engine-dev, qa-reviewer, docs-keeper (Creator-Reviewer 패턴)
- **Shared References (8개)**:
  - HIGH_QUALITY_CODE_STANDARDS.md (파일/함수/Props 한계, 타입 안전, 성능, DRY)
  - BRANDED_TYPES_PATTERN.md
  - RESULT_PATTERN.md
  - DISCRIMINATED_UNION.md (wrapSetWithPhase 무침습 도입)
  - NON_NULL_ELIMINATION.md
  - LIBRARY_TYPE_HARDENING.md (viem 실전 예시)
  - ZUSTAND_SLICE_PATTERN.md
  - REFACTORING_PREVENTION.md
- **Ralph v2**: 5-Stage Pipeline (Pre-Gate → Planner → Workers → Quality-Gate → Reviewer → Post-Gate)
  - 모델 라우팅 (haiku/sonnet/opus)
  - 병렬 워커 (`--parallel N`)
  - 품질 회귀 자동 차단 (`--strict`)
  - 자동 git rollback
  - append-only metrics.jsonl
- **MCP (10개)**: serena, context7, sequential-thinking, playwright, chrome-devtools, shadcn, magic, tavily-remote, memory, smithery-ai-github
- **Hooks (4개)**: install-mcp (dedup 자동 설치), session-summary, block-dangerous, quality-check
- **Commands (6개)**: /woojoo:init-ralph, check-quality, apply-branded, apply-result, refactor-plan, check-harness
- **Rules (4개)**: frontend, server, shared-engine, tests (레이어별 규칙 템플릿)

#### 주요 설계 결정
- **SessionStart 훅으로 MCP 자동 dedup 설치**: 기존 `~/.claude.json`과 비교 후 누락된 것만 프로젝트 `.mcp.json`에 병합. 재실행 방지 마커 사용.
- **모든 스킬이 shared-references 중앙 참조**: 중복 제거 + 단일 진실 공급원.
- **Ralph v2는 Creator-Reviewer 분리**: 같은 인스턴스가 짜고 리뷰하는 bias 제거.
- **품질 델타 추적**: iteration마다 300줄/any/!./tests 메트릭 기록 → 회귀 시 즉시 중단.
