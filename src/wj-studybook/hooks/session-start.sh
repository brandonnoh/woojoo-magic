#!/usr/bin/env bash
# session-start.sh — 세션 시작 시 프로필 초기화 안내
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "${_plugin_root}/lib/config-helpers.sh"

_config_dir="$(get_studybook_dir)"
_config_file="${_config_dir}/config.yaml"

# 일시정지 상태 안내
if [ -f "$(get_studybook_dir)/.paused" ]; then
  echo "⏸ wj-studybook: 자동 수집 일시정지 중 — 재개하려면 /wj-studybook:resume"
fi

# 프로필이 이미 있으면 조용히 종료
if [ -f "$_config_file" ]; then
  _active=$(grep -E '^\s*active_profile\s*:' "$_config_file" 2>/dev/null \
    | awk -F: '{gsub(/[[:space:]]/, "", $2); print $2}' | head -1)
  if [ -n "$_active" ] && [ "$_active" != "null" ] && [ "$_active" != '""' ]; then
    exit 0
  fi
fi

# 프로필 없음 → 온보딩 안내
cat <<'BANNER'
╭─────────────────────────────────────────────────────╮
│  📚 wj-studybook — 처음 오셨군요!                      │
│                                                       │
│  Claude와 대화하면 학습 내용이 자동으로 저장되고,           │
│  정기적으로 마크다운 책으로 만들어지는 플러그인입니다.         │
│                                                       │
│  시작하려면 아래 커맨드를 실행하세요:                       │
│                                                       │
│    /wj-studybook:config init                          │
│                                                       │
│  전체 커맨드 목록:                                      │
│    /wj-studybook:help                                 │
╰─────────────────────────────────────────────────────╯
BANNER
