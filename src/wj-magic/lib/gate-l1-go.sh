#!/usr/bin/env bash
# gate-l1-go.sh — Go L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_go() {
  local _files="$1"
  local _go_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.go) ;; *) continue ;; esac
    case "$f" in *vendor/*|*_test.go) continue ;; esac
    [[ -f "$f" ]] || continue
    _go_files="${_go_files}${f}"$'\n'
  done <<< "$_files"

  _go_files="$(echo "$_go_files" | sed '/^$/d')"
  [[ -n "$_go_files" ]] || return 0

  local _go_fail=0
  local _go_messages=""

  # 1) 500줄 초과
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 500 )); then
      _go_messages="${_go_messages}  500줄 초과: ${f} (${_lines}줄)"$'\n'
      _go_fail=1
    fi
  done <<< "$_go_files"

  # 2) _ = err (에러 무시)
  local _ignored_err
  _ignored_err=$(xargs -d '\n' grep -HnE "$WJ_GO_IGNORED_ERR" 2>/dev/null <<< "$_go_files" || true)
  if [[ -n "$_ignored_err" ]]; then
    _go_messages="${_go_messages}  _ = err (에러 무시) 감지:"$'\n'
    _go_messages="${_go_messages}$(echo "$_ignored_err" | head -5 | sed 's/^/    /')"$'\n'
    _go_fail=1
  fi

  # 3) interface{} 감지
  local _iface
  _iface=$(xargs -d '\n' grep -HnE "$WJ_GO_EMPTY_IFACE" 2>/dev/null <<< "$_go_files" || true)
  if [[ -n "$_iface" ]]; then
    _go_messages="${_go_messages}  interface{} 감지 — 제네릭 또는 구체 타입 사용:"$'\n'
    _go_messages="${_go_messages}$(echo "$_iface" | head -5 | sed 's/^/    /')"$'\n'
    _go_fail=1
  fi

  if (( _go_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Go 정적 감사 실패:"$'\n'"${_go_messages}"$'\n'
    _total_fail=1
  fi
}
