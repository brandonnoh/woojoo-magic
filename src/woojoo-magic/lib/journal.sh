#!/usr/bin/env bash
# journal.sh — .dev/journal/YYYY-MM-DD.md에 턴 기록 append
# Usage: journal.sh <iter> <task_id> <gate_result> [note]
set -euo pipefail

_iter="${1:-0}"
_task="${2:-unknown}"
_gate="${3:-unknown}"
_note="${4:-}"

_journal_dir="${CLAUDE_PROJECT_DIR:-.}/.dev/journal"
mkdir -p "$_journal_dir"

_today=$(date +"%Y-%m-%d")
_time=$(date +"%H:%M:%S")
_journal_file="${_journal_dir}/${_today}.md"

# 파일이 없으면 헤더 생성
if [[ ! -f "$_journal_file" ]]; then
  echo "# Journal — ${_today}" > "$_journal_file"
  echo "" >> "$_journal_file"
fi

# 변경된 파일 목록
_changed=""
if command -v git >/dev/null 2>&1; then
  _changed=$(git diff --name-only HEAD 2>/dev/null | head -10 | sed 's/^/  - /' || true)
  if [[ -z "$_changed" ]]; then
    _changed=$(git diff --name-only 2>/dev/null | head -10 | sed 's/^/  - /' || true)
  fi
fi

{
  echo "## iter-${_iter} — ${_time}"
  echo "- task: ${_task}"
  echo "- gate: ${_gate}"
  if [[ -n "$_changed" ]]; then
    echo "- files:"
    echo "$_changed"
  fi
  if [[ -n "$_note" ]]; then
    echo "- note: ${_note}"
  fi
  echo ""
} >> "$_journal_file"

echo "[journal] ${_journal_file} 기록"
