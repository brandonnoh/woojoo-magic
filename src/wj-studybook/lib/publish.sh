#!/usr/bin/env bash
# publish.sh — /wj:studybook publish weekly|monthly 구현 (s13)
# 공개 함수:
#   publish_collect_notes <weekly|monthly>         # stdout: 기간 내 노트 경로
#   publish_prepare <weekly|monthly>               # Claude 전달용 컨텍스트
#   publish_apply <json_file> <weekly|monthly>     # Claude 결과 → 책 저장 + published_in 갱신
# Claude JSON: {title, body, chapters:[{title,note_ids}], note_paths[]}
# 외부 의존: schema.sh, book-writer.sh, config-helpers.sh(선택), jq.
# 주의: source 전용. set -euo pipefail은 호출자 책임. silent catch 금지.

if [ -n "${BASH_SOURCE:-}" ]; then _PB_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _PB_SRC="${(%):-%x}"
else _PB_SRC="$0"; fi
_PB_DIR="$(cd "$(dirname "$_PB_SRC")" && pwd)"
if [ -f "${_PB_DIR}/config-helpers.sh" ] && ! command -v get_active_profile >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_PB_DIR}/config-helpers.sh"
fi
# shellcheck source=/dev/null
command -v ulid_generate >/dev/null 2>&1 || . "${_PB_DIR}/schema.sh"
# shellcheck source=/dev/null
command -v book_write    >/dev/null 2>&1 || . "${_PB_DIR}/book-writer.sh"

_pb_err() { echo "publish.sh: $*" >&2; }

_pb_studybook_dir() {
  if command -v get_studybook_dir >/dev/null 2>&1; then get_studybook_dir
  else printf '%s\n' "${WJ_SB_HOME:-${HOME}/.studybook}"; fi
}

_pb_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then
    _pb_p=$(get_active_profile); [ -n "$_pb_p" ] && { printf '%s\n' "$_pb_p"; return 0; }
  fi
  printf '%s\n' "${WJ_SB_PROFILE:-default}"
}

_pb_topics_dir() {
  set -u
  printf '%s/books/%s/topics\n' "$(_pb_studybook_dir)" "$(_pb_active_profile)"
}

_pb_profile_field() {
  set -u
  _pb_field="$1"; _pb_default="${2:-}"
  _pb_yf=""
  if command -v get_profiles_dir >/dev/null 2>&1; then
    _pb_yf="$(get_profiles_dir)/$(_pb_active_profile).yaml"
  fi
  if [ -f "$_pb_yf" ]; then
    _pb_v=$(awk -v k="$_pb_field" '
      $0 ~ "^"k":" { sub("^"k":[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit }' "$_pb_yf")
    [ -n "$_pb_v" ] && { printf '%s\n' "$_pb_v"; return 0; }
  fi
  printf '%s\n' "$_pb_default"
}

_pb_note_field() {
  set -u
  awk -v k="$2" '
    NR==1 && $0!="---" { exit }
    NR==1 && $0=="---" { inblk=1; next }
    inblk && $0=="---" { exit }
    inblk && $0 ~ "^"k":" {
      sub("^"k":[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit
    }' "$1" 2>/dev/null
}

_pb_period_bounds() {
  set -u
  _pb_p=$(book_compute_period "$1") || return 1
  printf '%s\n' "$_pb_p" | sed -n 1p
  printf '%s\n' "$_pb_p" | sed -n 2p
  printf '%s\n' "$_pb_p" | sed -n 3p
}

publish_collect_notes() {
  set -u
  _pb_bounds=$(_pb_period_bounds "$1") || return 1
  _pb_start=$(printf '%s\n' "$_pb_bounds" | sed -n 1p)
  _pb_end=$(printf   '%s\n' "$_pb_bounds" | sed -n 2p)
  _pb_root=$(_pb_topics_dir)
  [ -d "$_pb_root" ] || return 0
  find "$_pb_root" -type f -name '*.md' ! -name '_index.md' 2>/dev/null | sort |
    while IFS= read -r _pb_nf; do
      [ -z "$_pb_nf" ] && continue
      _pb_cap=$(_pb_note_field "$_pb_nf" "captured_at")
      [ -z "$_pb_cap" ] && _pb_cap=$(_pb_note_field "$_pb_nf" "created_at")
      [ -z "$_pb_cap" ] && continue
      _pb_day=$(printf '%s' "$_pb_cap" | awk '{print substr($0,1,10)}')
      _pb_ok=$(awk -v d="$_pb_day" -v s="$_pb_start" -v e="$_pb_end" \
        'BEGIN { print (d >= s && d <= e) ? "1" : "0" }')
      if [ "$_pb_ok" = "1" ]; then
        _pb_pin=$(_pb_note_field "$_pb_nf" "published_in")
        [ -z "$_pb_pin" ] && printf '%s\t%s\n' "$_pb_cap" "$_pb_nf"
      fi
    done | sort | awk -F '\t' '{print $2}'
}

_pb_print_profile_block() {
  set -u
  _pb_pname=$(_pb_active_profile)
  printf '## ACTIVE_PROFILE\n%s\n\n' "$_pb_pname"
  if command -v get_profiles_dir >/dev/null 2>&1; then
    _pb_yaml="$(get_profiles_dir)/${_pb_pname}.yaml"
    if [ -f "$_pb_yaml" ]; then
      printf '## PROFILE_YAML\n'; cat "$_pb_yaml"; printf '\n'
    fi
  fi
}

_pb_print_period_block() {
  set -u
  _pb_b=$(_pb_period_bounds "$1") || return 1
  _pb_s=$(printf '%s\n' "$_pb_b" | sed -n 1p)
  _pb_e=$(printf '%s\n' "$_pb_b" | sed -n 2p)
  printf '## BOOK_KIND\n%s\n\n' "$1"
  printf '## PERIOD_START\n%s\n\n' "$_pb_s"
  printf '## PERIOD_END\n%s\n\n'   "$_pb_e"
}

_pb_print_notes_block() {
  set -u
  _pb_count=0
  printf '## NOTES\n'
  while IFS= read -r _pb_nf; do
    [ -z "$_pb_nf" ] && continue
    _pb_count=$((_pb_count + 1))
    _pb_id=$(_pb_note_field "$_pb_nf" "id")
    _pb_tt=$(_pb_note_field "$_pb_nf" "title")
    printf -- '--- NOTE_BEGIN id=%s title=%s path=%s ---\n' "$_pb_id" "$_pb_tt" "$_pb_nf"
    cat "$_pb_nf"
    printf '\n--- NOTE_END id=%s ---\n\n' "$_pb_id"
  done < <(publish_collect_notes "$1")
  printf '## NOTE_COUNT\n%s\n\n' "$_pb_count"
}

_pb_print_instructions() {
  cat <<'EOF'
## INSTRUCTIONS
위 NOTES를 PROFILE_YAML의 level/tone/language/age_group/book_style에 맞게
한 권의 책으로 다듬어 아래 JSON으로 반환:
  {
    "title": "<책 제목>",
    "body":  "<아래 OUTPUT_TEMPLATE 구조의 markdown>",
    "chapters": [{"title":"<챕터 제목>", "note_ids":["<ulid>", ...]}],
    "note_paths": ["<NOTE_BEGIN path= 경로 그대로>", ...]
  }
원칙:
- 챕터 구조: 관련 노트 묶어 입문 → 심화 순서로 재배치
- 각 챕터 도입글 + 원본 노트 본문 통합
- 원본 노트의 `## 내 말로 정리` 사용자 주석이 있으면 "#### 내 말로 정리"로 보존
- level=child/beginner → 친절한 비유 / level=advanced → 간결/전문 톤
- language 필드 그대로 사용 (ko/en/ko-en)

## OUTPUT_TEMPLATE
# {제목}

> {기간}, {N}개 학습 노트 · 약 {M}분 읽기

## 들어가며
{이번 기간 학습 흐름 1~2문단}

## 1장. {주제 그룹 1}
{도입글}

### {노트 1 제목}
{노트 본문}

#### 내 말로 정리
{사용자 주석 (있으면만)}

## 2장. {주제 그룹 2}
...

## 용어집
- {term}: {정의}

## 다음에 배울 것
- {추천 주제}
EOF
}

publish_prepare() {
  set -u
  _pb_k="${1:-}"
  case "$_pb_k" in weekly|monthly) : ;;
    *) _pb_err "사용법: publish_prepare <weekly|monthly>"; return 1 ;;
  esac
  printf '# wj-studybook publish 컨텍스트 (%s)\n\n' "$_pb_k"
  _pb_print_profile_block
  _pb_print_period_block "$_pb_k"
  _pb_print_notes_block  "$_pb_k"
  _pb_print_instructions
}

_pb_book_path() {
  set -u
  printf '%s/books/%s/%s/%s.md\n' \
    "$(_pb_studybook_dir)" "$(_pb_active_profile)" "$1" "$2"
}

_pb_parse_result() {
  set -u
  _pb_file="$1"
  _pba_title=$(jq -r   '.title // ""'    "$_pb_file")
  _pba_body=$(jq  -r   '.body  // ""'    "$_pb_file")
  _pba_chapters=$(jq -c '.chapters // []' "$_pb_file")
  _pba_notes=$(jq -r   '.note_paths // [] | .[]' "$_pb_file") || {
    echo "publish.sh: note_paths 파싱 실패: $_pb_file" >&2
    return 1
  }
  if [ -z "$_pba_title" ] || [ -z "$_pba_body" ]; then
    _pb_err "Claude 결과 JSON에 title/body 누락: $_pb_file"; return 1
  fi
}

_pb_write_notes_listfile() {
  set -u
  _pba_notes_file=$(mktemp -t wjpub_notes.XXXXXX) || return 1
  if [ -n "${_pba_notes:-}" ]; then
    printf '%s\n' "$_pba_notes" > "$_pba_notes_file"
  else
    publish_collect_notes "$1" > "$_pba_notes_file" || return 1
  fi
}

_pb_build_book_fm() {
  set -u
  _pb_bid="$1"; _pb_k="$2"; _pb_s="$3"; _pb_e="$4"
  _pb_stats="$5"; _pb_mins="$6"
  book_build_frontmatter \
    --id "$_pb_bid" --kind "$_pb_k" \
    --profile "$(_pb_active_profile)" --title "$_pba_title" \
    --level "$(_pb_profile_field level unknown)" \
    --language "$(_pb_profile_field language ko)" \
    --start "$_pb_s" --end "$_pb_e" \
    --chapters-json "$_pba_chapters" \
    --stats-json "$_pb_stats" \
    --estimated-minutes "$_pb_mins"
}

_pb_update_notes_published_in() {
  set -u
  _pb_lf="$1"; _pb_bid_u="$2"
  while IFS= read -r _pb_np; do
    [ -z "$_pb_np" ] && continue
    [ -f "$_pb_np" ] || continue
    book_update_note_published_in "$_pb_np" "$_pb_bid_u" || return 1
  done < "$_pb_lf"
}

_pb_print_done() {
  set -u
  _pb_out_done="$1"; _pb_bid_done="$2"; _pb_s_done="$3"; _pb_e_done="$4"
  _pb_stats_done="$5"; _pb_mins_done="$6"
  printf '발간 완료: %s\n' "$_pb_out_done"
  printf '  book_id:   %s\n' "$_pb_bid_done"
  printf '  period:    %s ~ %s\n' "$_pb_s_done" "$_pb_e_done"
  printf '  notes:     %s\n' "$(printf '%s' "$_pb_stats_done" | jq -r '.total_notes')"
  printf '  reading:   %s분\n' "$_pb_mins_done"
}

# apply 입력 검증 + _pb_k2 / _pb_jf 설정
_pb_apply_validate() {
  set -u
  _pb_jf="${1:-}"; _pb_k2="${2:-}"
  if [ -z "$_pb_jf" ] || [ ! -f "$_pb_jf" ]; then
    _pb_err "사용법: publish_apply <json_file> <weekly|monthly>"; return 1
  fi
  case "$_pb_k2" in weekly|monthly) : ;;
    *) _pb_err "kind는 weekly|monthly"; return 1 ;;
  esac
}

# 책 파일 저장 + 노트 역참조 갱신 (listfile cleanup 보장)
_pb_persist_and_backref() {
  set -u
  _pb_pa_out="$1"; _pb_pa_fm="$2"; _pb_pa_bid="$3"
  book_write "$_pb_pa_out" "$_pb_pa_fm" "$_pba_body" >/dev/null || {
    rm -f "$_pba_notes_file"; return 1; }
  _pb_update_notes_published_in "$_pba_notes_file" "$_pb_pa_bid" || {
    rm -f "$_pba_notes_file"; return 1; }
  rm -f "$_pba_notes_file"
}

publish_apply() {
  set -u
  _pb_apply_validate "$@" || return 1
  _pb_parse_result "$_pb_jf" || return 1
  _pb_b=$(_pb_period_bounds "$_pb_k2") || return 1
  _pb_s=$(printf  '%s\n' "$_pb_b" | sed -n 1p)
  _pb_e=$(printf  '%s\n' "$_pb_b" | sed -n 2p)
  _pb_sl=$(printf '%s\n' "$_pb_b" | sed -n 3p)
  _pb_write_notes_listfile "$_pb_k2" || return 1
  _pb_stats=$(book_compute_stats "$_pba_notes_file") || {
    rm -f "$_pba_notes_file"; return 1; }
  _pb_mins=$(printf '%s' "$_pb_stats" | jq -r '.estimated_reading_minutes // 0')
  _pb_bid=$(ulid_generate)
  _pb_fm=$(_pb_build_book_fm "$_pb_bid" "$_pb_k2" "$_pb_s" "$_pb_e" \
    "$_pb_stats" "$_pb_mins") || { rm -f "$_pba_notes_file"; return 1; }
  _pb_out=$(_pb_book_path "$_pb_k2" "$_pb_sl")
  _pb_persist_and_backref "$_pb_out" "$_pb_fm" "$_pb_bid" || return 1
  _pb_print_done "$_pb_out" "$_pb_bid" "$_pb_s" "$_pb_e" "$_pb_stats" "$_pb_mins"
}
