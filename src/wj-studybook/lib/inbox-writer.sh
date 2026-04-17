#!/usr/bin/env bash
# inbox-writer.sh — ~/.studybook/inbox/<YYYY-MM-DD>-<ULID>.md 생성 헬퍼
# Usage:
#   source src/wj-studybook/lib/schema.sh        # ulid_generate, emit_frontmatter 필요
#   source src/wj-studybook/lib/inbox-writer.sh
#   write_inbox_note --session-id S --project P --project-path /p \
#     --branch main --model claude-x --user-prompt "..." --content "..."
#
# 출력: 생성된 파일의 절대 경로(stdout 1줄)
# 의존: schema.sh (ulid_generate, emit_frontmatter), date, mkdir
# 주의: 이 파일은 source 전용. set -euo pipefail은 호출자 책임.
#       각 함수 내부에서 set -u로 strict 가드.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.

# ── 내부 헬퍼 ────────────────────────────────────────────────────

_iw_err() {
  echo "inbox-writer.sh: $*" >&2
}

# YAML block scalar로 안전하게 변환 (각 줄 앞 2칸 들여쓰기, 빈 값은 "")
# 인자: $1=원본 텍스트
# 출력: 빈 값이면 ' ""', 비어있지 않으면 ' |\n  line1\n  line2'
# (호출자가 뒤에 '\n'을 명시적으로 붙여 사용 — 줄바꿈 손실 방지)
_iw_yaml_block() {
  set -u
  _src="${1:-}"
  if [ -z "$_src" ]; then
    printf ' ""'
    return 0
  fi
  printf ' |\n'
  # sed가 마지막 라인 뒤 newline을 보장 (printf '%s\n')
  printf '%s\n' "$_src" | sed 's/^/  /' | sed '$ s/$//'
}

# inbox 디렉터리 보장 (~/.studybook/inbox)
_iw_ensure_dir() {
  set -u
  _dir="$(get_studybook_dir)/inbox"
  if ! mkdir -p "$_dir"; then
    _iw_err "inbox 디렉터리 생성 실패: $_dir"
    return 1
  fi
  printf '%s\n' "$_dir"
}

# YAML frontmatter 본문 빌드 (필수 7필드 + content는 호출자가 본문에 붙임)
# 인자: $1=ulid $2=now $3=session $4=project $5=project_path
#       $6=branch $7=model $8=user_prompt $9=estimated_value(빈 값=null)
# 주의: 명령치환은 trailing newline을 strip → 줄 단위로 직접 출력해 손실 방지
_iw_build_yaml() {
  set -u
  _ulid="$1"; _now="$2"; _session="$3"; _project="$4"
  _ppath="$5"; _branch="$6"; _model="$7"; _uprompt="$8"
  _est="${9:-}"
  printf 'id: %s\n'             "$_ulid"
  printf 'schema: %s\n'         "studybook.note/v1"
  printf 'type: %s\n'           "inbox"
  printf 'status: %s\n'         "raw"
  printf 'captured_at: %s\n'    "$_now"
  printf 'session_id: %s\n'     "$_session"
  printf 'project: %s\n'        "$_project"
  printf 'project_path: %s\n'   "$_ppath"
  printf 'git_branch: %s\n'     "$_branch"
  printf 'model: %s\n'          "$_model"
  printf 'hook_source: %s\n'    "${WJ_SB_HOOK_SOURCE:-stop}"
  printf 'user_prompt:'
  _iw_yaml_block "$_uprompt"
  printf '\n'
  printf 'related_files: []\n'
  printf 'detected_keywords: []\n'
  printf 'language_hints: []\n'
  if [ -z "$_est" ]; then
    printf 'estimated_value: null\n'
  else
    printf 'estimated_value: %s\n' "$_est"
  fi
}

# ── 공개 함수 ────────────────────────────────────────────────────

# 인자 파싱 (--key value) → 전역 변수 _session, _project, _ppath, _branch,
# _model, _uprompt, _content 에 할당
_iw_parse_args() {
  set -u
  _session=""; _project=""; _ppath=""; _branch=""
  _model=""; _uprompt=""; _content=""; _estimated=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session-id)      _session="${2:-}"; shift 2 ;;
      --project)         _project="${2:-}"; shift 2 ;;
      --project-path)    _ppath="${2:-}"; shift 2 ;;
      --branch)          _branch="${2:-}"; shift 2 ;;
      --model)           _model="${2:-}"; shift 2 ;;
      --user-prompt)     _uprompt="${2:-}"; shift 2 ;;
      --content)         _content="${2:-}"; shift 2 ;;
      --estimated-value) _estimated="${2:-}"; shift 2 ;;
      *) _iw_err "알 수 없는 옵션: $1"; return 1 ;;
    esac
  done
}

# write_inbox_note — frontmatter+본문으로 inbox 파일 생성
# 옵션: --session-id, --project, --project-path, --branch, --model,
#       --user-prompt, --content
# 출력: 생성된 파일 경로(stdout)
write_inbox_note() {
  set -u
  _iw_parse_args "$@" || return 1
  if [ -z "$_content" ]; then
    _iw_err "--content 가 비어있음 (호출자가 사전 검사 필요)"
    return 1
  fi
  _dir=$(_iw_ensure_dir) || return 1
  _ulid=$(ulid_generate)
  _now=$(get_iso_now)
  _file="${_dir}/$(date +%Y-%m-%d)-${_ulid}.md"
  _yaml=$(_iw_build_yaml "$_ulid" "$_now" "$_session" "$_project" \
                          "$_ppath" "$_branch" "$_model" "$_uprompt" \
                          "$_estimated")
  {
    emit_frontmatter "$_yaml"
    printf '\n%s\n' "$_content"
  } > "$_file" || { _iw_err "파일 쓰기 실패: $_file"; return 1; }
  printf '%s\n' "$_file"
}
