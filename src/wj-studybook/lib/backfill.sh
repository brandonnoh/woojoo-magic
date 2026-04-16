#!/usr/bin/env bash
# backfill.sh — /wj:studybook backfill 구현 (s14)
# 공개 함수:
#   backfill_find_sessions   --since <YYYY-MM-DD> [--project <name>] [--all]
#   backfill_process_session <jsonl_path> <since_date>
#   backfill_progress        <current_idx> <total>
#   backfill_run             --since <YYYY-MM-DD> [--project <name>] [--all]
#
# 외부 의존: jq, shasum, date, sed, grep, awk
# 의존 라이브러리: schema.sh, inbox-writer.sh, filter.sh, transcript-parser.sh,
#                 index-update.sh (update_tree_unsorted_increment)
# 주의: source 전용. set -euo pipefail은 호출자 책임. silent catch 금지.
#       메인 루프 변수 prefix `_bf_*` (local 금지).

# ── source guard + sibling 로드 ──────────────────────────────────

if [ -n "${BASH_SOURCE:-}" ]; then _BF_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _BF_SRC="${(%):-%x}"
else _BF_SRC="$0"; fi
_BF_DIR="$(cd "$(dirname "$_BF_SRC")" && pwd)"

# shellcheck source=/dev/null
command -v ulid_generate                 >/dev/null 2>&1 || . "${_BF_DIR}/schema.sh"
# shellcheck source=/dev/null
command -v write_inbox_note              >/dev/null 2>&1 || . "${_BF_DIR}/inbox-writer.sh"
# shellcheck source=/dev/null
command -v is_educational                >/dev/null 2>&1 || . "${_BF_DIR}/filter.sh"
# shellcheck source=/dev/null
command -v extract_all_assistant_texts   >/dev/null 2>&1 || . "${_BF_DIR}/transcript-parser.sh"
# shellcheck source=/dev/null
command -v update_tree_unsorted_increment >/dev/null 2>&1 || . "${_BF_DIR}/index-update.sh"

# ── 내부 헬퍼 ────────────────────────────────────────────────────

_bf_err() { echo "backfill.sh: $*" >&2; }

# --since 날짜 검증 (YYYY-MM-DD). 유효하면 0, 아니면 1.
_bf_validate_date() {
  set -u
  _bf_d="${1:-}"
  printf '%s' "$_bf_d" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
  # macOS/Linux 공통 검증
  if date -j -f '%Y-%m-%d' "$_bf_d" +%s >/dev/null 2>&1; then return 0; fi
  date -d "$_bf_d" +%s >/dev/null 2>&1
}

# 본문 SHA256 (frontmatter 제거하지 않은 raw 텍스트 해시)
_bf_hash_text() {
  set -u
  printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
}

# inbox/*.md 본문(frontmatter --- 제외) SHA256 인덱스 출력
_bf_build_inbox_hash_index() {
  set -u
  _bf_dir="${HOME}/.studybook/inbox"
  [ -d "$_bf_dir" ] || return 0
  for _bf_f in "$_bf_dir"/*.md; do
    [ -f "$_bf_f" ] || continue
    _bf_body=$(awk '
      BEGIN { fm=0; done=0 }
      NR==1 && $0=="---" { fm=1; next }
      fm==1 && !done && $0=="---" { done=1; next }
      done==1 { print }
    ' "$_bf_f")
    _bf_body=$(printf '%s' "$_bf_body" | sed '1{/^$/d;}')
    [ -z "$_bf_body" ] && continue
    _bf_hash_text "$_bf_body"
  done
}

# 입력 파싱 (--since / --project / --all)
# 전역 변수 _bf_since / _bf_project / _bf_all 에 할당
_bf_parse_args() {
  set -u
  _bf_since=""; _bf_project=""; _bf_all=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --since)   _bf_since="${2:-}"; shift 2 ;;
      --project) _bf_project="${2:-}"; shift 2 ;;
      --all)     _bf_all=1; shift ;;
      *) _bf_err "알 수 없는 옵션: $1"; return 1 ;;
    esac
  done
  if [ "$_bf_all" -eq 0 ] && [ -z "$_bf_since" ]; then
    _bf_err "--since <YYYY-MM-DD> 또는 --all 필요"; return 1
  fi
  if [ "$_bf_all" -eq 0 ] && ! _bf_validate_date "$_bf_since"; then
    _bf_err "잘못된 날짜 형식 (YYYY-MM-DD 필요): $_bf_since"; return 1
  fi
}

# 인코딩된 디렉터리 이름이 --project 필터와 일치하는지 검사.
# 일치 규칙: 디렉터리 이름이 `-<project>`로 끝나거나 정확히 `-<project>` (basename 규칙)
_bf_match_project() {
  set -u
  _bf_dir_name="$1"; _bf_proj="$2"
  case "$_bf_dir_name" in
    *"-${_bf_proj}") return 0 ;;
    "${_bf_proj}")   return 0 ;;
  esac
  return 1
}

# transcript 레코드의 timestamp가 since_date(YYYY-MM-DD) 이후인지 판정.
# jq로 substr(0,10) 후 lexicographic 비교.
_bf_is_after_since() {
  set -u
  _bf_ts="$1"; _bf_s="$2"
  [ -z "$_bf_ts" ] && return 1
  _bf_day=$(printf '%s' "$_bf_ts" | awk '{print substr($0,1,10)}')
  awk -v d="$_bf_day" -v s="$_bf_s" 'BEGIN { exit (d >= s) ? 0 : 1 }'
}

# jsonl에서 (timestamp, text) 쌍을 NUL 구분으로 출력.
# 한 줄당: timestamp\ttext\0
_bf_extract_pairs() {
  set -u
  _bf_file="${1:-}"
  [ -f "$_bf_file" ] || { _bf_err "transcript 없음: $_bf_file"; return 1; }
  jq -j '
    select(.type == "assistant")
    | . as $rec
    | .message.content[]?
    | select(.type == "text")
    | .text as $t
    | select($t != null and $t != "")
    | (($rec.timestamp // "") + "\t" + $t + "\u0000")
  ' "$_bf_file"
}

# ── 공개 함수 ────────────────────────────────────────────────────

# backfill_find_sessions --since <date> [--project <name>] [--all]
# stdout: jsonl 파일 경로 목록 (한 줄씩, 정렬)
backfill_find_sessions() {
  set -u
  _bf_parse_args "$@" || return 1
  _bf_root="${HOME}/.claude/projects"
  [ -d "$_bf_root" ] || return 0
  for _bf_pd in "$_bf_root"/*/; do
    [ -d "$_bf_pd" ] || continue
    _bf_pname=$(basename "$_bf_pd")
    if [ -n "$_bf_project" ] && ! _bf_match_project "$_bf_pname" "$_bf_project"; then
      continue
    fi
    for _bf_jf in "$_bf_pd"*.jsonl; do
      [ -f "$_bf_jf" ] || continue
      printf '%s\n' "$_bf_jf"
    done
  done | sort
}

# 세션 파일에서 last assistant model 추출 (없으면 "unknown")
_bf_extract_model() {
  set -u
  _bf_m=$(jq -rs '
    (map(select(.type == "assistant" and .message.model != null))
     | last | .message.model) // "unknown"
  ' "$1" 2>/dev/null || echo "unknown")
  [ -z "$_bf_m" ] || [ "$_bf_m" = "null" ] && _bf_m="unknown"
  printf '%s\n' "$_bf_m"
}

# 하나의 text 블록을 inbox에 기록 (write_inbox_note + hook_source 패치).
# 성공 시 stdout=파일경로, 실패 시 return 1.
_bf_write_one_note() {
  set -u
  _bf_w_sid="$1"; _bf_w_pname="$2"; _bf_w_model="$3"
  _bf_w_txt="$4"; _bf_w_est="$5"
  _bf_w_out=$(WJ_SB_HOOK_SOURCE="backfill" write_inbox_note \
    --session-id "$_bf_w_sid" --project "$_bf_w_pname" \
    --project-path "" --branch "" --model "$_bf_w_model" \
    --user-prompt "" --content "$_bf_w_txt" \
    --estimated-value "$_bf_w_est") || return 1
  [ -f "$_bf_w_out" ] || return 1
  _bf_w_tmp="${_bf_w_out}.tmp.$$"
  sed 's/^hook_source: stop$/hook_source: backfill/' "$_bf_w_out" > "$_bf_w_tmp" \
    && mv "$_bf_w_tmp" "$_bf_w_out"
  update_tree_unsorted_increment 2>/dev/null || true
  printf '%s\n' "$_bf_w_out"
}

# 한 pair(timestamp\ttext) 검사 + 필요 시 inbox 기록. 성공 시 0, skip 시 1.
# 전역 사용: _bf_existing(업데이트), _bf_sid, _bf_pname, _bf_model, _bf_since_p
_bf_handle_pair() {
  set -u
  _bf_p_ts="${1%%	*}"; _bf_p_txt="${1#*	}"
  [ -z "$_bf_p_txt" ] && return 1
  _bf_is_after_since "$_bf_p_ts" "$_bf_since_p" || return 1
  is_educational "$_bf_p_txt" || return 1
  _bf_p_red=$(redact_sensitive "$_bf_p_txt")
  _bf_p_h=$(_bf_hash_text "$_bf_p_red")
  printf '%s\n' "$_bf_existing" | grep -Fxq "$_bf_p_h" && return 1
  _bf_p_est=$(estimate_value "$_bf_p_txt")
  _bf_write_one_note "$_bf_sid" "$_bf_pname" "$_bf_model" "$_bf_p_red" "$_bf_p_est" \
    >/dev/null || { _bf_err "write_inbox_note 실패 (skip 1건)"; return 1; }
  _bf_existing=$(printf '%s\n%s' "$_bf_existing" "$_bf_p_h")
  return 0
}

# backfill_process_session <jsonl_path> <since_date>
# 세션 1개 처리. stdout: 추가된 노트 개수 (단일 숫자).
# hook_source=backfill로 태깅. SHA256 dedup.
backfill_process_session() {
  set -u
  _bf_jsonl="${1:-}"; _bf_since_p="${2:-}"
  if [ -z "$_bf_jsonl" ] || [ ! -f "$_bf_jsonl" ]; then
    _bf_err "jsonl 경로 필요: ${_bf_jsonl:-<empty>}"; return 1
  fi
  [ -z "$_bf_since_p" ] && _bf_since_p="0000-01-01"
  _bf_existing=$(_bf_build_inbox_hash_index || true)
  _bf_added=0
  _bf_pname=$(basename "$(dirname "$_bf_jsonl")")
  _bf_sid=$(basename "$_bf_jsonl" .jsonl)
  _bf_model=$(_bf_extract_model "$_bf_jsonl")
  while IFS= read -r -d '' _bf_pair; do
    [ -z "$_bf_pair" ] && continue
    _bf_handle_pair "$_bf_pair" && _bf_added=$((_bf_added + 1)) || true
  done < <(_bf_extract_pairs "$_bf_jsonl")
  printf '%s\n' "$_bf_added"
}

# backfill_progress <current> <total> — stderr 진행률 1줄
backfill_progress() {
  set -u
  _bf_cur="${1:-0}"; _bf_tot="${2:-0}"
  printf '[%s/%s] ...\n' "$_bf_cur" "$_bf_tot" >&2
}

# run 내부: 파싱된 인자 기반으로 세션 목록 수집 (stdout=jsonl 경로 목록).
# 전제: 호출자가 _bf_effective_since 를 사전에 설정.
_bf_resolve_sessions() {
  set -u
  if [ "$_bf_all" -eq 1 ]; then
    backfill_find_sessions --all ${_bf_project:+--project "$_bf_project"}
  else
    backfill_find_sessions --since "$_bf_since" ${_bf_project:+--project "$_bf_project"}
  fi
}

# 세션 목록 루프. here-string 입력. stdout=총 추가 개수.
# 전역 사용: _bf_effective_since
_bf_run_loop() {
  set -u
  _bf_l_total="$1"; _bf_l_idx=0; _bf_l_added=0
  while IFS= read -r _bf_l_jf; do
    [ -z "$_bf_l_jf" ] && continue
    _bf_l_idx=$((_bf_l_idx + 1))
    backfill_progress "$_bf_l_idx" "$_bf_l_total"
    _bf_l_n=$(backfill_process_session "$_bf_l_jf" "$_bf_effective_since" 2>/dev/null || echo 0)
    case "$_bf_l_n" in ''|*[!0-9]*) _bf_l_n=0 ;; esac
    _bf_l_added=$((_bf_l_added + _bf_l_n))
  done
  printf '%s\n' "$_bf_l_added"
}

# backfill_run --since <date> [--project <name>] [--all]
# 라우터가 호출하는 오케스트레이터.
backfill_run() {
  set -u
  _bf_parse_args "$@" || return 1
  if [ "$_bf_all" -eq 1 ]; then _bf_effective_since="0000-01-01"
  else _bf_effective_since="$_bf_since"; fi
  _bf_sessions=$(_bf_resolve_sessions) || return 1
  if [ -z "$_bf_sessions" ]; then
    printf '대상 세션이 없습니다. (0개 노트 추가)\n'; return 0
  fi
  _bf_total=$(printf '%s\n' "$_bf_sessions" | grep -c '\.jsonl$' || true)
  _bf_total_added=$(_bf_run_loop "$_bf_total" <<< "$_bf_sessions")
  printf '%s개 노트가 inbox에 추가되었습니다. /wj:studybook digest로 분류하세요.\n' "$_bf_total_added"
}
