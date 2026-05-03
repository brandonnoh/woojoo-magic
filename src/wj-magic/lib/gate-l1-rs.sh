#!/usr/bin/env bash
# gate-l1-rs.sh — Rust L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_rs() {
  local _files="$1"
  local _rs_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.rs) ;; *) continue ;; esac
    case "$f" in *target/*) continue ;; esac
    [[ -f "$f" ]] || continue
    _rs_files="${_rs_files}${f}"$'\n'
  done <<< "$_files"

  _rs_files="$(echo "$_rs_files" | sed '/^$/d')"
  [[ -n "$_rs_files" ]] || return 0

  local _rs_fail=0
  local _rs_messages=""

  # 1) 500줄 초과
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 500 )); then
      _rs_messages="${_rs_messages}  500줄 초과: ${f} (${_lines}줄)"$'\n'
      _rs_fail=1
    fi
  done <<< "$_rs_files"

  # 2) unwrap() (테스트 외)
  local _unwrap
  _unwrap=$(xargs -d '\n' grep -HnE "$WJ_RS_UNWRAP" 2>/dev/null <<< "$_rs_files" | grep -v '#\[cfg(test)\]' | grep -v '#\[test\]' | grep -v 'tests/' || true)
  if [[ -n "$_unwrap" ]]; then
    _rs_messages="${_rs_messages}  unwrap() 감지 (테스트 외):"$'\n'
    _rs_messages="${_rs_messages}$(echo "$_unwrap" | head -5 | sed 's/^/    /')"$'\n'
    _rs_fail=1
  fi

  # 3) unsafe 블록 (경고만, fail 아님)
  local _unsafe
  _unsafe=$(xargs -d '\n' grep -HnE "$WJ_RS_UNSAFE" 2>/dev/null <<< "$_rs_files" || true)
  if [[ -n "$_unsafe" ]]; then
    _rs_messages="${_rs_messages}  unsafe 블록 감지 (사유 주석 확인 필요):"$'\n'
    _rs_messages="${_rs_messages}$(echo "$_unsafe" | head -5 | sed 's/^/    /')"$'\n'
    # unsafe는 경고만 (fail 아님)
  fi

  if (( _rs_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Rust 정적 감사 실패:"$'\n'"${_rs_messages}"$'\n'
    _total_fail=1
  fi
}
