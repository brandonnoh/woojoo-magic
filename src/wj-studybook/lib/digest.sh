#!/usr/bin/env bash
# digest.sh — inbox → topics 분류 파이프라인 (s10 핵심)
# Usage:
#   source src/wj-studybook/lib/digest.sh
#   digest_collect_inbox                          # stdout: 미분류 inbox 경로 (1줄/노트)
#   digest_prepare > /tmp/ctx.txt                 # Claude에 전달할 컨텍스트 출력
#   digest_apply /tmp/results.json                # Claude가 만든 JSON → 파일 적용
#   digest_archive_inbox <id1> <id2> ...          # 처리된 inbox → processed/<date>/
#
# 외부 의존: schema.sh, index-update.sh, topic-writer.sh, jq
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.
#       Claude API 직접 호출 금지 (bash 환경) — 슬래시 커맨드에서 Claude가 직접 분류.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _DG_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _DG_SRC="${(%):-%x}"
else
  _DG_SRC="$0"
fi
_DG_DIR="$(cd "$(dirname "$_DG_SRC")" && pwd)"
# shellcheck source=/dev/null
. "${_DG_DIR}/schema.sh"
# shellcheck source=/dev/null
. "${_DG_DIR}/index-update.sh"
# shellcheck source=/dev/null
. "${_DG_DIR}/topic-writer.sh"
# config-helpers는 선택적 (테스트 환경에서 부재 가능)
if [ -f "${_DG_DIR}/config-helpers.sh" ]; then
  # shellcheck source=/dev/null
  . "${_DG_DIR}/config-helpers.sh"
fi

# ── stderr ───────────────────────────────────────────────────────
_dg_err() { echo "digest.sh: $*" >&2; }

# ── 경로 헬퍼 ────────────────────────────────────────────────────
_dg_studybook_dir() {
  if command -v get_studybook_dir >/dev/null 2>&1; then
    get_studybook_dir
  else
    printf '%s\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

_dg_inbox_dir()    { printf '%s/inbox\n' "$(_dg_studybook_dir)"; }
_dg_tree_file()    { printf '%s/cache/tree.json\n' "$(_dg_studybook_dir)"; }

_dg_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then
    _dg_p=$(get_active_profile)
    [ -n "$_dg_p" ] && { printf '%s\n' "$_dg_p"; return 0; }
  fi
  printf '%s\n' "${WJ_SB_PROFILE:-default}"
}

# inbox 노트 1개에서 type 필드 추출 (frontmatter 1차 awk, 미존재 시 빈 값)
_dg_note_type() {
  set -u
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 && $0=="---" { inblk=1; next }
    inblk && $0=="---" { exit }
    inblk && /^type:/  { sub("^type:[[:space:]]*", ""); sub("[[:space:]]+$", ""); print; exit }
  ' "$1" 2>/dev/null
}

# inbox 노트의 id (frontmatter)
_dg_note_id() {
  set -u
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 && $0=="---" { inblk=1; next }
    inblk && $0=="---" { exit }
    inblk && /^id:/    { sub("^id:[[:space:]]*", ""); sub("[[:space:]]+$", ""); print; exit }
  ' "$1" 2>/dev/null
}

# ── 공개: 미분류 inbox 수집 ─────────────────────────────────────
# stdout: 한 줄당 inbox 노트 절대 경로
# 제외: processed/ 하위, type=session_summary
digest_collect_inbox() {
  set -u
  _dg_dir="$(_dg_inbox_dir)"
  [ -d "$_dg_dir" ] || return 0
  while IFS= read -r _dg_f; do
    [ -z "$_dg_f" ] && continue
    case "$_dg_f" in *"/processed/"*) continue ;; esac
    _dg_t=$(_dg_note_type "$_dg_f")
    [ "$_dg_t" = "session_summary" ] && continue
    printf '%s\n' "$_dg_f"
  done < <(find "$_dg_dir" -maxdepth 2 -type f -name '*.md' 2>/dev/null | sort)
}

# ── 공개: Claude에 전달할 컨텍스트 prepare ───────────────────────
_dg_print_profile_block() {
  set -u
  _dg_pname=$(_dg_active_profile)
  printf '## ACTIVE_PROFILE\n%s\n\n' "$_dg_pname"
  if command -v get_studybook_dir >/dev/null 2>&1; then
    _dg_yaml="$(get_profiles_dir 2>/dev/null)/${_dg_pname}.yaml"
    if [ -f "$_dg_yaml" ]; then
      printf '## PROFILE_YAML\n'; cat "$_dg_yaml"; printf '\n'
    fi
  fi
}

_dg_print_tree_block() {
  set -u
  _dg_tf=$(_dg_tree_file)
  printf '## CURRENT_TREE_JSON\n'
  if [ -f "$_dg_tf" ]; then
    # 카테고리/서브카테고리/토픽 이름 목록만 출력 (note_count 등 제거 — 토큰 절감)
    jq '[.tree | to_entries[] | {
      category: .key,
      subcategories: (.value.subtopics // {} | to_entries | map({
        name: .key,
        topics: (.value.subtopics // {} | keys)
      }))
    }]' "$_dg_tf" 2>/dev/null || printf '[]'
  else
    printf '[]'
  fi
  printf '\n\n'
}

_dg_print_inbox_block() {
  set -u
  _dg_count=0
  _dg_batch_max="${WJ_SB_DIGEST_BATCH_SIZE:-20}"
  printf '## INBOX_NOTES\n'
  while IFS= read -r _dg_f; do
    [ -z "$_dg_f" ] && continue
    [ "$_dg_count" -ge "$_dg_batch_max" ] && break
    _dg_count=$((_dg_count + 1))
    _dg_id=$(_dg_note_id "$_dg_f")
    printf -- '--- INBOX_BEGIN id=%s path=%s ---\n' "$_dg_id" "$_dg_f"
    # frontmatter만 출력 (라우팅에 충분)
    awk 'NR==1&&/^---/{p=1} p{print} p&&NR>1&&/^---/{p=0;exit}' "$_dg_f"
    printf '\n'
    # 본문 첫 200자 (시맨틱 분류 힌트용)
    awk '/^---/{n++;if(n==2){p=1;next}} p{print}' "$_dg_f" 2>/dev/null | head -c 200
    printf '\n...[본문 생략 — 에이전트가 path 경로에서 직접 read]\n'
    printf -- '--- INBOX_END id=%s ---\n\n' "$_dg_id"
  done < <(digest_collect_inbox)
  printf '## INBOX_COUNT\n%s\n' "$_dg_count"
}

digest_prepare() {
  set -u
  printf '# wj-studybook digest 컨텍스트\n\n'
  _dg_print_profile_block
  _dg_print_tree_block
  _dg_print_inbox_block
}

# ── 공개: 토픽 버킷용 prepare (서브에이전트 병렬 실행 지원) ─────────
# Usage: digest_prepare_bucket <routing_json_file> <category>/<subcategory>/<topic>
# 라우팅 JSON은 auto 모드 1단계에서 만든 배열. 이 함수는 해당 토픽 버킷에 속한
# inbox만 골라 서브에이전트 컨텍스트를 출력한다.
digest_prepare_bucket() {
  set -u
  _dg_route_file="${1:-}"
  _dg_bkey="${2:-}"
  if [ -z "$_dg_route_file" ] || [ ! -f "$_dg_route_file" ]; then
    _dg_err "사용법: digest_prepare_bucket <routing_json> <category/subcategory/topic>"
    return 1
  fi
  if [ -z "$_dg_bkey" ]; then
    _dg_err "topic 키가 비어있음 (형식: category/subcategory/topic)"
    return 1
  fi
  # 키 파싱
  _dg_bcat=$(printf '%s' "$_dg_bkey" | awk -F/ '{print $1}')
  _dg_bsub=$(printf '%s' "$_dg_bkey" | awk -F/ '{print $2}')
  _dg_btop=$(printf '%s' "$_dg_bkey" | awk -F/ '{print $3}')
  if [ -z "$_dg_bcat" ] || [ -z "$_dg_bsub" ] || [ -z "$_dg_btop" ]; then
    _dg_err "topic 키 형식 오류: $_dg_bkey"
    return 1
  fi
  # 해당 버킷 inbox_id 목록 추출
  _dg_bucket_ids=$(jq -r --arg c "$_dg_bcat" --arg s "$_dg_bsub" --arg t "$_dg_btop" \
    '.[] | select(.category==$c and .subcategory==$s and .topic==$t) | .inbox_id' \
    "$_dg_route_file")
  if [ -z "$_dg_bucket_ids" ]; then
    _dg_err "버킷 비어있음: $_dg_bkey"
    return 1
  fi
  printf '# wj-studybook digest 버킷 컨텍스트\n\n'
  _dg_print_profile_block
  _dg_print_tree_block
  printf '## TOPIC_KEY\n%s\n\n' "$_dg_bkey"
  printf '## INBOX_NOTES\n'
  _dg_bcount=0
  while IFS= read -r _dg_id; do
    [ -z "$_dg_id" ] && continue
    _dg_f=$(_dg_find_inbox_by_id "$_dg_id" 2>/dev/null) || continue
    [ -z "$_dg_f" ] && continue
    _dg_bcount=$((_dg_bcount + 1))
    printf -- '--- INBOX_BEGIN id=%s path=%s ---\n' "$_dg_id" "$_dg_f"
    cat "$_dg_f"
    printf '\n--- INBOX_END id=%s ---\n\n' "$_dg_id"
  done <<EOF
$_dg_bucket_ids
EOF
  printf '## INBOX_COUNT\n%s\n' "$_dg_bcount"
}

# ── 공개: Claude 분류 결과 → 파일 적용 ───────────────────────────
# 입력 JSON 형식 (배열):
#   [{"inbox_id":"...","category":"...","subcategory":"...","topic":"...",
#     "subtopic":"...","title":"...","slug":"...","tags":[...],"body":"..."}]
# 각 inbox_id는 frontmatter id 필드와 매칭되어야 함.

# inbox 경로를 id로 검색 (없으면 빈 문자열)
_dg_find_inbox_by_id() {
  set -u
  _dg_target_id="$1"
  while IFS= read -r _dg_f; do
    [ -z "$_dg_f" ] && continue
    _dg_iid=$(_dg_note_id "$_dg_f")
    if [ "$_dg_iid" = "$_dg_target_id" ]; then
      printf '%s\n' "$_dg_f"; return 0
    fi
  done < <(digest_collect_inbox)
  return 1
}

# inbox 노트 frontmatter에서 sources[] 1건 구성용 필드 추출 → JSON 객체
_dg_inbox_source_json() {
  set -u
  _dg_src_path="$1"; _dg_src_id="$2"
  _dg_yaml=$(read_frontmatter "$_dg_src_path" 2>/dev/null) || _dg_yaml=""
  _dg_cap=$(printf '%s\n' "$_dg_yaml" | awk '/^captured_at:/ {sub("^captured_at:[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit}')
  _dg_sid=$(printf '%s\n' "$_dg_yaml" | awk '/^session_id:/  {sub("^session_id:[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit}')
  _dg_mdl=$(printf '%s\n' "$_dg_yaml" | awk '/^model:/        {sub("^model:[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit}')
  jq -nc --arg id "$_dg_src_id" --arg cap "$_dg_cap" \
         --arg sid "$_dg_sid" --arg mdl "$_dg_mdl" \
    '{inbox_id:$id, captured_at:$cap, session_id:$sid, model:$mdl}'
}

# _dg_validate_slug — slug 형식 검증 (^[a-z0-9-]+$ 만 허용)
_dg_validate_slug() {
  _dg_vs_val="$1"
  if ! printf '%s' "$_dg_vs_val" | grep -qE '^[a-z0-9-]+$'; then
    echo "[ERROR] 잘못된 카테고리/슬러그: $_dg_vs_val" >&2; return 1
  fi
  return 0
}

# 분류 1건 처리 (jq로 한 객체 추출 → write_topic_note)
_dg_apply_one() {
  set -u
  _dg_obj="$1"; _dg_profile="$2"; _dg_level="$3"; _dg_lang="$4"
  _dg_iid=$(printf '%s' "$_dg_obj" | jq -r '.inbox_id')
  _dg_cat=$(printf '%s' "$_dg_obj" | jq -r '.category')
  _dg_sub=$(printf '%s' "$_dg_obj" | jq -r '.subcategory')
  _dg_top=$(printf '%s' "$_dg_obj" | jq -r '.topic')
  _dg_subtop=$(printf '%s' "$_dg_obj" | jq -r '.subtopic // ""')
  _dg_title=$(printf '%s' "$_dg_obj" | jq -r '.title')
  _dg_slug=$(printf '%s' "$_dg_obj" | jq -r '.slug')
  # slug 형식 검증
  _dg_validate_slug "$_dg_slug" || return 1
  _dg_tags_csv=$(printf '%s' "$_dg_obj" | jq -r '(.tags // []) | join(",")')
  _dg_body=$(printf '%s' "$_dg_obj" | jq -r '.body // ""')
  _dg_inbox_path=$(_dg_find_inbox_by_id "$_dg_iid") || {
    _dg_err "inbox_id 매칭 실패: $_dg_iid"; return 1; }
  _dg_src1=$(_dg_inbox_source_json "$_dg_inbox_path" "$_dg_iid")
  _dg_sources_json=$(jq -nc --argjson s "$_dg_src1" '[$s]')
  _dg_out=$(write_topic_note \
    --profile "$_dg_profile" \
    --category "$_dg_cat" --subcategory "$_dg_sub" --topic "$_dg_top" \
    --subtopic "$_dg_subtop" \
    --title "$_dg_title" --slug "$_dg_slug" \
    --tags "$_dg_tags_csv" --body "$_dg_body" \
    --sources-json "$_dg_sources_json" \
    --level "$_dg_level" --language "$_dg_lang") || return 1
  printf '%s\t%s\n' "$_dg_iid" "$_dg_out"
}

# 활성 프로필에서 level/language 추출 (없으면 기본값)
_dg_profile_field() {
  set -u
  _dg_field="$1"; _dg_default="$2"
  _dg_pn=$(_dg_active_profile)
  _dg_yf=""
  if command -v get_profiles_dir >/dev/null 2>&1; then
    _dg_yf="$(get_profiles_dir)/${_dg_pn}.yaml"
  fi
  if [ -f "$_dg_yf" ]; then
    _dg_v=$(awk -v k="$_dg_field" '$0 ~ "^"k":" {sub("^"k":[[:space:]]*",""); sub("[[:space:]]+$",""); print; exit}' "$_dg_yf")
    [ -n "$_dg_v" ] && { printf '%s\n' "$_dg_v"; return 0; }
  fi
  printf '%s\n' "$_dg_default"
}

digest_apply() {
  set -u
  _dg_json_file="${1:-}"
  if [ -z "$_dg_json_file" ] || [ ! -f "$_dg_json_file" ]; then
    _dg_err "사용법: digest_apply <json_file>"; return 1
  fi
  if ! jq -e 'type=="array"' "$_dg_json_file" >/dev/null 2>&1; then
    _dg_err "최상위는 JSON 배열이어야 함: $_dg_json_file"; return 1
  fi
  _dg_profile=$(_dg_active_profile)
  _dg_lvl=$(_dg_profile_field "level" "unknown")
  _dg_lng=$(_dg_profile_field "language" "ko")
  _dg_processed_ids=""
  _dg_n=0
  while IFS= read -r _dg_obj; do
    [ -z "$_dg_obj" ] && continue
    _dg_line=$(_dg_apply_one "$_dg_obj" "$_dg_profile" "$_dg_lvl" "$_dg_lng") || return 1
    _dg_iid_done=$(printf '%s' "$_dg_line" | awk -F '\t' '{print $1}')
    _dg_processed_ids="${_dg_processed_ids} ${_dg_iid_done}"
    _dg_n=$((_dg_n + 1))
  done < <(jq -c '.[]' "$_dg_json_file")
  if [ "$_dg_n" -gt 0 ]; then
    # shellcheck disable=SC2086
    digest_archive_inbox $_dg_processed_ids || return 1
    _dg_i=0
    while [ "$_dg_i" -lt "$_dg_n" ]; do
      update_tree_unsorted_decrement || return 1
      _dg_i=$((_dg_i + 1))
    done
  fi
  printf 'digest_apply: %d개 분류 완료\n' "$_dg_n"
}

# ── 공개: 처리된 inbox → processed/<YYYY-MM-DD>/ 이동 ─────────────
digest_archive_inbox() {
  set -u
  if [ "$#" -eq 0 ]; then return 0; fi
  _dg_date=$(date +%Y-%m-%d)
  _dg_pdir="$(_dg_inbox_dir)/processed/${_dg_date}"
  mkdir -p "$_dg_pdir" || { _dg_err "processed 폴더 생성 실패: $_dg_pdir"; return 1; }
  for _dg_arg_id in "$@"; do
    [ -z "$_dg_arg_id" ] && continue
    _dg_p=$(_dg_find_inbox_by_id "$_dg_arg_id") || {
      _dg_err "archive: inbox_id 매칭 실패: $_dg_arg_id"; return 1; }
    _dg_base=$(basename "$_dg_p")
    mv "$_dg_p" "${_dg_pdir}/${_dg_base}" || {
      _dg_err "이동 실패: $_dg_p"; return 1; }
  done
  return 0
}
