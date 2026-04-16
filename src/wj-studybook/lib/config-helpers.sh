#!/usr/bin/env bash
# config-helpers.sh — wj-studybook 공통 경로/설정 헬퍼
# Usage:
#   source src/wj-studybook/lib/config-helpers.sh
#   dir=$(get_studybook_dir)
#   active=$(get_active_profile)
#
# 외부 의존: 없음 (POSIX 도구만 사용)
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       STUDYBOOK_HOME 환경변수로 베이스 디렉토리 오버라이드 가능 (테스트용).

# ── stderr ───────────────────────────────────────────────────────
_ch_err() {
  echo "config-helpers.sh: $*" >&2
}

# ── 경로 함수 ────────────────────────────────────────────────────

# get_studybook_dir — 베이스 디렉토리 (STUDYBOOK_HOME 우선, 없으면 ~/.studybook)
get_studybook_dir() {
  set -u
  if [ -n "${STUDYBOOK_HOME:-}" ]; then
    printf '%s\n' "$STUDYBOOK_HOME"
  else
    printf '%s\n' "$HOME/.studybook"
  fi
}

# get_config_path — config.yaml 경로
get_config_path() {
  set -u
  printf '%s/config.yaml\n' "$(get_studybook_dir)"
}

# get_profiles_dir — profiles 디렉토리 경로
get_profiles_dir() {
  set -u
  printf '%s/profiles\n' "$(get_studybook_dir)"
}

# get_books_dir — books 디렉토리 경로
get_books_dir() {
  set -u
  printf '%s/books\n' "$(get_studybook_dir)"
}

# ── 프로필 조회 ──────────────────────────────────────────────────

# list_profile_names — profiles/*.yaml 파일명(확장자 제외) 줄단위 출력
list_profile_names() {
  set -u
  _dir=$(get_profiles_dir)
  [ -d "$_dir" ] || return 0
  # ls 대신 find 사용 (특수문자/빈디렉토리 안전)
  find "$_dir" -maxdepth 1 -type f -name '*.yaml' 2>/dev/null \
    | while IFS= read -r _f; do
        _base=$(basename "$_f" .yaml)
        printf '%s\n' "$_base"
      done \
    | sort
}

# profile_exists <name> — 존재하면 0, 없으면 1
profile_exists() {
  set -u
  _name="${1:-}"
  if [ -z "$_name" ]; then
    return 1
  fi
  _file="$(get_profiles_dir)/${_name}.yaml"
  [ -f "$_file" ]
}

# get_active_profile — config.yaml에서 active_profile 값 출력 (없으면 빈 문자열)
get_active_profile() {
  set -u
  _cfg=$(get_config_path)
  [ -f "$_cfg" ] || { printf '\n'; return 0; }
  awk '
    /^active_profile:[[:space:]]*/ {
      sub("^active_profile:[[:space:]]*", "")
      sub("[[:space:]]+$", "")
      print
      exit
    }
  ' "$_cfg"
}
