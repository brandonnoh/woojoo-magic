#!/usr/bin/env bash
# gate-l1-ts.sh — TS/JS L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_ts() {
  local _files="$1"
  local _ts_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx) ;;
      *) continue ;;
    esac
    case "$f" in
      *.d.ts|*__tests__*|*.test.*|*.spec.*|*node_modules*|*dist/*) continue ;;
    esac
    [[ -f "$f" ]] || continue
    _ts_files="${_ts_files}${f}"$'\n'
  done <<< "$_files"

  _ts_files="$(echo "$_ts_files" | sed '/^$/d')"
  [[ -n "$_ts_files" ]] || return 0

  local _fail=0
  local _messages=""

  # 1) 300줄 초과
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 300 )); then
      _messages="${_messages}  300줄 초과: ${f} (${_lines}줄)"$'\n'
      _fail=1
    fi
  done <<< "$_ts_files"

  # 2) any 금지
  local _any_hits
  _any_hits=$(grep -HnE "$WJ_TS_ANY" $(echo "$_ts_files") 2>/dev/null | grep -v '// @ts-' || true)
  if [[ -n "$_any_hits" ]]; then
    _messages="${_messages}  any 타입 감지:"$'\n'
    _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
    _fail=1
  fi

  # 3) non-null assertion
  local _nn_hits
  _nn_hits=$(grep -HnE "$WJ_TS_NONNULL" $(echo "$_ts_files") 2>/dev/null || true)
  if [[ -n "$_nn_hits" ]]; then
    _messages="${_messages}  non-null assertion(!.) 감지:"$'\n'
    _messages="${_messages}$(echo "$_nn_hits" | head -5 | sed 's/^/    /')"$'\n'
    _fail=1
  fi

  # 4) silent catch
  local _sc_hits
  _sc_hits=$(grep -HnE "$WJ_TS_SILENT_CATCH" $(echo "$_ts_files") 2>/dev/null || true)
  if [[ -n "$_sc_hits" ]]; then
    _messages="${_messages}  silent catch {} 감지:"$'\n'
    _messages="${_messages}$(echo "$_sc_hits" | head -5 | sed 's/^/    /')"$'\n'
    _fail=1
  fi

  # 5) eslint-disable no-explicit-any
  local _ed_hits
  _ed_hits=$(grep -Hn "$WJ_TS_ESLINT_ANY" $(echo "$_ts_files") 2>/dev/null || true)
  if [[ -n "$_ed_hits" ]]; then
    _messages="${_messages}  eslint-disable no-explicit-any 감지:"$'\n'
    _messages="${_messages}$(echo "$_ed_hits" | head -5 | sed 's/^/    /')"$'\n'
    _fail=1
  fi

  if (( _fail == 1 )); then
    _total_messages="${_total_messages}[L1] TS/JS 정적 감사 실패:"$'\n'"${_messages}"$'\n'
    _total_fail=1
  fi
}
