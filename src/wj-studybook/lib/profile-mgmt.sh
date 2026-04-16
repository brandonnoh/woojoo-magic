#!/usr/bin/env bash
# profile-mgmt.sh — wj-studybook 프로필 관리 (list/use/new/delete)
# Usage:
#   source src/wj-studybook/lib/profile-mgmt.sh
#   profile_list
#   profile_use woojoo
#   profile_new
#   profile_delete woojoo --keep-books
#   profile_delete woojoo --purge
#
# 외부 의존: config-helpers.sh, config-wizard.sh (같은 폴더)
# 주의: source 전용. set -euo pipefail은 호출자 책임.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _PM_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _PM_SRC="${(%):-%x}"
else
  _PM_SRC="$0"
fi
_PM_DIR="$(cd "$(dirname "$_PM_SRC")" && pwd)"
# shellcheck source=/dev/null
. "${_PM_DIR}/config-helpers.sh"
# shellcheck source=/dev/null
. "${_PM_DIR}/config-wizard.sh"

# ── stderr ───────────────────────────────────────────────────────
_pm_err() {
  echo "profile-mgmt.sh: $*" >&2
}

# ── 공개 함수 ────────────────────────────────────────────────────

# profile_list — 프로필 목록 출력 (활성 프로필에 ★ 표시)
# stdout으로 한 줄당 하나의 프로필 출력. 비어있으면 안내 메시지.
profile_list() {
  set -u
  _active=$(get_active_profile)
  _names=$(list_profile_names)
  if [ -z "$_names" ]; then
    echo "프로필 없음 — /wj:studybook config init 으로 생성하세요"
    return 0
  fi
  printf '%s\n' "$_names" | while IFS= read -r _n; do
    [ -z "$_n" ] && continue
    if [ "$_n" = "$_active" ]; then
      printf '★ %s\n' "$_n"
    else
      printf '  %s\n' "$_n"
    fi
  done
}

# profile_use <name> — active_profile 갱신 (wizard_set_active 위임)
profile_use() {
  set -u
  _name="${1:-}"
  if [ -z "$_name" ]; then
    _pm_err "사용법: profile_use <name>"
    return 1
  fi
  if ! profile_exists "$_name"; then
    _pm_err "존재하지 않는 프로필: $_name"
    return 1
  fi
  wizard_set_active "$_name" || return 1
  echo "활성 프로필: $_name"
  return 0
}

# profile_new — wizard_main 위임 (인터랙티브 신규 생성)
profile_new() {
  set -u
  wizard_main
}

# profile_delete <name> [--keep-books|--purge]
# yaml 삭제. mode=--purge면 books/<name>/ 폴더도 삭제.
# mode 미지정 시 기본 --keep-books.
profile_delete() {
  set -u
  _name="${1:-}"
  _mode="${2:---keep-books}"
  if [ -z "$_name" ]; then
    _pm_err "사용법: profile_delete <name> [--keep-books|--purge]"
    return 1
  fi
  case "$_mode" in
    --keep-books|--purge) ;;
    *)
      _pm_err "지원하지 않는 옵션: $_mode (허용: --keep-books|--purge)"
      return 1
      ;;
  esac
  if ! profile_exists "$_name"; then
    _pm_err "존재하지 않는 프로필: $_name"
    return 1
  fi

  _yaml="$(get_profiles_dir)/${_name}.yaml"
  rm -f "$_yaml" || {
    _pm_err "yaml 삭제 실패: $_yaml"
    return 1
  }

  # active_profile이 삭제된 프로필이면 키 라인 제거
  _active=$(get_active_profile)
  if [ "$_active" = "$_name" ]; then
    _cfg=$(get_config_path)
    if [ -f "$_cfg" ]; then
      _tmp="${_cfg}.tmp.$$"
      awk '/^active_profile:/ { next } { print }' "$_cfg" > "$_tmp" \
        && mv "$_tmp" "$_cfg"
    fi
  fi

  if [ "$_mode" = "--purge" ]; then
    _book_dir="$(get_books_dir)/${_name}"
    if [ -d "$_book_dir" ]; then
      rm -rf "$_book_dir" || {
        _pm_err "books 디렉토리 삭제 실패: $_book_dir"
        return 1
      }
    fi
    echo "삭제 완료(purge): $_name"
  else
    echo "삭제 완료(yaml만): $_name (books/${_name}/ 보존)"
  fi
  return 0
}
