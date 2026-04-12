#!/usr/bin/env bash
# rollback.sh — iteration 실패 시 git reset 복원
set -euo pipefail

rollback_iteration() {
  local iter="$1"
  local reason="${2:-unknown}"
  local state="${STATE_DIR:-.ralph-state}"
  local sha_file="$state/checkpoint-${iter}.sha"

  echo "[rollback] iter=$iter reason=$reason"

  # 실패 원인을 last-failure.log에 기록 → 다음 Worker가 참조
  {
    echo "=== iter=$iter reason=$reason $(date +%Y-%m-%dT%H:%M:%S) ==="
    local fail_log="$state/logs/iter-${iter}-3-quality.log"
    if [[ -f "$fail_log" ]]; then
      echo "--- quality-gate 로그 (tail 30) ---"
      tail -30 "$fail_log"
    fi
    local worker_log="$state/logs/iter-${iter}-2-worker-1.log"
    if [[ -f "$worker_log" ]]; then
      echo "--- worker 로그 (tail 15) ---"
      tail -15 "$worker_log"
    fi
  } > "$state/last-failure.log"

  if [[ ! -f "$sha_file" ]]; then
    echo "[rollback] WARNING: 체크포인트 SHA 없음 → HEAD 유지"
    return 0
  fi

  local sha; sha=$(cat "$sha_file")
  echo "[rollback] git reset --hard $sha"
  git reset --hard "$sha" 2>&1 || {
    echo "[rollback] ERROR: reset 실패"
    return 1
  }

  # rollback 기록
  local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  jq -n \
    --argjson iter "$iter" \
    --arg ts "$ts" \
    --arg reason "$reason" \
    '{iter: $iter, timestamp: $ts, rollback: true, reason: $reason}' \
    >> "$state/metrics.jsonl"

  echo "[rollback] OK"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  rollback_iteration "${1:-manual}" "${2:-manual}"
fi
