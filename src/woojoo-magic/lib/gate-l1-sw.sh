#!/usr/bin/env bash
# gate-l1-sw.sh — Swift L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_sw() {
  local _files="$1"
  local _swift_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.swift) ;; *) continue ;; esac
    case "$f" in *.build/*|*DerivedData/*) continue ;; esac
    [[ -f "$f" ]] || continue
    _swift_files="${_swift_files}${f}"$'\n'
  done <<< "$_files"

  _swift_files="$(echo "$_swift_files" | sed '/^$/d')"
  [[ -n "$_swift_files" ]] || return 0

  local _sw_fail=0
  local _sw_messages=""

  # 1) 400줄 초과
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 400 )); then
      _sw_messages="${_sw_messages}  400줄 초과: ${f} (${_lines}줄)"$'\n'
      _sw_fail=1
    fi
  done <<< "$_swift_files"

  # 2) force unwrap (!)
  local _force
  _force=$(xargs -d '\n' grep -HnE "$WJ_SW_FORCE_UNWRAP" 2>/dev/null <<< "$_swift_files" | grep -v 'IBOutlet' | grep -v '// force-unwrap:' || true)
  if [[ -n "$_force" ]]; then
    _sw_messages="${_sw_messages}  force unwrap (!) 감지:"$'\n'
    _sw_messages="${_sw_messages}$(echo "$_force" | head -5 | sed 's/^/    /')"$'\n'
    _sw_fail=1
  fi

  # 3) try!
  local _tryforce
  _tryforce=$(xargs -d '\n' grep -HnE "$WJ_SW_TRY_FORCE" 2>/dev/null <<< "$_swift_files" || true)
  if [[ -n "$_tryforce" ]]; then
    _sw_messages="${_sw_messages}  try! 감지:"$'\n'
    _sw_messages="${_sw_messages}$(echo "$_tryforce" | head -5 | sed 's/^/    /')"$'\n'
    _sw_fail=1
  fi

  if (( _sw_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Swift 정적 감사 실패:"$'\n'"${_sw_messages}"$'\n'
    _total_fail=1
  fi
}
