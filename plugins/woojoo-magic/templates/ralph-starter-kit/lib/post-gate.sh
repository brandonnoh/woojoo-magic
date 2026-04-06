#!/usr/bin/env bash
# post-gate.sh — Stage 5: 커밋 검증 + 메트릭 기록
set -euo pipefail

if ! declare -f append_iteration_metrics >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/metrics.sh"
fi

post_gate_run() {
  local iter="$1"
  local duration="$2"
  local state="${STATE_DIR:-.ralph-state}"

  echo "[post-gate] iter=$iter duration=${duration}s"

  # 1. tests.json summary 재계산
  if [[ -f tests.json ]]; then
    local total passing failing
    total=$(jq '[.features[]] | length' tests.json 2>/dev/null || echo 0)
    passing=$(jq '[.features[] | select(.status == "passing")] | length' tests.json 2>/dev/null || echo 0)
    failing=$(( total - passing ))
    jq --argjson t "$total" --argjson p "$passing" --argjson f "$failing" \
      '.summary = {total: $t, passing: $p, failing: $f}' tests.json > tests.json.tmp \
      && mv tests.json.tmp tests.json
    echo "[post-gate] tests.json summary: $passing/$total"
  fi

  # 2. Claude가 commit 스킬로 이미 커밋했는지 확인
  local last_msg; last_msg=$(git log -1 --pretty=%s 2>/dev/null || echo "")
  echo "[post-gate] last commit: $last_msg"

  # 3. 현재 품질 메트릭
  local curr="$state/quality-${iter}.json"
  [[ ! -f "$curr" ]] && collect_quality_metrics > "$curr"

  # 4. metrics.jsonl append
  append_iteration_metrics "$iter" "$duration" "false" "$(cat "$curr")" 0

  # 5. prev-metrics 갱신 (다음 iteration 비교 기준)
  cp "$curr" "$state/prev-metrics.json"

  # 6. progress.md append
  if [[ -f progress.md ]]; then
    {
      echo ""
      echo "## iter-$iter — $(date +%Y-%m-%d\ %H:%M)"
      echo "- duration: ${duration}s"
      echo "- commit: $last_msg"
      echo "- quality: $(cat "$curr")"
    } >> progress.md
  fi

  # 7. 하우스키핑 자동 커밋 — tests.json summary + progress.md append로 dirty해진
  #    working tree를 그대로 두면 다음 iteration의 pre-gate가 거부한다.
  #    worker가 이미 메인 커밋을 만들었으므로 여기서는 orchestrator 소유 파일만
  #    범위 지정해서 커밋한다. (.ralph-state는 pre-gate가 pathspec으로 무시)
  local housekeeping_files=()
  for f in tests.json progress.md; do
    [[ -f "$f" ]] || continue
    if ! git diff --quiet -- "$f" 2>/dev/null; then
      housekeeping_files+=("$f")
    fi
  done
  if (( ${#housekeeping_files[@]} > 0 )); then
    git add -- "${housekeeping_files[@]}" 2>/dev/null || true
    if git commit --no-verify -m "chore(ralph): iter-${iter} housekeeping (summary+progress)" >/dev/null 2>&1; then
      echo "[post-gate] 하우스키핑 커밋: ${housekeeping_files[*]}"
    else
      echo "[post-gate] WARN: 하우스키핑 커밋 실패 → git checkout으로 복원 시도"
      # 커밋 실패 시 변경사항을 되돌려서 다음 pre-gate 차단 방지
      git checkout -- "${housekeeping_files[@]}" 2>/dev/null || true
      echo "[post-gate] 하우스키핑 파일 복원 완료 (summary/progress 미반영)"
    fi
  fi

  echo "[post-gate] OK"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  post_gate_run "${1:-manual}" "${2:-0}"
fi
