#!/usr/bin/env bash
# capture-session-end.sh — SessionEnd hook: 세션 단위 통합 노트 + 누락분 보완
#
# 입력: stdin JSON (Claude Code SessionEnd hook 페이로드)
#   { session_id, transcript_path, cwd, end_reason }
#
# 동작:
#   1) end_reason == "resume" → 즉시 종료 (세션 계속됨)
#   2) transcript JSONL 전체 파싱 (transcript-parser.sh)
#   3) 모든 assistant text 추출 → filter 통과한 것만 후보
#   4) 각 후보의 SHA256 hash로 inbox/ 기존 파일 본문과 중복 검사
#   5) 신규만 inbox-writer로 저장 (hook_source=session_end)
#   6) 세션 요약 노트 생성 (~/.studybook/inbox/session-<sessionId>.md, type=session_summary)
#   7) update_index_on_add (혹은 update_tree_unsorted_increment) 호출
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
# shellcheck source=../lib/transcript-parser.sh
source "${_plugin_root}/lib/transcript-parser.sh"
# shellcheck source=../lib/index-update.sh
source "${_plugin_root}/lib/index-update.sh"

_cse_err() { echo "capture-session-end.sh: $*" >&2; }

# ── 입력 파싱 ────────────────────────────────────────────────────

_input=$(cat)
if [ -z "$_input" ]; then
  _cse_err "빈 입력 — SessionEnd hook 페이로드 없음"
  exit 0
fi

_session_id=$(jq -r '.session_id // empty'      <<< "$_input")
_transcript=$(jq -r '.transcript_path // empty' <<< "$_input")
_cwd=$(jq -r '.cwd // empty'                    <<< "$_input")
_end_reason=$(jq -r '.end_reason // empty'      <<< "$_input")

# end_reason=resume → 세션 계속, 처리하지 않음 (acceptance #7)
if [ "$_end_reason" = "resume" ]; then
  exit 0
fi

# transcript 없거나 파일 없음 → 처리 불가
if [ -z "$_transcript" ] || [ ! -f "$_transcript" ]; then
  _cse_err "transcript 없음 — skip ($_transcript)"
  exit 0
fi

# ── SHA256 인덱스 (inbox 본문 hash) ───────────────────────────────

# 본문 hash (frontmatter --- 블록 제거 후 sha256)
# 인자: $1=텍스트
_cse_hash_text() {
  set -u
  printf '%s' "$1" | sed 's/[[:space:]]*$//' | shasum -a 256 | awk '{print $1}'
}

# inbox/*.md의 본문 hash 인덱스를 stdout 1줄씩 출력
_cse_build_inbox_hash_index() {
  set -u
  _dir="${HOME}/.studybook/inbox"
  [ -d "$_dir" ] || return 0
  for _f in "$_dir"/*.md; do
    [ -f "$_f" ] || continue
    # frontmatter ---...--- 블록 제거 → 본문만
    _body=$(awk '
      BEGIN { fm=0; done=0 }
      NR==1 && $0=="---" { fm=1; next }
      fm==1 && !done && $0=="---" { done=1; next }
      done==1 { print }
    ' "$_f")
    # 첫 줄 빈 줄 제거 (write_inbox_note이 본문 앞에 \n 삽입) + trailing whitespace 정규화
    _body=$(printf '%s' "$_body" | sed '1{/^$/d;}' | sed 's/[[:space:]]*$//')
    [ -z "$_body" ] && continue
    _cse_hash_text "$_body"
  done
}

# ── 메타 수집 (write_inbox_note 공통) ─────────────────────────────

_cse_collect_meta() {
  set -u
  _branch=""
  if [ -n "$_cwd" ] && git -C "$_cwd" rev-parse --git-dir >/dev/null 2>&1; then
    _branch=$(git -C "$_cwd" branch --show-current 2>/dev/null || true)
  fi
  _project="unknown"
  [ -n "$_cwd" ] && _project=$(basename "$_cwd")
  _model="unknown"
  if [ -f "$_transcript" ]; then
    _meta=$(get_session_meta "$_transcript" 2>/dev/null || true)
    _m=$(printf '%s\n' "$_meta" | sed -n 4p)
    [ -n "$_m" ] && [ "$_m" != "unknown" ] && _model="$_m"
  fi
}

# ── 누락 발화 보완 ────────────────────────────────────────────────

# 기존 inbox 본문 hash 집합 (newline-separated)
_existing_hashes=$(_cse_build_inbox_hash_index || true)
_cse_collect_meta

_added_count=0
_total_candidates=0

# assistant text 순회 (NUL 구분)
while IFS= read -r -d '' _txt; do
  [ -z "$_txt" ] && continue
  # filter 통과 + 액션 발화 차단
  if ! is_educational "$_txt"; then
    continue
  fi
  _total_candidates=$((_total_candidates + 1))
  _redacted=$(redact_sensitive "$_txt")
  _hash=$(_cse_hash_text "$_redacted")
  # 중복 검사: 기존 inbox에 동일 hash 있으면 skip
  if printf '%s\n' "$_existing_hashes" | grep -Fxq "$_hash"; then
    continue
  fi
  _est=$(estimate_value "$_txt")
  # hook_source=session_end (write_inbox_note는 stop으로 하드코딩 →
  # 환경변수로 override, inbox-writer.sh는 그대로 유지)
  _out=$(WJ_SB_HOOK_SOURCE="session_end" write_inbox_note \
    --session-id      "$_session_id" \
    --project         "$_project" \
    --project-path    "$_cwd" \
    --branch          "$_branch" \
    --model           "$_model" \
    --user-prompt     "" \
    --content         "$_redacted" \
    --estimated-value "$_est") || {
      _cse_err "write_inbox_note 실패 (skip 1건)"
      continue
    }
  # WJ_SB_HOOK_SOURCE=session_end 환경변수로 inbox-writer가 직접 처리 (sed 패치 불필요)
  if [ -f "$_out" ]; then
    update_tree_unsorted_increment 2>/dev/null || true
    _added_count=$((_added_count + 1))
    # 새 hash를 인덱스에 추가하여 동일 세션 내 중복 방지
    _existing_hashes=$(printf '%s\n%s' "$_existing_hashes" "$_hash")
  fi
done < <(extract_all_assistant_texts "$_transcript")

# ── 세션 요약 노트 작성 ─────────────────────────────────────────

_meta=$(get_session_meta "$_transcript" 2>/dev/null || printf 'unknown\nunknown\n0\nunknown\n')
_started_at=$(printf '%s\n' "$_meta" | sed -n 1p)
_ended_at=$(printf '%s\n' "$_meta"   | sed -n 2p)
_total_messages=$(printf '%s\n' "$_meta" | sed -n 3p)
[ -z "$_started_at" ] && _started_at="unknown"
[ -z "$_ended_at" ]   && _ended_at="unknown"
[ -z "$_total_messages" ] && _total_messages=0

_summary_dir="${HOME}/.studybook/inbox"
mkdir -p "$_summary_dir"
_summary_file="${_summary_dir}/session-${_session_id}.md"

# captured_at (write_inbox_note의 _iw_now_iso와 동일 로직 — 의존 최소화)
if date -Iseconds >/dev/null 2>&1; then
  _captured_at=$(date -Iseconds)
else
  _captured_at=$(date +"%Y-%m-%dT%H:%M:%S%z")
fi

_summary_ulid=$(ulid_generate)

# 세션 요약 frontmatter (acceptance #5: session_id, started_at, ended_at,
# total_messages, captured_count, end_reason 포함)
{
  emit_frontmatter "$(cat <<EOF
id: ${_summary_ulid}
schema: studybook.note/v1
type: session_summary
status: raw
captured_at: ${_captured_at}
session_id: ${_session_id}
started_at: ${_started_at}
ended_at: ${_ended_at}
total_messages: ${_total_messages}
captured_count: ${_added_count}
end_reason: ${_end_reason}
project: ${_project}
project_path: ${_cwd}
git_branch: ${_branch}
model: ${_model}
hook_source: session_end
EOF
)"
  printf '\n'
  printf '# 세션 요약 — %s\n\n' "$_session_id"
  printf -- '- started_at: %s\n'      "$_started_at"
  printf -- '- ended_at: %s\n'        "$_ended_at"
  printf -- '- total_messages: %s\n'  "$_total_messages"
  printf -- '- captured_count: %s\n'  "$_added_count"
  printf -- '- end_reason: %s\n'      "$_end_reason"
  printf -- '- candidates: %s\n'      "$_total_candidates"
} > "$_summary_file"

# unsorted_count +1 (요약 노트도 inbox에 들어감)
update_tree_unsorted_increment 2>/dev/null || true

echo "wj-studybook: session-end summary → $_summary_file (added: $_added_count)" >&2

# ── 자동 digest 트리거 (백그라운드) ───────────────────────────────
# inbox에 type=inbox, status=raw 인 미분류 노트가 있으면 claude CLI를
# setsid+nohup으로 분리 실행해 쪽 페이지로 자동 발간한다.
# - 락 파일: $(get_studybook_dir)/.digest.lock (O_EXCL, 백그라운드 자식이 해제)
# - 로그:   $(get_studybook_dir)/.logs/digest-<ts>.log
# - 테스트: WJ_SB_DIGEST_DISABLE=1 이면 skip
# - CLI 부재/인증 실패는 로그만 남기고 skip → 다음 SessionEnd에 자연 재시도.

_cse_auto_digest() {
  set -u
  if [ "${WJ_SB_DIGEST_DISABLE:-0}" = "1" ]; then
    _cse_err "auto-digest skipped (WJ_SB_DIGEST_DISABLE=1)"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    _cse_err "auto-digest skipped (claude CLI not found)"
    return 0
  fi
  _sb_dir=$(get_studybook_dir)
  _inbox_dir="${_sb_dir}/inbox"
  [ -d "$_inbox_dir" ] || return 0
  # 미분류 inbox 개수 (type=inbox, processed/ 제외)
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
  if [ "$_unsorted" -eq 0 ]; then
    return 0
  fi
  _lock="${_sb_dir}/.digest.lock"
  if ! ( set -o noclobber; : > "$_lock" ) 2>/dev/null; then
    _cse_err "auto-digest already running (lock: $_lock), skip"
    return 0
  fi
  # 락 파일은 백그라운드 자식이 종료 시 제거하도록 subshell trap 설정
  _log_dir="${_sb_dir}/.logs"
  mkdir -p "$_log_dir" 2>/dev/null || true
  _log="${_log_dir}/digest-$(date +%s)-$$.log"
  # setsid로 세션 리더 분리, nohup으로 SIGHUP 무시, disown으로 job table 제거.
  # 자식은 trap으로 락 파일 정리. stdout/stderr는 로그 파일로.
  ( setsid nohup sh -c '
      trap "rm -f \"$0\"" EXIT INT TERM
      claude -p "/wj-studybook:digest auto"
    ' "$_lock" >"$_log" 2>&1 </dev/null & ) 2>/dev/null || {
      _cse_err "auto-digest spawn failed, removing lock"
      rm -f "$_lock"
      return 0
    }
  _cse_err "auto-digest spawned (unsorted=${_unsorted}, log=${_log})"
  return 0
}

_cse_auto_digest || true

exit 0
