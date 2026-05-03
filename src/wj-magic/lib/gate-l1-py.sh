#!/usr/bin/env bash
# gate-l1-py.sh — Python L1 정적 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_py() {
  local _files="$1"
  local _py_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.py) ;; *) continue ;; esac
    case "$f" in *__pycache__*|*.pyc|*node_modules*|*dist/*|*venv/*|*.venv/*) continue ;; esac
    [[ -f "$f" ]] || continue
    _py_files="${_py_files}${f}"$'\n'
  done <<< "$_files"

  _py_files="$(echo "$_py_files" | sed '/^$/d')"
  [[ -n "$_py_files" ]] || return 0

  local _py_fail=0
  local _py_messages=""

  # 1) 600줄 초과 (hard limit)
  while IFS= read -r f; do
    local _lines
    _lines=$(wc -l < "$f" | tr -d ' ')
    if (( _lines > 600 )); then
      _py_messages="${_py_messages}  600줄 초과: ${f} (${_lines}줄)"$'\n'
      _py_fail=1
    fi
  done <<< "$_py_files"

  # 2) Any 사용 금지
  local _any_py
  _any_py=$(xargs -d '\n' grep -HnE "$WJ_PY_ANY" 2>/dev/null <<< "$_py_files" | grep -v '# type:' || true)
  if [[ -n "$_any_py" ]]; then
    _py_messages="${_py_messages}  Any 타입 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_any_py" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi

  # 3) bare except / silent except
  local _bare _silent _pass_after
  _bare=$(xargs -d '\n' grep -HnE "$WJ_PY_BARE_EXCEPT" 2>/dev/null <<< "$_py_files" || true)
  _silent=$(xargs -d '\n' grep -HnE "$WJ_PY_SILENT_EXCEPT" 2>/dev/null <<< "$_py_files" || true)
  _pass_after=""
  if [[ -n "$_silent" ]]; then
    _pass_after=$(xargs -d '\n' grep -HnE 'except.*:' -A1 2>/dev/null <<< "$_py_files" | grep -E '^\s+pass\s*$' || true)
  fi
  if [[ -n "$_bare" ]]; then
    _py_messages="${_py_messages}  bare except: 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_bare" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi
  if [[ -n "$_pass_after" ]]; then
    _py_messages="${_py_messages}  except + pass (silent catch) 감지"$'\n'
    _py_fail=1
  fi

  # 4) type: ignore (사유 없는)
  local _ignore
  _ignore=$(xargs -d '\n' grep -HnE "$WJ_PY_TYPE_IGNORE" 2>/dev/null <<< "$_py_files" || true)
  if [[ -n "$_ignore" ]]; then
    _py_messages="${_py_messages}  type: ignore (사유 없음) 감지:"$'\n'
    _py_messages="${_py_messages}$(echo "$_ignore" | head -5 | sed 's/^/    /')"$'\n'
    _py_fail=1
  fi

  if (( _py_fail == 1 )); then
    _total_messages="${_total_messages}[L1] Python 정적 감사 실패:"$'\n'"${_py_messages}"$'\n'
    _total_fail=1
  fi

  # CC 검사는 gate-l1-cc.sh에서 _py_files를 별도로 필터링하므로 여기서는 생략
}
