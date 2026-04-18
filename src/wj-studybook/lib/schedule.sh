#!/usr/bin/env bash
# schedule.sh — wj-studybook launchd 스케줄 관리 (macOS 전용)
# Usage:
#   source src/wj-studybook/lib/schedule.sh
#   schedule_install   # plist 생성 + launchd 등록
#   schedule_uninstall # plist 제거
#   schedule_status    # 등록 상태 확인
#
# 외부 의존: config-helpers.sh (같은 폴더)
# 주의: source 전용. set -euo pipefail은 호출자 책임.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _SC_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _SC_SRC="${(%):-%x}"
else
  _SC_SRC="$0"
fi
_SC_DIR="$(cd "$(dirname "$_SC_SRC")" && pwd)"
# shellcheck source=/dev/null
. "${_SC_DIR}/config-helpers.sh"

# ── 상수 ─────────────────────────────────────────────────────────
_SC_LABEL="com.wj-studybook.weekly"
_SC_PLIST_DIR="${HOME}/Library/LaunchAgents"
_SC_PLIST_PATH="${_SC_PLIST_DIR}/${_SC_LABEL}.plist"

# ── stderr ───────────────────────────────────────────────────────
_sc_err() {
  echo "schedule.sh: $*" >&2
}

# ── macOS 검증 ───────────────────────────────────────────────────
_sc_require_macos() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "이 기능은 macOS 전용입니다."
    return 1
  fi
  return 0
}

# ── claude 바이너리 경로 탐색 ────────────────────────────────────
_sc_find_claude() {
  _claude_path=""
  # type -P: alias 무시하고 실제 경로만 반환
  if _claude_path=$(type -P claude 2>/dev/null); then
    printf '%s' "$_claude_path"
    return 0
  fi
  # 일반적인 설치 경로 폴백
  for _p in \
    "${HOME}/.local/bin/claude" \
    "/usr/local/bin/claude" \
    "/opt/homebrew/bin/claude"; do
    if [ -x "$_p" ]; then
      printf '%s' "$_p"
      return 0
    fi
  done
  _sc_err "claude 바이너리를 찾을 수 없습니다"
  return 1
}

# ── plist 생성 ───────────────────────────────────────────────────
_sc_emit_plist() {
  _claude_bin="$1"
  _log_dir="$(get_studybook_dir)/logs"
  _log_path="${_log_dir}/weekly-publish.log"
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${_SC_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${_claude_bin}</string>
    <string>-p</string>
    <string>/wj-studybook:publish weekly</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>2</integer>
    <key>Hour</key>
    <integer>0</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${_log_path}</string>
  <key>StandardErrorPath</key>
  <string>${_log_path}</string>
  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
PLIST
}

# ── 공개 함수 ────────────────────────────────────────────────────

# schedule_install — plist 생성 + launchd 등록
schedule_install() {
  set -u
  _sc_require_macos || return 1

  _claude_bin=$(_sc_find_claude) || return 1
  _log_dir="$(get_studybook_dir)/logs"
  mkdir -p "$_log_dir" "$_SC_PLIST_DIR"

  # 기존 등록 해제 (재설치 대응)
  if launchctl list "$_SC_LABEL" >/dev/null 2>&1; then
    launchctl unload "$_SC_PLIST_PATH" 2>/dev/null || true
  fi

  _sc_emit_plist "$_claude_bin" > "$_SC_PLIST_PATH"
  launchctl load "$_SC_PLIST_PATH"

  echo "launchd 스케줄 등록 완료"
  echo "  plist: $_SC_PLIST_PATH"
  echo "  실행: 매주 월요일 09:00 KST (UTC 00:00)"
  echo "  로그: ${_log_dir}/weekly-publish.log"
  return 0
}

# schedule_uninstall — launchd 해제 + plist 삭제
schedule_uninstall() {
  set -u
  _sc_require_macos || return 1

  if [ ! -f "$_SC_PLIST_PATH" ]; then
    echo "등록된 스케줄이 없습니다."
    return 0
  fi

  launchctl unload "$_SC_PLIST_PATH" 2>/dev/null || true
  rm -f "$_SC_PLIST_PATH"
  echo "launchd 스케줄 제거 완료"
  return 0
}

# schedule_status — 등록 상태 확인
schedule_status() {
  set -u
  _sc_require_macos || return 1

  if [ ! -f "$_SC_PLIST_PATH" ]; then
    echo "상태: 미등록"
    echo "  plist 파일 없음: $_SC_PLIST_PATH"
    return 0
  fi

  echo "plist: $_SC_PLIST_PATH"
  if launchctl list "$_SC_LABEL" >/dev/null 2>&1; then
    echo "상태: 활성 (launchd 등록됨)"
    launchctl list "$_SC_LABEL" 2>/dev/null \
      | head -5
  else
    echo "상태: 비활성 (plist 존재하나 launchd 미등록)"
  fi
  return 0
}
