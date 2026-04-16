# woojoo-magic

> Claude Code 플러그인 — 클린 스캐폴딩 + 세션 내 자율 루프

## 구조
- `src/woojoo-magic/` — 플러그인 소스
- `docs/` — 설계 문서, 마이그레이션 가이드
- `tests/` — bats 회귀 테스트
- `.dev/` — 개발 흔적

## 빠른 참조
- 플러그인 구조: `docs/ARCHITECTURE.md`
- v2→v3 마이그레이션: `docs/MIGRATION.md`
- 설계서: `docs/superpowers/specs/2026-04-11-plugin-v3-redesign.md`
- 테스트: `bats tests/`

## 규칙
- bash 스크립트: `set -euo pipefail` 필수
- 메인 루프에서 `local` 금지, `_prefix` 변수명 사용
- 한글 커밋 메시지
- **테스트 픽스처 시크릿 패턴**: `sk_live_*`, `ghp_*`, `AKIA*` 등 실 서비스 prefix 금지.
  반드시 `sk_test_FAKE_*` / `ghp_FAKE_*` 같이 명백한 더미 prefix 사용 — GitHub
  secret scanning 오탐으로 push가 차단될 수 있음 (2026-04-16 filter-branch
  이력 rewrite 이력 있음).
