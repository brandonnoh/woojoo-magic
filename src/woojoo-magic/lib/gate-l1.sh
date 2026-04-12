#!/usr/bin/env bash
# gate-l1.sh — L1 정적 감사 (grep only, <1초)
# 인자: 파일 목록 (stdin, 한 줄에 하나) 또는 $1로 단일 파일
# 출력: 실패 시 위반 내역을 stdout에 출력하고 exit 1
# 성공 시 exit 0
set -euo pipefail

_files=""
if [[ $# -gt 0 && -f "$1" ]]; then
  _files="$1"
else
  _files="$(cat || true)"
fi

[[ -n "$_files" ]] || exit 0

# TS/JS 파일만 필터
_ts_files=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *.ts|*.tsx|*.mts|*.cts|*.js|*.jsx) ;;
    *) continue ;;
  esac
  # 제외: .d.ts, __tests__, *.test.*, *.spec.*, node_modules, dist
  case "$f" in
    *.d.ts|*__tests__*|*.test.*|*.spec.*|*node_modules*|*dist/*) continue ;;
  esac
  [[ -f "$f" ]] || continue
  _ts_files="${_ts_files}${f}"$'\n'
done <<< "$_files"

_ts_files="$(echo "$_ts_files" | sed '/^$/d')"
[[ -n "$_ts_files" ]] || exit 0

_fail=0
_messages=""

# 1) 300줄 초과
while IFS= read -r f; do
  _lines=$(wc -l < "$f" | tr -d ' ')
  if (( _lines > 300 )); then
    _messages="${_messages}  300줄 초과: ${f} (${_lines}줄)"$'\n'
    _fail=1
  fi
done <<< "$_ts_files"

# 2) any 금지
_any_hits=$(echo "$_ts_files" | xargs grep -HnE ':\s*any\b|<any>|\bas\s+any\b' 2>/dev/null | grep -v '// @ts-' || true)
if [[ -n "$_any_hits" ]]; then
  _messages="${_messages}  any 타입 감지:"$'\n'
  _messages="${_messages}$(echo "$_any_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 3) non-null assertion
_nn_hits=$(echo "$_ts_files" | xargs grep -HnE '[A-Za-z0-9_\)\]]!\.' 2>/dev/null || true)
if [[ -n "$_nn_hits" ]]; then
  _messages="${_messages}  non-null assertion(!.) 감지:"$'\n'
  _messages="${_messages}$(echo "$_nn_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 4) silent catch
_sc_hits=$(echo "$_ts_files" | xargs grep -HnE 'catch\s*\(\s*\w*\s*\)\s*\{\s*\}' 2>/dev/null || true)
if [[ -n "$_sc_hits" ]]; then
  _messages="${_messages}  silent catch {} 감지:"$'\n'
  _messages="${_messages}$(echo "$_sc_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

# 5) eslint-disable no-explicit-any
_ed_hits=$(echo "$_ts_files" | xargs grep -Hn 'eslint-disable.*no-explicit-any' 2>/dev/null || true)
if [[ -n "$_ed_hits" ]]; then
  _messages="${_messages}  eslint-disable no-explicit-any 감지:"$'\n'
  _messages="${_messages}$(echo "$_ed_hits" | head -5 | sed 's/^/    /')"$'\n'
  _fail=1
fi

if (( _fail == 1 )); then
  echo "[L1] 정적 감사 실패:"
  echo "$_messages"
  exit 1
fi

echo "[L1] OK"
exit 0
