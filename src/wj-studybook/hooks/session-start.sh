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

# 프로필이 이미 있으면 현황 알림 출력 후 종료
if [ -f "$_config_file" ]; then
  _active=$(grep -E '^\s*active_profile\s*:' "$_config_file" 2>/dev/null \
    | awk -F: '{gsub(/[[:space:]]/, "", $2); print $2}' | head -1)
  if [ -n "$_active" ] && [ "$_active" != "null" ] && [ "$_active" != '""' ]; then
    # inbox 카운트
    _inbox_count=0
    if [ -d "${_config_dir}/inbox" ]; then
      _inbox_count=$(find "${_config_dir}/inbox" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
    fi

    # quarantine 카운트
    _quarantine_count=0
    if [ -d "${_config_dir}/quarantine" ]; then
      _quarantine_count=$(find "${_config_dir}/quarantine" -maxdepth 1 -name "*.md" | wc -l | tr -d ' ')
    fi

    # 알림 강도 결정 (inbox 10개 미만이면 조용히)
    [ "$_inbox_count" -lt 10 ] && exit 0

    # 알림 출력
    if [ "$_inbox_count" -ge 30 ]; then
      _urgency="📬 inbox가 많이 쌓였어요 (세션 종료 시 자동 발간됩니다)"
    else
      _urgency="📚 wj-studybook 현황"
    fi

    # Claude에게 사용자에게 전달하도록 지시
    echo "IMPORTANT: 세션 시작 시 아래 wj-studybook 알림을 사용자에게 첫 응답에서 반드시 보여주세요:"
    echo ""
    echo "$_urgency"
    echo "  inbox        ${_inbox_count}개 (미분류)"
    [ "$_quarantine_count" -gt 0 ] && echo "  quarantine   ${_quarantine_count}개 (검토 대기)"
    echo ""
    echo "  세션이 끝나면 백그라운드에서 토픽별 쪽 페이지로 자동 발간됩니다."
    echo "  즉시 처리하려면:  /wj-studybook:digest"
    echo ""
    exit 0
  fi
fi

# 프로필 없음 → 온보딩 안내
cat <<'BANNER'
╭─────────────────────────────────────────────────────╮
│  📚 wj-studybook — 처음 오셨군요!                      │
│                                                       │
│  Claude와 대화하면 학습 내용이 자동으로 저장되고,           │
│  세션이 끝날 때 토픽별 쪽 페이지로 자동 발간됩니다.            │
│                                                       │
│  시작하려면 아래 커맨드를 실행하세요:                       │
│                                                       │
│    /wj-studybook:config init                          │
│                                                       │
│  전체 커맨드 목록:                                      │
│    /wj-studybook:help                                 │
╰─────────────────────────────────────────────────────╯
BANNER
