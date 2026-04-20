#!/usr/bin/env bash
# capture-stop.sh — Stop hook: 어시스턴트 발화 → ~/.studybook/inbox 저장
#
# 입력: stdin JSON (Claude Code Stop hook 페이로드)
#   { session_id, transcript_path, cwd, last_assistant_message }
#
# 동작:
#   1) last_assistant_message 우선 추출, 없으면 transcript_path fallback
#   2) 빈 메시지(도구 호출만) → exit 0
#   3) 사용자 prompt / git branch / model 메타 수집
#   4) write_inbox_note 호출 → ~/.studybook/inbox/<date>-<ulid>.md 생성
#
# 통합 placeholder (이 task에서는 미적용):
#   - s4(filter): 저장 전 noise 필터
#   - s5(tree.json): unsorted_count +1
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/config-helpers.sh
source "${_plugin_root}/lib/config-helpers.sh"

# 일시정지 체크
if [ -f "$(get_studybook_dir)/.paused" ]; then
  exit 0
fi

# shellcheck source=../lib/schema.sh
source "${_plugin_root}/lib/schema.sh"
# shellcheck source=../lib/inbox-writer.sh
source "${_plugin_root}/lib/inbox-writer.sh"
# shellcheck source=../lib/filter.sh
source "${_plugin_root}/lib/filter.sh"

# ── 입력 파싱 ────────────────────────────────────────────────────

_cs_err() { echo "capture-stop.sh: $*" >&2; }

_cs_auto_digest() {
  if [ "${WJ_SB_DIGEST_DISABLE:-0}" = "1" ]; then
    _cs_err "auto-digest skipped (WJ_SB_DIGEST_DISABLE=1)"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    _cs_err "auto-digest skipped (claude CLI not found)"
    return 0
  fi
  _sb_dir=$(get_studybook_dir)
  _inbox_dir="${_sb_dir}/inbox"
  [ -d "$_inbox_dir" ] || return 0
  _unsorted=0
  for _f in "$_inbox_dir"/*.md; do
    [ -f "$_f" ] || continue
    _t=$(awk '
      NR==1 && $0!="---" { exit }
      NR==1 && $0=="---" { inblk=1; next }
      inblk && $0=="---" { exit }
      inblk && /^type:/  { sub("^type:[[:space:]]*", ""); sub("[[:space:]]+$", ""); print; exit }
    ' "$_f" 2>/dev/null)
    [ "$_t" = "inbox" ] && _unsorted=$((_unsorted + 1))
  done
  [ "$_unsorted" -lt 10 ] && return 0
  _lock="${_sb_dir}/.digest.lock"
  if ! ( set -o noclobber; : > "$_lock" ) 2>/dev/null; then
    _cs_err "auto-digest already running (lock: $_lock), skip"
    return 0
  fi
  _log_dir="${_sb_dir}/.logs"
  mkdir -p "$_log_dir" 2>/dev/null || true
  _log="${_log_dir}/digest-$(date +%s)-$$.log"
  ( setsid nohup sh -c '
      trap "rm -f \"$0\"" EXIT INT TERM
      claude -p "/wj-studybook:digest auto"
    ' "$_lock" >"$_log" 2>&1 </dev/null & ) 2>/dev/null || {
      _cs_err "auto-digest spawn failed, removing lock"
      rm -f "$_lock"
      return 0
    }
  _cs_err "auto-digest spawned (unsorted=${_unsorted}, log=${_log})"
  return 0
}

# stdin → 변수
_input=$(cat)
if [ -z "$_input" ]; then
  _cs_err "빈 입력 — Stop hook 페이로드 없음"
  exit 0
fi

_session_id=$(jq -r '.session_id // empty'         <<< "$_input")
_transcript=$(jq -r '.transcript_path // empty'    <<< "$_input")
_cwd=$(jq -r '.cwd // empty'                       <<< "$_input")
_last_msg=$(jq -r '.last_assistant_message // empty' <<< "$_input")

# ── fallback: transcript에서 마지막 assistant text 블록 추출 ────

if [ -z "$_last_msg" ] && [ -n "$_transcript" ] && [ -f "$_transcript" ]; then
  _last_msg=$(jq -rs '
    map(select(.type == "assistant"))
    | last
    | .message.content[]?
    | select(.type == "text")
    | .text
  ' "$_transcript" 2>/dev/null || true)
fi

# 빈 메시지 = 도구 호출만 있던 응답 → 저장하지 않음
if [ -z "$_last_msg" ]; then
  exit 0
fi

# ── s4: 휴리스틱 필터 + 민감정보 마스킹 ──────────────────────────

# [0차] 슬래시 커맨드 차단 — user_prompt가 /로 시작하면 플러그인 커맨드 실행이므로 저장하지 않음
# (transcript user_prompt는 아직 추출 전이라 stdin 재파싱)
_up_check=$(jq -rs '
  map(select(.type == "user")) | last
  | (.message.content | if type=="string" then . else (map(select(.type=="text") | .text) | join("")) end)
' "$_transcript" 2>/dev/null || true)
if [[ "$_up_check" =~ ^[[:space:]]*/[a-zA-Z] ]]; then
  exit 0
fi

# 학습 가치 없는 발화(짧은 답변, 액션 발화, 테이블 덤프)는 저장하지 않음
if ! is_educational "$_last_msg"; then
  echo "※ study: 배울만한 내용이 아님 — 저장 건너뜀"
  exit 0
fi
# 점수 계산은 마스킹 전 원본 기준 (마스킹 토큰이 키워드 카운트 왜곡 방지)
_estimated_value=$(estimate_value "$_last_msg")
# 민감정보 마스킹 (API 키/이메일/사용자 경로/.env 값)
_last_msg=$(redact_sensitive "$_last_msg")

# ── 메타 수집 ────────────────────────────────────────────────────

# 직전 user 메시지 (transcript에서 추출, 실패 시 빈 문자열)
_user_prompt=""
if [ -n "$_transcript" ] && [ -f "$_transcript" ]; then
  _user_prompt=$(jq -rs '
    map(select(.type == "user"))
    | last
    | (.message.content
        | if type=="string" then .
          else (map(select(.type=="text") | .text) | join("\n"))
          end)
  ' "$_transcript" 2>/dev/null || true)
  [ "$_user_prompt" = "null" ] && _user_prompt=""
fi

# git branch (cwd가 git repo인 경우만)
_branch=""
if [ -n "$_cwd" ] && git -C "$_cwd" rev-parse --git-dir >/dev/null 2>&1; then
  _branch=$(git -C "$_cwd" branch --show-current 2>/dev/null || true)
fi

# project name (cwd basename, 빈 cwd면 "unknown")
_project="unknown"
[ -n "$_cwd" ] && _project=$(basename "$_cwd")

# model (transcript에서 마지막 assistant 메시지의 model)
_model="unknown"
if [ -n "$_transcript" ] && [ -f "$_transcript" ]; then
  _m=$(jq -rs '
    map(select(.type == "assistant"))
    | last
    | .message.model // empty
  ' "$_transcript" 2>/dev/null || true)
  [ -n "$_m" ] && [ "$_m" != "null" ] && _model="$_m"
fi

# user_prompt도 마스킹 (질문 안에 키/이메일 노출 방지)
[ -n "$_user_prompt" ] && _user_prompt=$(redact_sensitive "$_user_prompt")

# ── 저장 ─────────────────────────────────────────────────────────

_out=$(write_inbox_note \
  --session-id      "$_session_id" \
  --project         "$_project" \
  --project-path    "$_cwd" \
  --branch          "$_branch" \
  --model           "$_model" \
  --user-prompt     "$_user_prompt" \
  --content         "$_last_msg" \
  --estimated-value "$_estimated_value") || {
    _cs_err "write_inbox_note 실패"
    exit 1
  }

# s5 placeholder: update_tree_unsorted +1 (s5 완료 후 통합)
# 예) bash "${_plugin_root}/lib/tree.sh" inbox-add "$_out"

echo "wj-studybook: inbox saved → $_out" >&2
echo "※ study: 배울만한 내용이 있음 — 대화 내용 수집됨"
_cs_auto_digest || true
exit 0
