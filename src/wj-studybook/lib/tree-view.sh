#!/usr/bin/env bash
# tree-view.sh — /wj:studybook tree 구현 (s15)
# Usage:
#   source src/wj-studybook/lib/tree-view.sh
#   tree_render <tree_json_path> [max_depth]   # ASCII 트리 stdout
#   tree_render_json <tree_json_path>          # jq pretty print
#   tree_cli [--depth N] [--json]              # 라우터 엔트리
#
# 외부 의존: config-helpers.sh, jq (필수)
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.
#       재귀/렌더링은 jq 1-pass로 처리하여 bash 변수 오염을 회피.
#       utf-8 (한글/이모지/box-drawing) 출력 안전.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _TV_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _TV_SRC="${(%):-%x}"
else
  _TV_SRC="$0"
fi
_TV_DIR="$(cd "$(dirname "$_TV_SRC")" && pwd)"
if [ -f "${_TV_DIR}/config-helpers.sh" ] && ! command -v get_active_profile >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_TV_DIR}/config-helpers.sh"
fi

# ── stderr ───────────────────────────────────────────────────────
_tv_err() { echo "tree-view.sh: $*" >&2; }

# ── 내부: 기본 tree.json 경로 ────────────────────────────────────
_tv_default_tree_file() {
  if command -v get_studybook_dir >/dev/null 2>&1; then
    printf '%s/cache/tree.json\n' "$(get_studybook_dir)"
  else
    printf '%s/cache/tree.json\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

# ── 내부: 활성 프로필 yaml에서 단일 키 추출 ──────────────────────
_tv_profile_yaml_value() {
  set -u
  _prof_file="$1"; _key="$2"
  [ -f "$_prof_file" ] || { printf ''; return 0; }
  awk -v k="$_key" '
    $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*", "")
      sub("[[:space:]]+$", "")
      print
      exit
    }
  ' "$_prof_file"
}

# ── 내부: 프로필 이름/level/language 수집 ────────────────────────
# stdout: 3줄 (name / level / language) — 비어 있을 수 있음
_tv_profile_summary() {
  set -u
  if command -v get_active_profile >/dev/null 2>&1; then
    _pn=$(get_active_profile)
  else
    _pn="${WJ_SB_PROFILE:-default}"
  fi
  [ -z "$_pn" ] && _pn="default"
  if command -v get_profiles_dir >/dev/null 2>&1; then
    _pf="$(get_profiles_dir)/${_pn}.yaml"
  else
    _pf="${WJ_SB_HOME:-${HOME}/.studybook}/profiles/${_pn}.yaml"
  fi
  _lv=$(_tv_profile_yaml_value "$_pf" "level")
  _lg=$(_tv_profile_yaml_value "$_pf" "language")
  printf '%s\n%s\n%s\n' "$_pn" "$_lv" "$_lg"
}

# ── 내부: ISO 타임스탬프 → "YYYY-MM-DD HH:MM" (POSIX awk) ────────
_tv_fmt_timestamp() {
  set -u
  _ts="${1:-}"
  [ -z "$_ts" ] && { printf ''; return 0; }
  # "2026-04-16T15:01:00+09:00" → "2026-04-16 15:01"
  printf '%s' "$_ts" | awk '
    {
      s=$0
      gsub(/T/, " ", s)
      # 첫 16자 = "YYYY-MM-DD HH:MM"
      print substr(s, 1, 16)
    }'
}

# ── 내부: 루트 헤더 출력 ─────────────────────────────────────────
_tv_print_header() {
  set -u
  _psum="$1"
  _name=$(printf '%s\n' "$_psum" | sed -n 1p)
  _level=$(printf '%s\n' "$_psum" | sed -n 2p)
  _lang=$(printf '%s\n' "$_psum" | sed -n 3p)
  if [ -n "$_level" ] && [ -n "$_lang" ]; then
    printf '📚 %s (%s, %s)\n' "$_name" "$_level" "$_lang"
  elif [ -n "$_level" ]; then
    printf '📚 %s (%s)\n' "$_name" "$_level"
  elif [ -n "$_lang" ]; then
    printf '📚 %s (%s)\n' "$_name" "$_lang"
  else
    printf '📚 %s\n' "$_name"
  fi
}

# ── 내부: jq로 트리 본문 전체 렌더 (재귀) ────────────────────────
# 인자: tree_json_path / max_depth
# 출력: box-drawing 포함 한 라인씩
_tv_render_body() {
  set -u
  _tf="$1"; _maxd="$2"
  [ "$_maxd" -lt 1 ] && return 0
  jq -r --argjson maxd "$_maxd" '
    # 노드(오브젝트) 한 개를 prefix/branch/depth 받아 렌더.
    # $is_cat: true → 카테고리(📁) 접두, false → topic(접두 없음)
    # (jq는 0도 truthy이므로 반드시 boolean 사용)
    def render_node($name; $node; $prefix; $is_last; $depth; $is_cat):
      (if $is_last then "└── " else "├── " end) as $branch
      | (if $is_cat then "📁 " else "" end) as $emoji
      | ($node.note_count // 0) as $cnt
      | "\($prefix)\($branch)\($emoji)\($name) (\($cnt))"
      , ( if $depth < $maxd then
            ($node.subtopics // {}) as $subs
            | ($subs | keys_unsorted) as $ks
            | ($ks | length) as $n
            | (if $is_last then "    " else "│   " end) as $gap
            | ($prefix + $gap) as $child_prefix
            | ($depth + 1) as $nd
            | ($nd < 3) as $child_cat
            | range(0; $n) as $i
            | $ks[$i] as $k
            | render_node($k; $subs[$k]; $child_prefix; ($i == $n - 1); $nd; $child_cat)
          else empty end );

    (.tree // {}) as $root
    | ($root | keys_unsorted) as $ks
    | ($ks | length) as $n
    | range(0; $n) as $i
    | $ks[$i] as $k
    | render_node($k; $root[$k]; ""; ($i == $n - 1); 1; true)
  ' "$_tf"
}

# ── 공개: ASCII 트리 렌더 ────────────────────────────────────────
tree_render() {
  set -u
  _tf="${1:-}"; _maxd="${2:-3}"
  if [ -z "$_tf" ]; then
    _tv_err "사용법: tree_render <tree_json_path> [max_depth]"
    return 1
  fi
  if [ ! -f "$_tf" ]; then
    _tv_err "tree.json 없음: $_tf"
    return 1
  fi
  if ! jq -e '.schema == "studybook.tree/v1"' "$_tf" >/dev/null 2>&1; then
    _tv_err "tree.json 스키마 불일치: $_tf"
    return 1
  fi
  if ! printf '%s' "$_maxd" | grep -Eq '^[0-9]+$'; then
    _tv_err "max_depth는 정수여야 함: $_maxd"
    return 1
  fi
  _psum=$(_tv_profile_summary)
  _tv_print_header "$_psum"
  _tv_render_body "$_tf" "$_maxd" || return 1
  _unsorted=$(jq -r '.unsorted_count // 0' "$_tf" 2>/dev/null)
  _gen=$(jq -r '.generated_at // ""' "$_tf" 2>/dev/null)
  if [ "${_unsorted:-0}" -gt 0 ] 2>/dev/null; then
    printf '\n미분류 inbox: %s개\n' "$_unsorted"
  fi
  if [ -n "$_gen" ]; then
    _fmt=$(_tv_fmt_timestamp "$_gen")
    printf '마지막 갱신: %s\n' "$_fmt"
  fi
}

# ── 공개: JSON 그대로 출력 ───────────────────────────────────────
tree_render_json() {
  set -u
  _tf="${1:-}"
  if [ -z "$_tf" ]; then
    _tv_err "사용법: tree_render_json <tree_json_path>"
    return 1
  fi
  if [ ! -f "$_tf" ]; then
    _tv_err "tree.json 없음: $_tf"
    return 1
  fi
  jq '.' "$_tf"
}

# ── 공개: CLI 엔트리 ─────────────────────────────────────────────
tree_cli() {
  set -u
  _mode="ascii"; _maxd=3
  while [ $# -gt 0 ]; do
    case "$1" in
      --depth)
        shift
        _maxd="${1:-}"
        if ! printf '%s' "$_maxd" | grep -Eq '^[0-9]+$'; then
          _tv_err "--depth 값은 정수여야 함: ${_maxd:-<empty>}"
          return 2
        fi
        ;;
      --depth=*)
        _maxd="${1#--depth=}"
        if ! printf '%s' "$_maxd" | grep -Eq '^[0-9]+$'; then
          _tv_err "--depth 값은 정수여야 함: $_maxd"
          return 2
        fi
        ;;
      --json) _mode="json" ;;
      "") : ;;
      *)
        _tv_err "지원하지 않는 옵션: $1"
        return 2
        ;;
    esac
    shift || true
  done
  _tf=$(_tv_default_tree_file)
  if [ "$_mode" = "json" ]; then
    tree_render_json "$_tf"
  else
    tree_render "$_tf" "$_maxd"
  fi
}
