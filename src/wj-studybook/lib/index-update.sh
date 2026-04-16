#!/usr/bin/env bash
# index-update.sh — wj-studybook 인덱스 점진 갱신 (★ P1 핵심)
# 원칙: 점진, 부모 누적, lockfile, AUTO 영역만 갱신, idempotency
# 의존: jq (필수), flock (있으면 사용), bash 4+. source 전용.
WJ_SB_HOME="${WJ_SB_HOME:-${HOME}/.studybook}"
# ── 헬퍼 ────────────────────────────────────────────────────────
_idx_err() { echo "index-update.sh: $*" >&2; }

_idx_now_iso() {
  if date -Iseconds >/dev/null 2>&1; then date -Iseconds
  else date +"%Y-%m-%dT%H:%M:%S%z" | sed 's/\(..\)$/:\1/'; fi
}

_idx_tree_file() { printf '%s/cache/tree.json' "$WJ_SB_HOME"; }
_idx_tree_lock() { printf '%s.lockdir' "$(_idx_tree_file)"; }

_idx_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then get_active_profile
  else printf '%s' "${WJ_SB_PROFILE:-default}"; fi
}

# 동시성 lock (flock 우선, mkdir fallback for macOS)
_idx_with_lock() {
  set -u
  _lockdir="$(_idx_tree_lock)"
  if command -v flock >/dev/null 2>&1; then
    _lockfile="${_lockdir}.flock"; mkdir -p "$(dirname "$_lockfile")"
    ( flock -x 200; "$@" ) 200>"$_lockfile"; return $?
  fi
  _waited=0
  while ! mkdir "$_lockdir" 2>/dev/null; do
    _waited=$((_waited + 1))
    if [ "$_waited" -gt 500 ]; then _idx_err "lock 5s timeout"; return 1; fi
    sleep 0.01
  done
  "$@"; _rc=$?
  rmdir "$_lockdir" 2>/dev/null || true
  return $_rc
}

# ── tree.json 초기화 ────────────────────────────────────────────
init_tree_cache() {
  set -u
  _tree_file="$(_idx_tree_file)"
  mkdir -p "$(dirname "$_tree_file")"
  [ -f "$_tree_file" ] && return 0
  _profile=$(_idx_active_profile); _now=$(_idx_now_iso)
  cat > "$_tree_file" <<EOF
{
  "schema": "studybook.tree/v1",
  "generated_at": "${_now}",
  "active_profile": "${_profile}",
  "unsorted_count": 0,
  "tree": {}
}
EOF
}

# ── tree.json 부분 갱신 ─────────────────────────────────────────
_idx_jq_path() {
  set -u
  _cat="$1"; _sub="${2:-}"; _top="${3:-}"
  _path=".tree[\"$_cat\"]"
  if [ -n "$_sub" ]; then _path="${_path}.subtopics[\"$_sub\"]"; fi
  if [ -n "$_top" ]; then _path="${_path}.subtopics[\"$_top\"]"; fi
  printf '%s' "$_path"
}

_idx_apply_delta() {
  set -u
  _cat="$1"; _sub="${2:-}"; _top="${3:-}"; _delta="$4"
  _tree_file="$(_idx_tree_file)"
  _path=$(_idx_jq_path "$_cat" "$_sub" "$_top")
  _now=$(_idx_now_iso); _tmp="${_tree_file}.tmp.$$"
  jq --arg now "$_now" --argjson delta "$_delta" "
    if (${_path} | type) != \"object\" then ${_path} = {note_count: 0, subtopics: {}} else . end
    | ${_path}.note_count = ((${_path}.note_count // 0) + \$delta)
    | if (${_path}.subtopics | type) != \"object\" then ${_path}.subtopics = {} else . end
    | .generated_at = \$now
  " "$_tree_file" > "$_tmp" && mv "$_tmp" "$_tree_file"
}

_idx_walk_ancestors() {
  set -u
  _wa_cat="$1"; _wa_sub="${2:-}"; _wa_top="${3:-}"; _wa_delta="$4"
  if [ -n "$_wa_cat" ]; then _idx_apply_delta "$_wa_cat" "" "" "$_wa_delta" || return 1; fi
  if [ -n "$_wa_sub" ]; then _idx_apply_delta "$_wa_cat" "$_wa_sub" "" "$_wa_delta" || return 1; fi
  if [ -n "$_wa_top" ]; then _idx_apply_delta "$_wa_cat" "$_wa_sub" "$_wa_top" "$_wa_delta" || return 1; fi
  return 0
}

# ── _index.md 갱신 ──────────────────────────────────────────────
_idx_yaml_value() {
  set -u
  _yaml="$1"; _key="$2"
  printf '%s\n' "$_yaml" | awk -v k="$_key" '
    $0 ~ "^"k":" { sub("^"k":[[:space:]]*", ""); sub("[[:space:]]+$", ""); print; exit }'
}

_idx_extract_coords() {
  set -u
  _yaml=$(read_frontmatter "$1") || return 1
  _idx_yaml_value "$_yaml" "category"
  _idx_yaml_value "$_yaml" "subcategory"
  _idx_yaml_value "$_yaml" "topic"
}

_idx_render_index() {
  set -u
  _ri_cat="$1"; _ri_sub="$2"; _ri_top="$3"; _ri_cnt="$4"; _ri_now="$5"
  _ri_lbl="${_ri_top:-${_ri_sub:-${_ri_cat}}}"
  printf -- '---\nschema: studybook.index/v1\ntype: index\n'
  printf 'category: %s\nsubcategory: %s\ntopic: %s\n' "$_ri_cat" "$_ri_sub" "$_ri_top"
  printf 'note_count: %s\nlast_updated: %s\nsubtopics: []\n---\n\n' "$_ri_cnt" "$_ri_now"
  printf '# %s 노트 모음\n\n총 %s개 노트.\n\n' "$_ri_lbl" "$_ri_cnt"
  printf '<!-- @AUTO-GENERATED — 이 섹션은 인덱스 갱신 시 자동 재생성됨 -->\n'
  printf -- '- note_count: %s\n- last_updated: %s\n' "$_ri_cnt" "$_ri_now"
  printf '<!-- @END-AUTO -->\n'
}

# 기존 _index.md의 frontmatter note_count/last_updated + AUTO 영역만 in-place 갱신
_idx_patch_existing() {
  set -u
  _file="$1"; _count="$2"; _now="$3"; _tmp="${_file}.tmp.$$"
  awk -v cnt="$_count" -v ts="$_now" '
    BEGIN { fm=0; fmDone=0; auto=0 }
    /^---$/ {
      if (!fmDone) { if (fm==0) { fm=1; print; next } else { fmDone=1; print; next } }
      else { print; next }
    }
    fm==1 && !fmDone {
      if ($0 ~ /^note_count:/)   { print "note_count: " cnt; next }
      if ($0 ~ /^last_updated:/) { print "last_updated: " ts; next }
      print; next
    }
    /<!-- @AUTO-GENERATED/ { print; print "- note_count: " cnt; print "- last_updated: " ts; auto=1; next }
    /<!-- @END-AUTO -->/   { auto=0; print; next }
    auto==1 { next }
    { print }
  ' "$_file" > "$_tmp" && mv "$_tmp" "$_file"
}

# 한 폴더 _index.md를 delta만큼 갱신 (없으면 생성)
_idx_update_one_index() {
  set -u
  _folder="$1"; _cat="$2"; _sub="$3"; _top="$4"; _delta="$5"
  _index="${_folder}/_index.md"; _now=$(_idx_now_iso); mkdir -p "$_folder"
  if [ ! -f "$_index" ]; then
    _count=$_delta; [ "$_count" -lt 0 ] && _count=0
    _idx_render_index "$_cat" "$_sub" "$_top" "$_count" "$_now" > "$_index"
    return 0
  fi
  _yaml=$(read_frontmatter "$_index" 2>/dev/null) || _yaml=""
  _cur=$(_idx_yaml_value "$_yaml" "note_count"); [ -z "$_cur" ] && _cur=0
  _new=$((_cur + _delta)); [ "$_new" -lt 0 ] && _new=0
  _idx_patch_existing "$_index" "$_new" "$_now"
}

# 노트 경로의 모든 조상 폴더 _index.md 재귀 갱신
_idx_walk_index_files() {
  set -u
  _wi_note="$1"; _wi_cat="$2"; _wi_sub="$3"; _wi_top="$4"; _wi_delta="$5"
  _wi_leaf=$(dirname "$_wi_note")
  _idx_update_one_index "$_wi_leaf" "$_wi_cat" "$_wi_sub" "$_wi_top" "$_wi_delta" || return 1
  if [ -n "$_wi_top" ] && [ -n "$_wi_sub" ]; then
    _idx_update_one_index "$(dirname "$_wi_leaf")" "$_wi_cat" "$_wi_sub" "" "$_wi_delta" || return 1
  fi
  if [ -n "$_wi_sub" ] && [ -n "$_wi_cat" ]; then
    # category 폴더 = leaf에서 sub/topic 만큼 위로
    _wi_parent=$(dirname "$_wi_leaf")
    if [ -n "$_wi_top" ]; then _wi_parent=$(dirname "$_wi_parent"); fi
    _idx_update_one_index "$_wi_parent" "$_wi_cat" "" "" "$_wi_delta" || return 1
  fi
  return 0
}

# ── 공개 함수: 점진 갱신 ────────────────────────────────────────
_idx_resolve_coords() {
  set -u
  _note="$1"; _cat=""; _sub=""; _top=""
  if [ -f "$_note" ]; then
    _coords=$(_idx_extract_coords "$_note") || return 1
    _cat=$(printf '%s\n' "$_coords" | sed -n 1p)
    _sub=$(printf '%s\n' "$_coords" | sed -n 2p)
    _top=$(printf '%s\n' "$_coords" | sed -n 3p)
  else
    _cat="${WJ_SB_RM_CATEGORY:-}"; _sub="${WJ_SB_RM_SUBCATEGORY:-}"; _top="${WJ_SB_RM_TOPIC:-}"
  fi
  printf '%s\n%s\n%s\n' "$_cat" "$_sub" "$_top"
}

update_index_on_add() {
  set -u
  _ua_note="${1:-}"
  if [ -z "$_ua_note" ] || [ ! -f "$_ua_note" ]; then
    _idx_err "update_index_on_add: 노트 파일 필요: ${_ua_note:-<empty>}"; return 1
  fi
  init_tree_cache
  _ua_r=$(_idx_resolve_coords "$_ua_note") || return 1
  _ua_cat=$(printf '%s\n' "$_ua_r" | sed -n 1p)
  _ua_sub=$(printf '%s\n' "$_ua_r" | sed -n 2p)
  _ua_top=$(printf '%s\n' "$_ua_r" | sed -n 3p)
  if [ -z "$_ua_cat" ]; then _idx_err "category 없음: $_ua_note"; return 1; fi
  _idx_with_lock _idx_walk_ancestors "$_ua_cat" "$_ua_sub" "$_ua_top" 1 || return 1
  _idx_walk_index_files "$_ua_note" "$_ua_cat" "$_ua_sub" "$_ua_top" 1
}

update_index_on_remove() {
  set -u
  _ur_note="${1:-}"
  if [ -z "$_ur_note" ]; then _idx_err "노트 경로 필요"; return 1; fi
  init_tree_cache
  _ur_r=$(_idx_resolve_coords "$_ur_note") || return 1
  _ur_cat=$(printf '%s\n' "$_ur_r" | sed -n 1p)
  _ur_sub=$(printf '%s\n' "$_ur_r" | sed -n 2p)
  _ur_top=$(printf '%s\n' "$_ur_r" | sed -n 3p)
  if [ -z "$_ur_cat" ]; then _idx_err "category 알 수 없음: $_ur_note"; return 1; fi
  _idx_with_lock _idx_walk_ancestors "$_ur_cat" "$_ur_sub" "$_ur_top" -1 || return 1
  _idx_walk_index_files "$_ur_note" "$_ur_cat" "$_ur_sub" "$_ur_top" -1
}

update_index_on_move() {
  set -u
  _from="${1:-}"; _to="${2:-}"
  if [ -z "$_from" ] || [ -z "$_to" ]; then _idx_err "from/to 필요"; return 1; fi
  if [ ! -f "$_to" ]; then _idx_err "to 없음: $_to"; return 1; fi
  update_index_on_remove "$_from" || return 1
  update_index_on_add    "$_to"   || return 1
}

# ── unsorted (inbox) 카운트 ─────────────────────────────────────
_idx_set_unsorted() {
  set -u
  _val="$1"; _tree_file="$(_idx_tree_file)"; _now=$(_idx_now_iso); _tmp="${_tree_file}.tmp.$$"
  jq --argjson v "$_val" --arg now "$_now" '.unsorted_count = $v | .generated_at = $now' \
    "$_tree_file" > "$_tmp" && mv "$_tmp" "$_tree_file"
}

_idx_bump_unsorted() {
  set -u
  _delta="$1"; _tree_file="$(_idx_tree_file)"; _now=$(_idx_now_iso); _tmp="${_tree_file}.tmp.$$"
  jq --argjson d "$_delta" --arg now "$_now" '
    .unsorted_count = ((.unsorted_count // 0) + $d)
    | if .unsorted_count < 0 then .unsorted_count = 0 else . end
    | .generated_at = $now
  ' "$_tree_file" > "$_tmp" && mv "$_tmp" "$_tree_file"
}

update_tree_unsorted_increment() { init_tree_cache; _idx_with_lock _idx_bump_unsorted 1; }
update_tree_unsorted_decrement() { init_tree_cache; _idx_with_lock _idx_bump_unsorted -1; }
update_tree_unsorted_set()       { set -u; init_tree_cache; _idx_with_lock _idx_set_unsorted "${1:-0}"; }

# ── 전체 재구성 ─────────────────────────────────────────────────
update_tree_full_rebuild() {
  set -u
  _profile="${1:-$(_idx_active_profile)}"
  _root="${WJ_SB_HOME}/books/${_profile}/topics"
  _tree_file="$(_idx_tree_file)"
  mkdir -p "$(dirname "$_tree_file")"
  _now=$(_idx_now_iso); _prev_unsorted=0
  if [ -f "$_tree_file" ]; then
    _prev_unsorted=$(jq -r '.unsorted_count // 0' "$_tree_file" 2>/dev/null || echo 0)
  fi
  cat > "$_tree_file" <<EOF
{
  "schema": "studybook.tree/v1",
  "generated_at": "${_now}",
  "active_profile": "${_profile}",
  "unsorted_count": ${_prev_unsorted},
  "tree": {}
}
EOF
  [ -d "$_root" ] || return 0
  find "$_root" -type f -name '_index.md' -delete 2>/dev/null || true
  while IFS= read -r _note; do
    [ -z "$_note" ] && continue
    _coords=$(_idx_extract_coords "$_note" 2>/dev/null) || continue
    _cat=$(printf '%s\n' "$_coords" | sed -n 1p)
    _sub=$(printf '%s\n' "$_coords" | sed -n 2p)
    _top=$(printf '%s\n' "$_coords" | sed -n 3p)
    [ -z "$_cat" ] && continue
    _idx_walk_ancestors "$_cat" "$_sub" "$_top" 1
    _idx_walk_index_files "$_note" "$_cat" "$_sub" "$_top" 1
  done < <(find "$_root" -type f -name '*.md' ! -name '_index.md' 2>/dev/null)
}
