#!/usr/bin/env bash
# gate-l1-kt.sh — Kotlin L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_kt() {
  local _files="$1"
  local _kt_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.kt|*.kts) ;; *) continue ;; esac
    case "$f" in *build/*|*generated/*) continue ;; esac
    [[ -f "$f" ]] || continue
    _kt_files="${_kt_files}${f}"$'\n'
  done <<< "$_files"

  _kt_files="$(echo "$_kt_files" | sed '/^$/d')"
  [[ -n "$_kt_files" ]] || return 0

  local _kt_fail=0
  local _kt_messages=""

  # 1) 400줄 초과
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 400 )); then
      _kt_messages="${_kt_messages}  400줄 초과: ${f} (${_lines}줄)"$'\n'
      _kt_fail=1
    fi
  done <<< "$_kt_files"

  # 2) !! (force unwrap)
  local _bangbang
  _bangbang=$(xargs -d '\n' grep -HnE "$WJ_KT_BANGBANG" 2>/dev/null <<< "$_kt_files" || true)
  if [[ -n "$_bangbang" ]]; then
    _kt_messages="${_kt_messages}  !! (force unwrap) 감지:"$'\n'
    _kt_messages="${_kt_messages}$(echo "$_bangbang" | head -5 | sed 's/^/    /')"$'\n'
    _kt_fail=1
  fi

  # 3) GlobalScope
  local _globalscope
  _globalscope=$(xargs -d '\n' grep -HnE "$WJ_KT_GLOBALSCOPE" 2>/dev/null <<< "$_kt_files" || true)
  if [[ -n "$_globalscope" ]]; then
    _kt_messages="${_kt_messages}  GlobalScope 감지 — structured concurrency 사용:"$'\n'
    _kt_messages="${_kt_messages}$(echo "$_globalscope" | head -5 | sed 's/^/    /')"$'\n'
    _kt_fail=1
  fi

  if (( _kt_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Kotlin 정적 감사 실패:"$'\n'"${_kt_messages}"$'\n'
    _total_fail=1
  fi
}
