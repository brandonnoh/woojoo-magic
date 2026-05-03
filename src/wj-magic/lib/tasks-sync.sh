#!/usr/bin/env bash
# tasks-sync.sh — .dev/tasks.json 읽기/검증/다음 task 선별
# Usage:
#   tasks-sync.sh validate            → 구조 검증
#   tasks-sync.sh next [current_id]   → 다음 eligible task id
#   tasks-sync.sh count               → done/total 카운트
set -euo pipefail

_tasks_file="${CLAUDE_PROJECT_DIR:-.}/.dev/tasks.json"

_ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "jq 필요"; exit 1; }
}

_ensure_jq

if [[ ! -f "$_tasks_file" ]]; then
  echo '{"error":"tasks.json 없음","path":"'"$_tasks_file"'"}'
  exit 1
fi

case "${1:-validate}" in
  validate)
    _feat_count=$(jq '.features | length' "$_tasks_file" 2>/dev/null || echo -1)
    if (( _feat_count < 0 )); then
      echo '{"valid":false,"error":"features 배열 없음 또는 JSON 파싱 실패"}'
      exit 1
    fi
    echo "{\"valid\":true,\"feature_count\":${_feat_count}}"
    ;;
  next)
    _current="${2:-}"
    _next=$(jq -r --arg cur "$_current" '
      [.features[] | select(.status == "pending" or .status == "in_progress") | select(.id != $cur)] |
      first | .id // empty
    ' "$_tasks_file" 2>/dev/null || true)
    if [[ -n "$_next" ]]; then
      echo "$_next"
    else
      echo ""
    fi
    ;;
  count)
    jq '{
      total: (.features | length),
      done: ([.features[] | select(.status == "done")] | length),
      in_progress: ([.features[] | select(.status == "in_progress")] | length),
      pending: ([.features[] | select(.status == "pending")] | length)
    }' "$_tasks_file" 2>/dev/null
    ;;
  *)
    echo "Usage: tasks-sync.sh {validate|next|count}"
    exit 1
    ;;
esac
