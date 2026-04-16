#!/usr/bin/env bash
# config-set.sh — wj-studybook 설정 변경/표시 (show/set/edit)
# Usage:
#   source src/wj-studybook/lib/config-set.sh
#   config_show
#   config_set learner.level intermediate
#   config_edit
#
# 외부 의존: config-helpers.sh (같은 폴더). yq가 있으면 사용, 없으면 sed/awk fallback.
# 주의: source 전용. set -euo pipefail은 호출자 책임.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _CS_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _CS_SRC="${(%):-%x}"
else
  _CS_SRC="$0"
fi
_CS_DIR="$(cd "$(dirname "$_CS_SRC")" && pwd)"
# shellcheck source=/dev/null
. "${_CS_DIR}/config-helpers.sh"

# ── stderr ───────────────────────────────────────────────────────
_cs_err() {
  echo "config-set.sh: $*" >&2
}

# ── 내부 헬퍼 ────────────────────────────────────────────────────

# _cs_active_profile_yaml — 활성 프로필의 yaml 경로 (없으면 빈 문자열)
_cs_active_profile_yaml() {
  set -u
  _name=$(get_active_profile)
  [ -n "$_name" ] || { printf '\n'; return 0; }
  printf '%s/%s.yaml\n' "$(get_profiles_dir)" "$_name"
}

# _cs_has_yq — yq 가용성 (0=있음, 1=없음)
_cs_has_yq() {
  command -v yq >/dev/null 2>&1
}

# _cs_validate_key — 허용된 key.path 형식인지 검증 (영숫자/_/. 만)
_cs_validate_key() {
  _k="${1:-}"
  if [ -z "$_k" ]; then
    _cs_err "key.path가 비었습니다"
    return 1
  fi
  if ! printf '%s' "$_k" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$'; then
    _cs_err "잘못된 key.path 형식: '$_k' (허용: a.b.c)"
    return 1
  fi
  return 0
}

# _cs_set_with_yq <file> <key.path> <value>
_cs_set_with_yq() {
  _f="$1"; _k="$2"; _v="$3"
  # path 존재 검증 (없으면 yq가 null을 추가하므로 사전 차단)
  _exists=$(yq eval ".${_k}" "$_f" 2>/dev/null || printf 'null')
  if [ "$_exists" = "null" ]; then
    _cs_err "존재하지 않는 key.path: $_k"
    return 1
  fi
  yq eval ".${_k} = \"${_v}\"" -i "$_f" 2>/dev/null || {
    _cs_err "yq 갱신 실패: $_k=$_v"
    return 1
  }
  return 0
}

# _cs_set_with_sed <file> <key.path> <value>
# fallback: 단일 키만 지원. 중첩 키는 마지막 토큰으로 매칭.
_cs_set_with_sed() {
  _f="$1"; _k="$2"; _v="$3"
  _last=$(printf '%s' "$_k" | awk -F'.' '{print $NF}')
  # 매칭되는 라인이 있는지 확인
  if ! grep -qE "^[[:space:]]*${_last}:[[:space:]]" "$_f"; then
    _cs_err "존재하지 않는 key.path (sed fallback): $_k"
    return 1
  fi
  _tmp="${_f}.tmp.$$"
  awk -v key="$_last" -v val="$_v" '
    {
      if (match($0, "^([[:space:]]*)" key ":[[:space:]]")) {
        prefix = substr($0, RSTART, RLENGTH)
        print prefix val
      } else {
        print
      }
    }
  ' "$_f" > "$_tmp" && mv "$_tmp" "$_f"
  return 0
}

# ── 공개 함수 ────────────────────────────────────────────────────

# config_show — 전역 config.yaml + 활성 프로필 yaml dump
config_show() {
  set -u
  _cfg=$(get_config_path)
  echo "── config.yaml (${_cfg}) ──"
  if [ -f "$_cfg" ]; then
    cat "$_cfg"
  else
    echo "(없음 — /wj:studybook config init 으로 생성)"
  fi

  _prof=$(_cs_active_profile_yaml)
  if [ -n "$_prof" ] && [ -f "$_prof" ]; then
    echo
    echo "── 활성 프로필 yaml (${_prof}) ──"
    cat "$_prof"
  else
    echo
    echo "── 활성 프로필 yaml ──"
    echo "(활성 프로필 없음)"
  fi
  return 0
}

# config_set <key.path> <value> — 활성 프로필 yaml의 단일 값 변경
# 잘못된 path/누락 키는 에러. yq 우선, 없으면 sed fallback.
config_set() {
  set -u
  _k="${1:-}"
  _v="${2:-}"
  if [ -z "$_k" ] || [ "$#" -lt 2 ]; then
    _cs_err "사용법: config_set <key.path> <value>"
    return 1
  fi
  _cs_validate_key "$_k" || return 1

  _prof=$(_cs_active_profile_yaml)
  if [ -z "$_prof" ] || [ ! -f "$_prof" ]; then
    _cs_err "활성 프로필이 없거나 yaml 파일이 없습니다"
    return 1
  fi

  if _cs_has_yq; then
    _cs_set_with_yq "$_prof" "$_k" "$_v" || return 1
  else
    _cs_set_with_sed "$_prof" "$_k" "$_v" || return 1
  fi
  echo "갱신: $_k = $_v"
  return 0
}

# config_edit — $EDITOR (없으면 vi)로 활성 프로필 yaml 열기
config_edit() {
  set -u
  _prof=$(_cs_active_profile_yaml)
  if [ -z "$_prof" ] || [ ! -f "$_prof" ]; then
    _cs_err "활성 프로필이 없거나 yaml 파일이 없습니다"
    return 1
  fi
  _ed="${EDITOR:-vi}"
  exec "$_ed" "$_prof"
}
