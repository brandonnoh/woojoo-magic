#!/usr/bin/env bash
# topic-writer.sh — books/<profile>/topics/<...>/<slug>-<ulid>.md 생성 헬퍼
# Usage:
#   source src/wj-studybook/lib/schema.sh        # ulid_generate, emit_frontmatter
#   source src/wj-studybook/lib/index-update.sh  # update_index_on_add
#   source src/wj-studybook/lib/topic-writer.sh
#   write_topic_note --profile p --category c --subcategory s --topic t \
#     --title "..." --slug "..." --tags "a,b" --body "..." \
#     --sources-json '[{"inbox_id":"...","captured_at":"...","session_id":"...","model":"..."}]' \
#     [--subtopic st] [--level beginner] [--language ko]
#
# 출력: 생성된 파일 절대 경로 (stdout 1줄)
# 의존: schema.sh, index-update.sh, jq
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.

# ── stderr ───────────────────────────────────────────────────────
_tw_err() { echo "topic-writer.sh: $*" >&2; }

# ── 내부 헬퍼 ────────────────────────────────────────────────────

# _tw_validate_path_segment — 경로 세그먼트 검증 (../포함 및 비허용 문자 차단)
_tw_validate_path_segment() {
  _tw_vs_val="$1"; _tw_vs_name="$2"
  # ../ 포함 여부 검사
  case "$_tw_vs_val" in
    *"../"* | ".." | *"/.."*)
      echo "[ERROR] 잘못된 ${_tw_vs_name}: $1" >&2; return 1 ;;
  esac
  # ^[a-zA-Z0-9가-힣_-]+$ 형식 검증
  if ! printf '%s' "$_tw_vs_val" | grep -qE '^[a-zA-Z0-9가-힣_-]+$'; then
    echo "[ERROR] 잘못된 카테고리/슬러그: $1" >&2; return 1
  fi
  return 0
}

# books_dir (config-helpers.sh가 source되어 있으면 그것을 사용, 아니면 fallback)
_tw_books_dir() {
  if command -v get_books_dir >/dev/null 2>&1; then
    get_books_dir
  else
    printf '%s/books\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

# 좌표 → 디렉터리 경로 (subtopic 비어있으면 생략)
_tw_topic_dir() {
  set -u
  _tw_profile="$1"; _tw_cat="$2"; _tw_sub="$3"; _tw_top="$4"
  # 경로 세그먼트 검증 (path traversal 및 비허용 문자 차단)
  _tw_validate_path_segment "$_tw_profile" "profile" || return 1
  _tw_validate_path_segment "$_tw_cat"     "category" || return 1
  _tw_validate_path_segment "$_tw_sub"     "subcategory" || return 1
  _tw_validate_path_segment "$_tw_top"     "topic" || return 1
  _tw_d="$(_tw_books_dir)/${_tw_profile}/topics/${_tw_cat}/${_tw_sub}/${_tw_top}"
  printf '%s' "$_tw_d"
}

# tags CSV → YAML flow array ("a,b" → "[\"a\", \"b\"]")
_tw_tags_to_yaml() {
  set -u
  _tw_csv="${1:-}"
  if [ -z "$_tw_csv" ]; then printf '[]'; return 0; fi
  printf '%s\n' "$_tw_csv" | jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$"; ""))'
}

# frontmatter YAML 빌드 (필수 + sources[])
_tw_build_yaml() {
  set -u
  _tw_y_ulid="$1"; _tw_y_now="$2"; _tw_y_profile="$3"
  _tw_y_cat="$4"; _tw_y_sub="$5"; _tw_y_top="$6"; _tw_y_subtop="$7"
  _tw_y_title="$8"; _tw_y_slug="$9"; _tw_y_tags="${10}"
  _tw_y_level="${11}"; _tw_y_language="${12}"; _tw_y_sources="${13}"
  printf 'id: %s\n'             "$_tw_y_ulid"
  printf 'schema: %s\n'         "studybook.note/v1"
  printf 'type: %s\n'           "topic"
  printf 'status: %s\n'         "published"
  printf 'captured_at: %s\n'    "$_tw_y_now"
  printf 'profile: %s\n'        "$_tw_y_profile"
  printf 'category: %s\n'       "$_tw_y_cat"
  printf 'subcategory: %s\n'    "$_tw_y_sub"
  printf 'topic: %s\n'          "$_tw_y_top"
  if [ -n "$_tw_y_subtop" ]; then printf 'subtopic: %s\n' "$_tw_y_subtop"; fi
  printf 'title: %s\n'          "$_tw_y_title"
  printf 'slug: %s\n'           "$_tw_y_slug"
  printf 'level: %s\n'          "$_tw_y_level"
  printf 'language: %s\n'       "$_tw_y_language"
  printf 'tags: %s\n'           "$_tw_y_tags"
  printf 'sources: %s\n'        "$_tw_y_sources"
}

# 본문 + Generation Effect 슬롯
_tw_build_body() {
  set -u
  _tw_b_body="${1:-}"
  printf '%s\n' "$_tw_b_body"
  printf '\n## 내 말로 정리\n<!-- Generation Effect 슬롯 — 직접 작성 -->\n\n'
}

# 인자 파싱 (전역 변수 _twa_* 에 할당)
_tw_parse_args() {
  set -u
  _twa_profile=""; _twa_cat=""; _twa_sub=""; _twa_top=""; _twa_subtop=""
  _twa_title=""; _twa_slug=""; _twa_tags=""; _twa_body=""; _twa_sources=""
  _twa_level=""; _twa_language=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --profile)      _twa_profile="${2:-}"; shift 2 ;;
      --category)     _twa_cat="${2:-}"; shift 2 ;;
      --subcategory)  _twa_sub="${2:-}"; shift 2 ;;
      --topic)        _twa_top="${2:-}"; shift 2 ;;
      --subtopic)     _twa_subtop="${2:-}"; shift 2 ;;
      --title)        _twa_title="${2:-}"; shift 2 ;;
      --slug)         _twa_slug="${2:-}"; shift 2 ;;
      --tags)         _twa_tags="${2:-}"; shift 2 ;;
      --body)         _twa_body="${2:-}"; shift 2 ;;
      --sources-json) _twa_sources="${2:-}"; shift 2 ;;
      --level)        _twa_level="${2:-}"; shift 2 ;;
      --language)     _twa_language="${2:-}"; shift 2 ;;
      *) _tw_err "알 수 없는 옵션: $1"; return 1 ;;
    esac
  done
}

# ── 공개 함수 ────────────────────────────────────────────────────

# write_topic_note — 분류 결과 1건 → topic 노트 파일 저장 + 인덱스 갱신
write_topic_note() {
  set -u
  _tw_parse_args "$@" || return 1
  for _tw_req in "$_twa_profile" "$_twa_cat" "$_twa_sub" "$_twa_top" \
                 "$_twa_title" "$_twa_slug"; do
    if [ -z "$_tw_req" ]; then
      _tw_err "필수 인자 누락 (profile/category/subcategory/topic/title/slug)"
      return 1
    fi
  done
  [ -z "$_twa_sources" ] && _twa_sources="[]"
  _tw_dir="$(_tw_topic_dir "$_twa_profile" "$_twa_cat" "$_twa_sub" "$_twa_top")"
  mkdir -p "$_tw_dir" || { _tw_err "디렉터리 생성 실패: $_tw_dir"; return 1; }
  _tw_ulid="$(ulid_generate)"
  _tw_now="$(get_iso_now)"
  _tw_tags_yaml="$(_tw_tags_to_yaml "$_twa_tags")"
  _tw_file="${_tw_dir}/${_twa_slug}-${_tw_ulid}.md"
  _tw_yaml=$(_tw_build_yaml "$_tw_ulid" "$_tw_now" "$_twa_profile" \
    "$_twa_cat" "$_twa_sub" "$_twa_top" "$_twa_subtop" \
    "$_twa_title" "$_twa_slug" "$_tw_tags_yaml" \
    "${_twa_level:-unknown}" "${_twa_language:-ko}" "$_twa_sources")
  {
    emit_frontmatter "$_tw_yaml"
    printf '\n# %s\n\n' "$_twa_title"
    _tw_build_body "$_twa_body"
  } > "$_tw_file" || { _tw_err "파일 쓰기 실패: $_tw_file"; return 1; }
  update_index_on_add "$_tw_file" || { _tw_err "인덱스 갱신 실패: $_tw_file"; return 1; }
  printf '%s\n' "$_tw_file"
}
