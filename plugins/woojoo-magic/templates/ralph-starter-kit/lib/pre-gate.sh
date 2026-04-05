#!/usr/bin/env bash
# pre-gate.sh — Stage 0: 사전 검증
set -euo pipefail

# 상위 스크립트에서 source되지 않아도 동작하도록
if ! declare -f collect_quality_metrics >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/metrics.sh"
fi

pre_gate_run() {
  local iter="$1"
  local state="${STATE_DIR:-.ralph-state}"
  mkdir -p "$state"

  echo "[pre-gate] iter=$iter 시작"

  # 1. git 저장소 확인
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "[pre-gate] ERROR: git 저장소가 아닙니다"
    return 1
  fi

  # 2. git clean 확인 — Ralph 런타임 산출물(.ralph-state/)은 self-owned로 간주하여 제외
  local dirty
  dirty=$(git status --porcelain -- ':!:.ralph-state' ':!:.ralph-state/**' 2>/dev/null || git status --porcelain)

  # 2-a. post-gate 하우스키핑 잔존물 자동 회수
  #      post-gate.sh가 tests.json summary 재계산 + progress.md append 후 커밋에
  #      실패한 경우를 대비한 안전망. 오직 이 두 파일만 단독으로 dirty일 때 자동 커밋.
  if [[ -n "$dirty" ]]; then
    local only_housekeeping=1
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local path="${line:3}"
      if [[ "$path" != "tests.json" && "$path" != "progress.md" ]]; then
        only_housekeeping=0
        break
      fi
    done <<< "$dirty"
    if (( only_housekeeping == 1 )); then
      echo "[pre-gate] 하우스키핑 잔존물 감지 → 자동 회수 커밋"
      git add -- tests.json progress.md 2>/dev/null || true
      if git commit -m "chore(ralph): iter-${iter} pre-gate housekeeping recovery" >/dev/null 2>&1; then
        dirty=""
      fi
    fi
  fi

  if [[ -n "$dirty" ]]; then
    echo "[pre-gate] ERROR: working tree가 dirty합니다. 먼저 commit/stash 해주세요"
    echo "$dirty"
    return 1
  fi

  # 3. 체크포인트 브랜치/태그
  local head_sha; head_sha=$(git rev-parse HEAD)
  echo "$head_sha" > "$state/checkpoint-${iter}.sha"
  echo "[pre-gate] 체크포인트: $head_sha"

  # 4. 현재 품질 메트릭 수집
  local curr="$state/quality-pre-${iter}.json"
  collect_quality_metrics > "$curr"
  echo "[pre-gate] quality 스냅샷: $(cat "$curr")"

  # 5. 이전과 비교 (strict 모드에서만 사전 회귀 차단)
  local prev="$state/prev-metrics.json"
  if [[ -f "$prev" && "${STRICT:-0}" == "1" ]]; then
    local delta; delta=$(get_delta "$prev" "$curr")
    local d_over d_any d_nn
    d_over=$(echo "$delta" | jq '.files_over_300_delta')
    d_any=$(echo "$delta" | jq '.any_count_delta')
    d_nn=$(echo "$delta" | jq '.nonnull_count_delta')
    if (( d_over > 0 || d_any > 0 || d_nn > 0 )); then
      echo "[pre-gate] STRICT: 직전 iteration이 품질 회귀를 남겼습니다 → ABORT"
      echo "$delta"
      return 1
    fi
  fi

  echo "[pre-gate] OK"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  pre_gate_run "${1:-manual}"
fi
