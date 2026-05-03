#!/usr/bin/env bash
# gate-l1-cc.sh — Cyclomatic Complexity L1 감사
# gate-l1.sh에서 source됨. _total_fail, _total_messages 전역 변수 공유.

_l1_run_cc() {
  local _files="$1"

  # Python CC 파일 필터
  local _py_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.py) ;; *) continue ;; esac
    case "$f" in *__pycache__*|*.pyc|*node_modules*|*dist/*|*venv/*|*.venv/*) continue ;; esac
    [[ -f "$f" ]] || continue
    _py_files="${_py_files}${f}"$'\n'
  done <<< "$_files"
  _py_files="$(echo "$_py_files" | sed '/^$/d')"

  # Go CC 파일 필터
  local _go_files=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in *.go) ;; *) continue ;; esac
    case "$f" in *vendor/*|*_test.go) continue ;; esac
    [[ -f "$f" ]] || continue
    _go_files="${_go_files}${f}"$'\n'
  done <<< "$_files"
  _go_files="$(echo "$_go_files" | sed '/^$/d')"

  # Python CC: ruff C901 (ruff + jq 설치 시만)
  if [[ -n "$_py_files" ]] && command -v ruff >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local _cc_violations=""
    while IFS= read -r f; do
      local _cc_out
      _cc_out=$(ruff check --select C901 --output-format json "$f" 2>/dev/null || true)
      if [[ -n "$_cc_out" && "$_cc_out" != "[]" ]]; then
        local _cc_parsed
        _cc_parsed=$(echo "$_cc_out" | jq -r '.[] | "\(.filename):\(.location.row) \(.message)"' 2>/dev/null || true)
        if [[ -n "$_cc_parsed" ]]; then
          _cc_violations="${_cc_violations}${_cc_parsed}"$'\n'
        fi
      fi
    done <<< "$_py_files"
    _cc_violations="$(echo "$_cc_violations" | sed '/^$/d')"
    if [[ -n "$_cc_violations" ]]; then
      local _cc_display
      _cc_display=$(echo "$_cc_violations" | head -5 | sed 's/^/  /')
      _total_messages="${_total_messages}[L1] Python Cyclomatic Complexity 초과:"$'\n'"${_cc_display}"$'\n'
      _total_fail=1
    fi
  fi

  # Go CC: gocyclo (설치 시만)
  if [[ -n "$_go_files" ]] && command -v gocyclo >/dev/null 2>&1; then
    local _go_cc
    _go_cc=$(xargs -d '\n' gocyclo -over 10 2>/dev/null <<< "$_go_files" || true)
    if [[ -n "$_go_cc" ]]; then
      local _go_cc_display
      _go_cc_display=$(echo "$_go_cc" | head -5 | sed 's/^/  /')
      _total_messages="${_total_messages}[L1] Go Cyclomatic Complexity 초과 (>10):"$'\n'"${_go_cc_display}"$'\n'
      _total_fail=1
    fi
  fi

  # TS/JS CC: skip (eslint complexity 규칙은 .eslintrc 의존성이 높아 L1에 부적합)
  # Rust CC: skip (cargo clippy cognitive_complexity는 L2에서 처리)
  # Swift CC: skip (swiftlint cyclomatic_complexity는 L2에서 처리)
  # Kotlin CC: skip (detekt CyclomaticComplexMethod는 L2에서 처리)
}
