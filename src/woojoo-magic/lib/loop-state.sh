#!/usr/bin/env bash
# loop-state.sh — .dev/state/loop.state 관리
# Usage:
#   loop-state.sh start [task-id]   → active=true
#   loop-state.sh stop [reason]     → active=false
#   loop-state.sh status            → JSON 출력
#   loop-state.sh get <field>       → 특정 필드 값
#   loop-state.sh inc-failure       → consecutive_failures++
#   loop-state.sh reset-failure     → consecutive_failures=0
#   loop-state.sh inc-iter          → iteration++
set -euo pipefail

_state_dir="${CLAUDE_PROJECT_DIR:-.}/.dev/state"
_state_file="${_state_dir}/loop.state"
mkdir -p "$_state_dir"

_ensure_jq() {
  command -v jq >/dev/null 2>&1 || { echo "jq 필요"; exit 1; }
}

_read_state() {
  if [[ -f "$_state_file" ]]; then
    cat "$_state_file"
  else
    echo '{"active":false,"started_at":null,"current_task":null,"iteration":0,"consecutive_failures":0,"last_gate_result":null,"stop_reason":null}'
  fi
}

_write_state() {
  echo "$1" > "$_state_file"
}

_ensure_jq

case "${1:-status}" in
  start)
    _task="${2:-}"
    _timeout="${3:-0}"
    _now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    _state=$(_read_state | jq --arg t "$_task" --arg n "$_now" --argjson tm "$_timeout" \
      '.active=true | .started_at=$n | .current_task=$t | .timeout_min=$tm | .iteration=0 | .consecutive_failures=0 | .last_gate_result=null | .stop_reason=null')
    _write_state "$_state"
    echo "$_state"
    ;;
  stop)
    _reason="${2:-manual}"
    _state=$(_read_state | jq --arg r "$_reason" '.active=false | .stop_reason=$r')
    _write_state "$_state"
    echo "$_state"
    ;;
  status)
    _read_state
    ;;
  get)
    _read_state | jq -r ".${2}" 2>/dev/null
    ;;
  inc-failure)
    _state=$(_read_state | jq '.consecutive_failures += 1')
    _write_state "$_state"
    echo "$_state"
    ;;
  reset-failure)
    _state=$(_read_state | jq '.consecutive_failures = 0')
    _write_state "$_state"
    ;;
  inc-iter)
    _state=$(_read_state | jq '.iteration += 1')
    _write_state "$_state"
    echo "$_state"
    ;;
  *)
    echo "Usage: loop-state.sh {start|stop|status|get|inc-failure|reset-failure|inc-iter}"
    exit 1
    ;;
esac
