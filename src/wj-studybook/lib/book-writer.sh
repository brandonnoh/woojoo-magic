#!/usr/bin/env bash
# book-writer.sh — books/<profile>/<weekly|monthly>/<slug>.md 생성/갱신 헬퍼 (s13)
# 공개 함수:
#   book_compute_period <weekly|monthly>          # stdout: start / end / slug
#   book_build_frontmatter --id --kind --profile --title --level --language \
#     --start --end [--published-at] [--chapters-json] [--stats-json] [--estimated-minutes]
#   book_write <output_path> <frontmatter_yaml> <body_text>
#   book_update_note_published_in <note_path> <book_id>
#   book_compute_stats <list_file>
# 외부 의존: schema.sh(emit_frontmatter), jq.
# 주의: source 전용. set -euo pipefail은 호출자 책임. silent catch 금지.

_bw_err() { echo "book-writer.sh: $*" >&2; }

_bw_now_iso() {
  if date -Iseconds >/dev/null 2>&1; then date -Iseconds
  else date +"%Y-%m-%dT%H:%M:%S%z"; fi
}

_bw_date_offset() {
  set -u
  _bw_base="$1"; _bw_delta="$2"
  if date -j -f '%Y-%m-%d' "$_bw_base" +%s >/dev/null 2>&1; then
    _bw_epoch=$(date -j -f '%Y-%m-%d' "$_bw_base" +%s)
    _bw_new=$((_bw_epoch + _bw_delta * 86400))
    date -r "$_bw_new" +%Y-%m-%d
  else
    date -d "${_bw_base} ${_bw_delta} day" +%Y-%m-%d
  fi
}

_bw_year_week()  { if date -j +%G-w%V >/dev/null 2>&1; then date -j +%G-w%V; else date +%G-w%V; fi; }
_bw_year_month() { date +%Y-%m; }

book_compute_period() {
  set -u
  _bw_kind="${1:-}"; _bw_today=$(date +%Y-%m-%d)
  case "$_bw_kind" in
    weekly)  _bw_s=$(_bw_date_offset "$_bw_today" -6);  _bw_slug=$(_bw_year_week)  ;;
    monthly) _bw_s=$(_bw_date_offset "$_bw_today" -29); _bw_slug=$(_bw_year_month) ;;
    *) _bw_err "지원하지 않는 kind: ${_bw_kind:-<empty>} (weekly|monthly)"; return 1 ;;
  esac
  printf '%s\n%s\n%s\n' "$_bw_s" "$_bw_today" "$_bw_slug"
}

_bw_fm_assign_one() {
  set -u
  case "$1" in
    --id)                _bwa_id="$2" ;;
    --kind)              _bwa_kind="$2" ;;
    --profile)           _bwa_profile="$2" ;;
    --title)             _bwa_title="$2" ;;
    --level)             _bwa_level="$2" ;;
    --language)          _bwa_language="$2" ;;
    --start)             _bwa_start="$2" ;;
    --end)               _bwa_end="$2" ;;
    --published-at)      _bwa_published="$2" ;;
    --chapters-json)     _bwa_chapters="$2" ;;
    --stats-json)        _bwa_stats="$2" ;;
    --estimated-minutes) _bwa_minutes="$2" ;;
    *) _bw_err "알 수 없는 옵션: $1"; return 1 ;;
  esac
}

_bw_parse_fm_args() {
  set -u
  _bwa_id=""; _bwa_kind=""; _bwa_profile=""; _bwa_title=""
  _bwa_level=""; _bwa_language=""; _bwa_start=""; _bwa_end=""
  _bwa_published=""; _bwa_chapters=""; _bwa_stats=""; _bwa_minutes=""
  while [ "$#" -gt 0 ]; do
    _bw_fm_assign_one "$1" "${2:-}" || return 1
    shift 2
  done
}

_bw_check_fm_required() {
  set -u
  for _bw_req in "$_bwa_id" "$_bwa_kind" "$_bwa_profile" "$_bwa_title" \
                 "$_bwa_start" "$_bwa_end"; do
    if [ -z "$_bw_req" ]; then
      _bw_err "필수 인자 누락 (id/kind/profile/title/start/end)"; return 1
    fi
  done
}

_bw_render_chapters() {
  set -u
  printf 'chapters:\n'
  printf '%s' "${1:-[]}" | jq -r '
    if (. | type) != "array" or length == 0 then "  []"
    else map("  - title: " + (.title // "") + "\n" +
            "    note_ids: " + ((.note_ids // []) | tojson)) | join("\n")
    end'
}

_bw_render_stats() {
  set -u
  printf 'stats:\n'
  printf '%s' "${1:-{\}}" | jq -r '
    ["  total_notes: "       + ((.total_notes // 0)       | tostring),
     "  new_topics: "        + ((.new_topics // 0)        | tostring),
     "  revisited_topics: "  + ((.revisited_topics // 0)  | tostring),
     "  user_annotated: "    + ((.user_annotated // 0)    | tostring),
     "  applied_in_code: "   + ((.applied_in_code // 0)   | tostring)
    ] | join("\n")'
}

_bw_fm_apply_defaults() {
  set -u
  [ -z "$_bwa_published" ] && _bwa_published=$(_bw_now_iso)
  [ -z "$_bwa_chapters" ]  && _bwa_chapters='[]'
  [ -z "$_bwa_stats" ]     && _bwa_stats='{}'
  [ -z "$_bwa_minutes" ]   && _bwa_minutes=0
}

_bw_fm_print_scalars() {
  set -u
  printf 'id: %s\nschema: studybook.book/v1\ntype: book\nbook_kind: %s\n' \
    "$_bwa_id" "$_bwa_kind"
  printf 'title: %s\nprofile: %s\nlevel: %s\nlanguage: %s\n' \
    "$_bwa_title" "$_bwa_profile" "${_bwa_level:-unknown}" "${_bwa_language:-ko}"
  printf 'period_start: %s\nperiod_end: %s\npublished_at: %s\n' \
    "$_bwa_start" "$_bwa_end" "$_bwa_published"
}

book_build_frontmatter() {
  set -u
  _bw_parse_fm_args "$@" || return 1
  _bw_check_fm_required  || return 1
  _bw_fm_apply_defaults
  _bw_fm_print_scalars
  _bw_render_chapters "$_bwa_chapters"
  _bw_render_stats    "$_bwa_stats"
  printf 'estimated_reading_minutes: %s\n' "$_bwa_minutes"
}

book_write() {
  set -u
  _bw_out="${1:-}"; _bw_fm="${2:-}"; _bw_body="${3:-}"
  if [ -z "$_bw_out" ] || [ -z "$_bw_fm" ]; then
    _bw_err "사용법: book_write <output_path> <frontmatter> <body>"; return 1
  fi
  _bw_dir=$(dirname "$_bw_out")
  mkdir -p "$_bw_dir" || { _bw_err "디렉터리 생성 실패: $_bw_dir"; return 1; }
  { emit_frontmatter "$_bw_fm"; printf '\n%s\n' "$_bw_body"; } > "$_bw_out" \
    || { _bw_err "파일 쓰기 실패: $_bw_out"; return 1; }
  printf '%s\n' "$_bw_out"
}

_bw_has_published_in() {
  set -u
  awk '
    BEGIN { fm=0; done=0; found=0 }
    /^---$/ {
      if (!done) { if (fm==0) { fm=1; next } else { done=1; exit } }
      else { exit }
    }
    fm==1 && !done && /^published_in:/ { found=1; exit }
    END { print (found ? "1" : "0") }' "$1"
}

_BW_PATCH_AWK='
  BEGIN { fm=0; done=0; patched=0 }
  /^---$/ {
    if (!done) {
      if (fm==0) { fm=1; print; next }
      else {
        if (!patched && mode=="append") { print "published_in: [\"" bid "\"]" }
        done=1; print; next
      }
    } else { print; next }
  }
  fm==1 && !done {
    if ($0 ~ /^published_in:/ && mode=="merge") {
      line=$0; sub("^published_in:[[:space:]]*", "", line)
      gsub(/^\[|\]$/, "", line); gsub(/[[:space:]]/, "", line)
      if (line == "") { print "published_in: [\"" bid "\"]" }
      else {
        n=split(line, arr, ","); dup=0
        for (i=1;i<=n;i++) { v=arr[i]; gsub(/^"|"$/, "", v); if (v == bid) { dup=1; break } }
        if (dup) { print $0 }
        else {
          out="["; for (i=1;i<=n;i++) { out=out arr[i] ", " }
          out=out "\"" bid "\"]"; print "published_in: " out
        }
      }
      patched=1; next
    }
    print; next
  }
  { print }'

book_update_note_published_in() {
  set -u
  _bw_note="${1:-}"; _bw_bid="${2:-}"
  if [ -z "$_bw_note" ] || [ -z "$_bw_bid" ]; then
    _bw_err "사용법: book_update_note_published_in <note_path> <book_id>"; return 1
  fi
  [ -f "$_bw_note" ] || { _bw_err "노트 파일 없음: $_bw_note"; return 1; }
  _bw_mode="append"
  [ "$(_bw_has_published_in "$_bw_note")" = "1" ] && _bw_mode="merge"
  _bw_tmp="${_bw_note}.bwtmp.$$"
  awk -v bid="$_bw_bid" -v mode="$_bw_mode" "$_BW_PATCH_AWK" \
    "$_bw_note" > "$_bw_tmp" && mv "$_bw_tmp" "$_bw_note" || {
    _bw_err "published_in 갱신 실패: $_bw_note"; rm -f "$_bw_tmp"; return 1; }
}

_BW_PI_AWK='
  BEGIN { fm=0; done=0 }
  NR==1 && $0=="---" { fm=1; next }
  fm==1 && !done && $0=="---" { done=1; exit }
  fm==1 && /^published_in:/ {
    sub("^published_in:[[:space:]]*","")
    gsub(/[[:space:]\[\]]/, "")
    if (length($0) > 0) print "1"; else print "0"; exit
  }'

_BW_ANNOT_AWK='
  BEGIN { found=0 }
  /^## 내 말로 정리/ { inblk=1; next }
  inblk && /^##[^#]/ { exit }
  inblk && /^[^<[:space:]]/ { found=1; exit }
  inblk && /^[[:space:]]*[^<[:space:]]/ { found=1; exit }
  END { print (found ? "1" : "0") }'

_BW_APPLIED_AWK='
  BEGIN { fm=0; done=0; inblk=0; c=0 }
  NR==1 && $0=="---" { fm=1; next }
  fm==1 && !done && $0=="---" { done=1; exit }
  fm==1 && /^  applied_in_code:/ { inblk=1; next }
  fm==1 && inblk && /^  [^ ]/ { exit }
  fm==1 && inblk && /^    -/ { c++; next }
  END { print (c ? c : 0) }'

_BW_WORDS_AWK='
  BEGIN { fm=0; done=0 }
  NR==1 && $0=="---" { fm=1; next }
  fm==1 && !done && $0=="---" { done=1; next }
  done { print }'

# stdout: has_pi\tannot\tapplied\twords
_bw_note_stat_line() {
  set -u
  _bw_f="$1"
  _bw_has_pi=$(awk "$_BW_PI_AWK"    "$_bw_f"); [ -z "$_bw_has_pi" ] && _bw_has_pi="0"
  _bw_annot=$(awk  "$_BW_ANNOT_AWK" "$_bw_f")
  _bw_apnum=$(awk  "$_BW_APPLIED_AWK" "$_bw_f")
  _bw_wd=$(awk     "$_BW_WORDS_AWK" "$_bw_f" | wc -w | tr -d ' ')
  printf '%s\t%s\t%s\t%s\n' "$_bw_has_pi" "$_bw_annot" "$_bw_apnum" "$_bw_wd"
}

_bw_stats_reset() {
  _bw_total=0; _bw_new=0; _bw_revisit=0
  _bw_annot_sum=0; _bw_applied_sum=0; _bw_words_sum=0
}

_bw_stats_accum_one() {
  set -u
  _bw_line="$1"
  _bw_pi=$(printf '%s' "$_bw_line" | awk -F '\t' '{print $1}')
  _bw_an=$(printf '%s' "$_bw_line" | awk -F '\t' '{print $2}')
  _bw_ap=$(printf '%s' "$_bw_line" | awk -F '\t' '{print $3}')
  _bw_wd=$(printf '%s' "$_bw_line" | awk -F '\t' '{print $4}')
  if [ "$_bw_pi" = "1" ]; then _bw_revisit=$((_bw_revisit + 1))
  else _bw_new=$((_bw_new + 1)); fi
  [ "$_bw_an" = "1" ] && _bw_annot_sum=$((_bw_annot_sum + 1))
  _bw_applied_sum=$((_bw_applied_sum + ${_bw_ap:-0}))
  _bw_words_sum=$((_bw_words_sum + ${_bw_wd:-0}))
}

_bw_stats_to_json() {
  set -u
  _bw_mins=$(( (_bw_words_sum + 249) / 250 ))
  jq -nc \
    --argjson t  "$_bw_total"       --argjson n  "$_bw_new" \
    --argjson r  "$_bw_revisit"     --argjson an "$_bw_annot_sum" \
    --argjson ap "$_bw_applied_sum" --argjson m  "$_bw_mins" \
    '{total_notes:$t, new_topics:$n, revisited_topics:$r,
      user_annotated:$an, applied_in_code:$ap, estimated_reading_minutes:$m}'
}

book_compute_stats() {
  set -u
  _bw_list="${1:-}"
  if [ -z "$_bw_list" ] || [ ! -f "$_bw_list" ]; then
    _bw_err "사용법: book_compute_stats <list_file>"; return 1
  fi
  _bw_stats_reset
  while IFS= read -r _bw_np; do
    [ -z "$_bw_np" ] && continue
    [ -f "$_bw_np" ] || continue
    _bw_total=$((_bw_total + 1))
    _bw_stats_accum_one "$(_bw_note_stat_line "$_bw_np")"
  done < "$_bw_list"
  _bw_stats_to_json
}
