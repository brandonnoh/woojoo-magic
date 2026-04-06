#!/usr/bin/env bash
# smoke-test.sh — Ralph Quality Gate E2E Smoke Test
# 프로젝트에 맞게 수정하세요. Quality Gate가 빌드+테스트 후 자동 실행합니다.
#
# 사용법:
#   bash smoke-test.sh          — 직접 실행
#   (Ralph가 자동 실행)         — quality-gate.sh에서 호출
#
# 종료 코드:
#   0 = 성공 (Quality Gate 통과)
#   1 = 실패 (Quality Gate 실패 → 롤백)
set -euo pipefail

# ─── 설정 ──────────────────────────────────────────────
PORT="${SMOKE_PORT:-3000}"
BASE="http://localhost:${PORT}"
TIMEOUT=10  # 서버 기동 대기 (초)

# ─── 서버 기동 ─────────────────────────────────────────
# TODO: 프로젝트에 맞게 서버 시작 명령 수정
# 예시: pnpm --filter my-server start
echo "[smoke] 서버 기동 중... (port=$PORT)"
# pnpm --filter my-server start &
# SERVER_PID=$!

# cleanup() { kill $SERVER_PID 2>/dev/null || true; }
# trap cleanup EXIT

# ─── 서버 대기 ─────────────────────────────────────────
# for i in $(seq 1 $TIMEOUT); do
#   if curl -sf "$BASE/health" > /dev/null 2>&1; then
#     break
#   fi
#   sleep 1
# done

# ─── 핵심 플로우 검증 ─────────────────────────────────
# TODO: 프로젝트의 핵심 플로우에 맞게 수정

# 1. Health Check
# curl -sf "$BASE/health" > /dev/null
# echo "[smoke] OK health"

# 2. Guest Login
# TOKEN=$(curl -sf "$BASE/api/auth/guest" | jq -r '.token')
# [[ -n "$TOKEN" && "$TOKEN" != "null" ]]
# echo "[smoke] OK guest-login"

# 3. Session Create
# SESSION=$(curl -sf -H "Authorization: Bearer $TOKEN" \
#   "$BASE/api/sessions" -X POST | jq -r '.id')
# [[ -n "$SESSION" && "$SESSION" != "null" ]]
# echo "[smoke] OK session-create"

# 4. Core Action
# RESULT=$(curl -sf -H "Authorization: Bearer $TOKEN" \
#   "$BASE/api/sessions/$SESSION/action" -X POST \
#   -H "Content-Type: application/json" \
#   -d '{"type": "ping"}' | jq -r '.status')
# [[ "$RESULT" != "null" ]]
# echo "[smoke] OK core-action"

echo "[smoke] ALL PASSED"
echo "[smoke] (주석을 해제하고 프로젝트에 맞게 수정하세요)"
