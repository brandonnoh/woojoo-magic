#!/usr/bin/env bash
# similar.sh — /wj:studybook similar <쿼리> 구현 (s11)
# Usage:
#   source src/wj-studybook/lib/similar.sh
#   similar_keyword_match "<query>"              # stdout: 후보 노트 경로 (최대 20줄)
#   echo "$candidates" | similar_semantic_rank "<query>"
#                                                # stdout: Claude에 전달할 컨텍스트
#   similar_format_output "<json_results>"       # stdout: 사람 친화 출력 (Top 5)
#
# 외부 의존: config-helpers.sh, jq, ripgrep(rg) — rg 없으면 grep fallback.
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.
#       Claude API 직접 호출 금지 — semantic_rank는 "컨텍스트 패키징"만 수행.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _SIM_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _SIM_SRC="${(%):-%x}"
else
  _SIM_SRC="$0"
fi
_SIM_DIR="$(cd "$(dirname "$_SIM_SRC")" && pwd)"
if [ -f "${_SIM_DIR}/config-helpers.sh" ] && ! command -v get_active_profile >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_SIM_DIR}/config-helpers.sh"
fi

# ── stderr ───────────────────────────────────────────────────────
_sim_err() { echo "similar.sh: $*" >&2; }

# ── 내부: 경로/프로필 ────────────────────────────────────────────
_sim_studybook_dir() {
  if command -v get_studybook_dir >/dev/null 2>&1; then
    get_studybook_dir
  else
    printf '%s\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

_sim_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then
    _sim_p=$(get_active_profile)
    [ -n "$_sim_p" ] && { printf '%s\n' "$_sim_p"; return 0; }
  fi
  printf '%s\n' "${WJ_SB_PROFILE:-default}"
}

_sim_topics_dir() {
  set -u
  _sim_prof=$(_sim_active_profile)
  printf '%s/books/%s/topics\n' "$(_sim_studybook_dir)" "$_sim_prof"
}

_sim_tree_file() {
  printf '%s/cache/tree.json\n' "$(_sim_studybook_dir)"
}

# ── 내부: 검색 엔진 선택 (rg 우선, 없으면 grep) ───────────────────
# stdout: 매칭된 파일 경로 (중복 제거) — 한 줄당 1개
_sim_search_files() {
  set -u
  _sim_pat="$1"; _sim_root="$2"
  [ -d "$_sim_root" ] || return 0
  if command -v rg >/dev/null 2>&1; then
    rg --no-messages --files-with-matches --fixed-strings --ignore-case \
       --glob '*.md' -- "$_sim_pat" "$_sim_root" 2>/dev/null | sort -u
  else
    grep -rIl --include='*.md' -F -i -- "$_sim_pat" "$_sim_root" 2>/dev/null | sort -u
  fi
}

# ── 공개: 1차 키워드 매칭 ────────────────────────────────────────
# 입력: query 문자열
# 출력: 활성 프로필의 topics/ 하위 md 파일 중 매칭된 경로 (최대 20줄)
similar_keyword_match() {
  set -u
  _sim_q="${1:-}"
  if [ -z "$_sim_q" ]; then
    _sim_err "사용법: similar_keyword_match <query>"
    return 1
  fi
  _sim_root=$(_sim_topics_dir)
  [ -d "$_sim_root" ] || return 0
  _sim_search_files "$_sim_q" "$_sim_root" | head -n 20
}

# ── 내부: 파일 앞부분 200자(본문) 추출 ───────────────────────────
# frontmatter(--- ... ---) 제거 후 첫 200자 한 줄로.
_sim_body_snippet() {
  set -u
  _sim_f="${1:-}"
  [ -f "$_sim_f" ] || { printf ''; return 0; }
  awk '
    BEGIN { infm=0; done=0 }
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" { infm=0; done=1; next }
    !infm && done { print }
  ' "$_sim_f" \
    | tr '\n' ' ' \
    | awk '{ s=$0; gsub(/[[:space:]]+/, " ", s); print substr(s, 1, 200) }'
}

# ── 내부: 파일 제목 추출 (frontmatter title:) ────────────────────
_sim_title() {
  set -u
  _sim_ft="${1:-}"
  [ -f "$_sim_ft" ] || { printf ''; return 0; }
  awk '
    NR==1 && $0!="---" { exit }
    NR==1 && $0=="---" { inblk=1; next }
    inblk && $0=="---" { exit }
    inblk && /^title:/ {
      sub("^title:[[:space:]]*", ""); sub("[[:space:]]+$", ""); print; exit
    }
  ' "$_sim_ft" 2>/dev/null
}

# ── 공개: 2차 의미적 유사도용 컨텍스트 패키징 ────────────────────
# stdin: 후보 파일 경로 (한 줄당 1개) — similar_keyword_match 출력 pipe
# 인자: query
# 출력: Claude에 전달할 컨텍스트 (QUERY / CURRENT_TREE_JSON / CANDIDATES)
similar_semantic_rank() {
  set -u
  _sim_q2="${1:-}"
  if [ -z "$_sim_q2" ]; then
    _sim_err "사용법: similar_semantic_rank <query> (후보는 stdin)"
    return 1
  fi
  printf '# wj-studybook similar 컨텍스트\n\n'
  printf '## QUERY\n%s\n\n' "$_sim_q2"
  printf '## CURRENT_TREE_JSON\n'
  _sim_tf=$(_sim_tree_file)
  if [ -f "$_sim_tf" ]; then cat "$_sim_tf"; else printf '{}'; fi
  printf '\n\n'
  printf '## CANDIDATES\n'
  _sim_n=0
  while IFS= read -r _sim_cf; do
    [ -z "$_sim_cf" ] && continue
    [ -f "$_sim_cf" ] || continue
    _sim_n=$((_sim_n + 1))
    _sim_ct=$(_sim_title "$_sim_cf")
    _sim_cs=$(_sim_body_snippet "$_sim_cf")
    printf -- '--- CANDIDATE_BEGIN path=%s title=%s ---\n' "$_sim_cf" "$_sim_ct"
    printf '%s\n' "$_sim_cs"
    printf -- '--- CANDIDATE_END ---\n\n'
  done
  printf '## CANDIDATE_COUNT\n%s\n' "$_sim_n"
}

# ── 공개: Claude 결과 JSON → 사람 친화 출력 ─────────────────────
# 입력: JSON 배열 문자열 [{"path":"...","score":95,"summary":"..."}]
# 출력: 경로 (점수%) — 요약 형식, Top 5로 정렬 후 제한
similar_format_output() {
  set -u
  _sim_json="${1:-}"
  if [ -z "$_sim_json" ]; then
    _sim_err "사용법: similar_format_output <json_array>"
    return 1
  fi
  if ! printf '%s' "$_sim_json" | jq -e 'type=="array"' >/dev/null 2>&1; then
    _sim_err "JSON 배열이 아님"
    return 1
  fi
  _sim_len=$(printf '%s' "$_sim_json" | jq 'length')
  if [ "$_sim_len" = "0" ]; then
    printf '유사한 노트를 찾지 못했습니다 (결과 없음).\n'
    return 0
  fi
  printf '%s' "$_sim_json" \
    | jq -r 'sort_by(-(.score // 0)) | .[0:5][]
             | "\(.path) (\(.score // 0)%) — \(.summary // "")"'
}
