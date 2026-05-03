# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# woojoo-magic

> Claude Code 플러그인 — 클린 스캐폴딩 + 세션 내 자율 루프

## 빠른 참조
- 플러그인 구조: `docs/ARCHITECTURE.md`
- v2→v3 마이그레이션: `docs/MIGRATION.md`
- 설계서: `docs/superpowers/specs/2026-04-11-plugin-v3-redesign.md`

## 테스트 실행

```bash
# 전체 테스트
bats tests/

# 특정 파일
bats tests/hooks/stop-loop.bats
bats tests/lib/gate-l1.bats
bats tests/commands/init.bats
```

빌드 스텝 없음 — 스크립트는 직접 소싱됨. 별도 패키지 매니저 불필요.

## 구조

```
src/wj-magic/
├── commands/     — 7개 사용자 명령 (/wj:init, /wj:loop, /wj:verify, /wj:check, /wj:help, /wj:explain, /wj:audit)
├── skills/       — 15개 워크플로우 (/wj:commit, /wj:devrule, /wj:investigate, /wj:audit 등)
├── agents/       — 21개 전문 에이전트 정의 (기존 13 + 보안 감사 8: auth-auditor, injection-hunter 등)
├── hooks/        — 7개 이벤트 훅 bash 스크립트 + hooks.json
├── lib/          — 품질 게이트 라이브러리 (gate-l1~3, patterns, investigation-utils 등)
├── rules/        — 7개 glob 매칭 자동 주입 규칙
├── references/   — 30+ 언어별/디자인 품질 기준 문서
├── templates/    — 프로젝트 스캐폴딩 템플릿
└── mcp-presets/  — 기본 MCP 서버 설정 (Serena, Context7, Playwright 등)
tests/
├── hooks/, lib/, commands/   — BATS 단위 테스트
└── fixtures/minimal-ts/      — TypeScript 테스트 픽스처
```

## 핵심 아키텍처

**이벤트 훅 흐름:**
1. `SessionStart` → `bootstrap.sh` (`.dev/state/` 초기화) + `session-summary.sh`
2. `PreToolUse(Bash)` → `block-dangerous.sh` (`rm -rf`, `sudo`, `git push --force` 차단)
3. `PreToolUse(Edit|Write)` → `block-sensitive-write.sh` (`.env`, `.pem` 보호)
4. `PostToolUse(Edit|Write)` → `quality-check.sh` (즉시 파일 크기·패턴 검사)
5. `Stop` → `stop-loop.sh` (L1→L2→L3 게이트 순차 실행, 블록 여부 결정)
6. `SubagentStop` → `subagent-gate.sh` (서브에이전트 L1 검사)

**3단계 품질 게이트:**
- **L1** (<1s, grep): 파일/함수 크기, forbidden 패턴 (`any`, `!.`, silent catch). `lib/gate-l1.sh` → 언어별 `gate-l1-{ts,py,go,rs,sw,kt}.sh` 위임
- **L2** (2-10s, 타입체커): `tsc --noEmit`, `pyright --strict`, `cargo check` 등. `lib/gate-l2.sh`
- **L3** (5-30s, 루프 모드 한정): 변경된 파일 매칭 테스트만 실행. `lib/gate-l3.sh`

**크기별 실행 전략 (`skills/devrule`):**
- S (1-3 파일): Claude 직접 구현
- M (4-10 파일): 전문 에이전트 1개 위임
- L (10+ 파일): 에이전트 팀 병렬 작업 (worktree 격리)

**언어별 파일 크기 제한:**
- TypeScript: 300줄/파일, 20줄/함수
- Python: 600줄/파일, 50줄/함수
- Go/Rust: 500줄/파일 | Swift/Kotlin: 400줄/파일

**자동 주입 규칙 (glob 매칭):**
- `**/client/**`, `**/web/**` → `rules/frontend.md` 자동 로드
- `**/server/**`, `**/api/**` → `rules/server.md`
- `**/shared/**`, `**/core/**` → `rules/shared-engine.md`
- `**/*.css`, `**/*.styled.*` → `rules/design.md`
- `**/*.test.ts`, `**/*.spec.ts` → `rules/tests.md`
- `**/migrations/**`, `**/*.migration.*` → `rules/db-migration.md`
- `**/*.sh`, `**/*.bash` → `rules/scripts.md`

## 규칙

- bash 스크립트: `set -euo pipefail` 필수
- 메인 루프에서 `local` 금지, `_prefix` 변수명 사용
- 한글 커밋 메시지
- **테스트 픽스처 시크릿 패턴**: `sk_live_*`, `ghp_*`, `AKIA*` 등 실 서비스 prefix 금지.
  반드시 `sk_test_FAKE_*` / `ghp_FAKE_*` 같이 명백한 더미 prefix 사용 — GitHub
  secret scanning 오탐으로 push가 차단될 수 있음 (2026-04-16 filter-branch
  이력 rewrite 이력 있음).
- 새 언어 게이트 추가 시: `lib/gate-l1-{lang}.sh` 생성 후 `lib/gate-l1.sh`에 분기 추가
- 공유 패턴은 `lib/patterns.sh`에 정의 — L1 게이트와 `quality-check.sh` 양쪽에서 소싱됨
