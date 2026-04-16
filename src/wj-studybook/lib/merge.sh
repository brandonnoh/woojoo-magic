#!/usr/bin/env bash
# merge.sh — /wj:studybook merge <from> <to> 구현 (s12)
# Usage:
#   source src/wj-studybook/lib/merge.sh
#   merge_detect_prepare                         # stdout: Claude에 전달할 동의어 탐지 컨텍스트
#   merge_apply <from_dir> <to_dir> [--yes]      # from 하위 노트를 to로 병합
#
# 외부 의존: index-update.sh, schema.sh, config-helpers.sh(선택), jq
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.
#       Claude API 직접 호출 금지 — detect는 "컨텍스트 패키징"만 수행.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _MG_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _MG_SRC="${(%):-%x}"
else
  _MG_SRC="$0"
fi
_MG_DIR="$(cd "$(dirname "$_MG_SRC")" && pwd)"
if [ -f "${_MG_DIR}/config-helpers.sh" ] && ! command -v get_active_profile >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_MG_DIR}/config-helpers.sh"
fi
if ! command -v update_index_on_move >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_MG_DIR}/index-update.sh"
fi

# ── stderr ───────────────────────────────────────────────────────
_mg_err() { echo "merge.sh: $*" >&2; }

# ── 내부: 경로/프로필 ────────────────────────────────────────────
_mg_studybook_dir() {
  if command -v get_studybook_dir >/dev/null 2>&1; then
    get_studybook_dir
  else
    printf '%s\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

_mg_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then
    _mg_p=$(get_active_profile)
    [ -n "$_mg_p" ] && { printf '%s\n' "$_mg_p"; return 0; }
  fi
  printf '%s\n' "${WJ_SB_PROFILE:-default}"
}

_mg_topics_dir() {
  set -u
  _mg_prof=$(_mg_active_profile)
  printf '%s/books/%s/topics\n' "$(_mg_studybook_dir)" "$_mg_prof"
}

_mg_tree_file() { printf '%s/cache/tree.json\n' "$(_mg_studybook_dir)"; }

# ── 내부: topics 하위 "leaf 폴더"(topic 레벨) 나열 ────────────────
# stdout: 한 줄당 절대 경로 (topic 디렉토리만) + note count
# 형식: <abs_path>\t<note_count>\t<category>\t<subcategory>\t<topic>
_mg_list_topic_folders() {
  set -u
  _mg_root=$(_mg_topics_dir)
  [ -d "$_mg_root" ] || return 0
  # topics/<category>/<subcategory>/<topic> — depth 3
  find "$_mg_root" -mindepth 3 -maxdepth 3 -type d 2>/dev/null | sort | while IFS= read -r _mg_d; do
    [ -z "$_mg_d" ] && continue
    _mg_rel="${_mg_d#${_mg_root}/}"
    _mg_cat=$(printf '%s' "$_mg_rel" | awk -F/ '{print $1}')
    _mg_sub=$(printf '%s' "$_mg_rel" | awk -F/ '{print $2}')
    _mg_top=$(printf '%s' "$_mg_rel" | awk -F/ '{print $3}')
    _mg_n=$(find "$_mg_d" -maxdepth 1 -type f -name '*.md' ! -name '_index.md' 2>/dev/null | wc -l | tr -d ' ')
    printf '%s\t%s\t%s\t%s\t%s\n' "$_mg_d" "$_mg_n" "$_mg_cat" "$_mg_sub" "$_mg_top"
  done
}

# ── 내부: 섹션 출력 헬퍼 ─────────────────────────────────────────
_mg_print_tree_block() {
  set -u
  _mg_tf=$(_mg_tree_file)
  printf '## TREE_DUMP\n'
  if [ -f "$_mg_tf" ]; then cat "$_mg_tf"; else printf '{}'; fi
  printf '\n\n'
}

_mg_print_folders_block() {
  set -u
  printf '## FOLDERS\n'
  _mg_n=0
  while IFS=$'\t' read -r _mg_path _mg_cnt _mg_c _mg_s _mg_t; do
    [ -z "$_mg_path" ] && continue
    _mg_n=$((_mg_n + 1))
    printf -- '- path=%s notes=%s category=%s subcategory=%s topic=%s\n' \
      "$_mg_path" "$_mg_cnt" "$_mg_c" "$_mg_s" "$_mg_t"
  done < <(_mg_list_topic_folders)
  printf '## FOLDER_COUNT\n%s\n\n' "$_mg_n"
}

_mg_print_instructions_block() {
  printf '## INSTRUCTIONS\n'
  printf '위 FOLDERS 목록에서 동의어/유사 주제 폴더 쌍을 찾아 JSON 배열로 반환:\n'
  printf '  [{"a":"<path>","b":"<path>","reason":"<short>","confidence":0-100}, ...]\n'
  printf '예: react ↔ 리액트, dp ↔ 다이나믹프로그래밍, ml ↔ 머신러닝\n'
  printf '사용자 확인 후 `/wj:studybook merge <from> <to> --yes` 호출.\n'
}

# ── 공개: 병합 탐지용 컨텍스트 prepare ───────────────────────────
# stdout 섹션: ACTIVE_PROFILE / TREE_DUMP / FOLDERS / INSTRUCTIONS
merge_detect_prepare() {
  set -u
  printf '# wj-studybook merge 탐지 컨텍스트\n\n'
  printf '## ACTIVE_PROFILE\n%s\n\n' "$(_mg_active_profile)"
  _mg_print_tree_block
  _mg_print_folders_block
  _mg_print_instructions_block
}

# ── 내부: frontmatter 3좌표 in-place 치환용 awk 스크립트 ─────────
_MG_PATCH_AWK='
  BEGIN { fm=0; fmDone=0 }
  /^---$/ {
    if (!fmDone) { if (fm==0) { fm=1; print; next } else { fmDone=1; print; next } }
    else { print; next }
  }
  fm==1 && !fmDone {
    if ($0 ~ /^category:/)    { print "category: " nc;    next }
    if ($0 ~ /^subcategory:/) { print "subcategory: " ns; next }
    if ($0 ~ /^topic:/)       { print "topic: " nt;       next }
    print; next
  }
  { print }
'

# ── 내부: 노트 frontmatter category/subcategory/topic 값 갱신 ────
# 인자: file, new_cat, new_sub, new_top
_mg_patch_frontmatter() {
  set -u
  _mg_f="$1"; _mg_nc="$2"; _mg_ns="$3"; _mg_nt="$4"
  _mg_tmp="${_mg_f}.mgtmp.$$"
  awk -v nc="$_mg_nc" -v ns="$_mg_ns" -v nt="$_mg_nt" "$_MG_PATCH_AWK" \
    "$_mg_f" > "$_mg_tmp" && mv "$_mg_tmp" "$_mg_f"
}

# ── 내부: 경로 → (cat, sub, top) 추출 ───────────────────────────
# 입력: topics/.../<cat>/<sub>/<top> 절대 경로
# 출력: 3줄 (cat, sub, top)
_mg_coords_from_path() {
  set -u
  _mg_p="$1"; _mg_root=$(_mg_topics_dir)
  case "$_mg_p" in
    "${_mg_root}"/*) : ;;
    *) _mg_err "경로가 topics/ 하위가 아님: $_mg_p"; return 1 ;;
  esac
  _mg_rel="${_mg_p#${_mg_root}/}"
  _mg_rc=$(printf '%s' "$_mg_rel" | awk -F/ '{print NF}')
  if [ "$_mg_rc" -lt 3 ]; then
    _mg_err "topic 레벨(cat/sub/top) 폴더가 아님: $_mg_p"; return 1
  fi
  printf '%s' "$_mg_rel" | awk -F/ '{print $1; print $2; print $3}'
}

# ── 내부: 한 노트 병합 (mv + frontmatter 갱신 + 인덱스 동기화) ──
# from 파일의 원본 좌표(fc/fs/ft)는 호출자가 추출해 env로 전달.
# 순서: mv → patch frontmatter → update_index_on_move
#   - remove phase: from 파일 없음 → WJ_SB_RM_* env vars로 좌표 주입
#   - add phase:    to 파일 존재 + 이미 새 좌표로 patch됨 → frontmatter 직접 읽음
_mg_merge_one_note() {
  set -u
  _mg_src="$1"; _mg_dst_dir="$2"
  _mg_fc="$3"; _mg_fs="$4"; _mg_ft="$5"
  _mg_nc="$6"; _mg_ns="$7"; _mg_nt="$8"
  _mg_base=$(basename "$_mg_src")
  _mg_dst="${_mg_dst_dir}/${_mg_base}"
  if [ -e "$_mg_dst" ]; then
    _mg_err "대상 파일 이미 존재: $_mg_dst"; return 1
  fi
  mv "$_mg_src" "$_mg_dst" || { _mg_err "이동 실패: $_mg_src"; return 1; }
  _mg_patch_frontmatter "$_mg_dst" "$_mg_nc" "$_mg_ns" "$_mg_nt" || {
    _mg_err "frontmatter 갱신 실패: $_mg_dst"; return 1; }
  WJ_SB_RM_CATEGORY="$_mg_fc" WJ_SB_RM_SUBCATEGORY="$_mg_fs" WJ_SB_RM_TOPIC="$_mg_ft" \
    update_index_on_move "$_mg_src" "$_mg_dst" || {
    _mg_err "인덱스 동기화 실패: $_mg_src → $_mg_dst"; return 1; }
}

# ── 내부: 사용자 확인 프롬프트 (--yes 시 bypass) ─────────────────
_mg_confirm() {
  set -u
  _mg_prompt="$1"; _mg_yes="$2"
  if [ "$_mg_yes" = "1" ]; then return 0; fi
  printf '%s [y/N] ' "$_mg_prompt" >&2
  read -r _mg_ans || return 1
  case "$_mg_ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# ── 내부: merge_apply 전처리 (인자 검증 + 좌표 추출) ──────────────
# 부작용: _mg_from/_mg_to 정규화, _mg_yes, _mg_fc/_mg_fs/_mg_ft, _mg_nc/_mg_ns/_mg_nt 설정
_mg_prepare_apply() {
  set -u
  _mg_from="${1:-}"; _mg_to="${2:-}"; _mg_flag="${3:-}"
  if [ -z "$_mg_from" ] || [ -z "$_mg_to" ]; then
    _mg_err "사용법: merge_apply <from_dir> <to_dir> [--yes]"; return 1
  fi
  _mg_yes=0; [ "$_mg_flag" = "--yes" ] && _mg_yes=1
  _mg_from="${_mg_from%/}"; _mg_to="${_mg_to%/}"
  [ -d "$_mg_from" ] || { _mg_err "from 디렉토리 없음: $_mg_from"; return 1; }
  [ "$_mg_from" = "$_mg_to" ] && { _mg_err "from과 to가 동일: $_mg_from"; return 1; }
  _mg_tc=$(_mg_coords_from_path "$_mg_to")           || return 1
  _mg_fc_coords=$(_mg_coords_from_path "$_mg_from")  || return 1
  _mg_nc=$(printf '%s\n' "$_mg_tc"        | sed -n 1p)
  _mg_ns=$(printf '%s\n' "$_mg_tc"        | sed -n 2p)
  _mg_nt=$(printf '%s\n' "$_mg_tc"        | sed -n 3p)
  _mg_fc=$(printf '%s\n' "$_mg_fc_coords" | sed -n 1p)
  _mg_fs=$(printf '%s\n' "$_mg_fc_coords" | sed -n 2p)
  _mg_ft=$(printf '%s\n' "$_mg_fc_coords" | sed -n 3p)
}

# ── 내부: from 하위 노트 목록 파이프 → to로 이동 ────────────────
_mg_move_all_notes() {
  set -u
  while IFS= read -r _mg_src; do
    [ -z "$_mg_src" ] && continue
    _mg_merge_one_note "$_mg_src" "$_mg_to" \
      "$_mg_fc" "$_mg_fs" "$_mg_ft" \
      "$_mg_nc" "$_mg_ns" "$_mg_nt" || return 1
  done
}

# ── 공개: 병합 적용 ──────────────────────────────────────────────
# Usage: merge_apply <from_dir> <to_dir> [--yes]
merge_apply() {
  set -u
  _mg_prepare_apply "$@" || return 1
  mkdir -p "$_mg_to" || { _mg_err "to 생성 실패: $_mg_to"; return 1; }
  _mg_files=$(find "$_mg_from" -maxdepth 1 -type f -name '*.md' ! -name '_index.md' 2>/dev/null | sort)
  _mg_n=0
  [ -n "$_mg_files" ] && _mg_n=$(printf '%s\n' "$_mg_files" | wc -l | tr -d ' ')
  _mg_confirm "'$_mg_from' (${_mg_n}개) → '$_mg_to' 병합?" "$_mg_yes" || {
    _mg_err "사용자 취소"; return 1; }
  if [ -n "$_mg_files" ]; then
    printf '%s\n' "$_mg_files" | _mg_move_all_notes || return 1
  fi
  rm -f "${_mg_from}/_index.md" 2>/dev/null || true
  rmdir "$_mg_from" 2>/dev/null || {
    _mg_err "from 디렉토리가 비어있지 않아 삭제하지 않음: $_mg_from"; return 0; }
  printf 'merge_apply: %d개 노트 이동 완료 (%s → %s)\n' "$_mg_n" "$_mg_from" "$_mg_to"
}
