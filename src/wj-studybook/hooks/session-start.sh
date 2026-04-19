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

    # 마지막 publish 날짜 (books/<profile>/weekly or monthly 중 가장 최근 파일)
    _last_publish=""
    _books_dir="${_config_dir}/books/${_active}"
    if [ -d "$_books_dir" ]; then
      _last_file=$(find "$_books_dir" -name "*.md" | sort | tail -1)
      if [ -n "$_last_file" ]; then
        _last_publish=$(basename "$_last_file" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
      fi
    fi

    # 알림 강도 결정 (inbox 10개 미만이면 조용히)
    [ "$_inbox_count" -lt 10 ] && exit 0

    # 마지막 publish 경과일 계산
    _days_since=""
    if [ -n "$_last_publish" ]; then
      _pub_epoch=$(date -j -f "%Y-%m-%d" "$_last_publish" "+%s" 2>/dev/null \
        || date -d "$_last_publish" "+%s" 2>/dev/null || true)
      _now_epoch=$(date "+%s")
      if [ -n "$_pub_epoch" ]; then
        _days_since=$(( (_now_epoch - _pub_epoch) / 86400 ))
      fi
    fi

    # 알림 출력
    if [ "$_inbox_count" -ge 30 ]; then
      _urgency="📬 inbox가 많이 쌓였어요"
    else
      _urgency="📚 wj-studybook 현황"
    fi

    # Claude에게 사용자에게 전달하도록 지시
    echo "IMPORTANT: 세션 시작 시 아래 wj-studybook 알림을 사용자에게 첫 응답에서 반드시 보여주세요:"
    echo ""
    echo "$_urgency"
    echo "  inbox        ${_inbox_count}개"
    [ "$_quarantine_count" -gt 0 ] && echo "  quarantine   ${_quarantine_count}개 (publish 때 같이 검토)"
    if [ -n "$_days_since" ]; then
      echo "  마지막 publish  ${_days_since}일 전"
    else
      echo "  마지막 publish  없음"
    fi
    echo ""
    echo "  → /wj-studybook:publish weekly"
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
