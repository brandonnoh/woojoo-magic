#!/usr/bin/env bash
# transcript-parser.sh — Claude Code transcript JSONL 공통 파서
# Usage:
#   source src/wj-studybook/lib/transcript-parser.sh
#   extract_all_assistant_texts /path/to/transcript.jsonl   # NUL-delimited records to stdout
#   extract_user_prompts        /path/to/transcript.jsonl   # NUL-delimited records to stdout
#   get_session_meta            /path/to/transcript.jsonl   # 4 lines: started_at, ended_at, total_messages, model
#
# 외부 의존: jq (필수)
# 주의: 이 파일은 source 전용. set -euo pipefail은 호출자 책임.
#       각 함수 내부에서 set -u로 strict 가드.
#       silent catch 금지 — 잘못된 입력은 stderr + non-zero exit.
#
# 출력 형식: assistant text/user prompt 본문은 줄바꿈을 포함할 수 있어
# NUL(\0) 구분자를 사용. 호출자는 `while IFS= read -r -d ''` 로 순회.
# (s9, s14에서 동일 인터페이스 재사용 — 변경 시 두 호출자 모두 영향)

# ── 내부 헬퍼 ────────────────────────────────────────────────────

_tp_err() {
  echo "transcript-parser.sh: $*" >&2
}

# transcript 파일 존재/읽기 가능 검증
_tp_check_file() {
  set -u
  _file="${1:-}"
  if [ -z "$_file" ]; then
    _tp_err "transcript 경로 비어있음"
    return 1
  fi
  if [ ! -f "$_file" ]; then
    _tp_err "transcript 파일 없음: $_file"
    return 1
  fi
  if [ ! -r "$_file" ]; then
    _tp_err "transcript 파일 읽기 불가: $_file"
    return 1
  fi
  return 0
}

# ── 공개 함수 ────────────────────────────────────────────────────

# extract_all_assistant_texts <transcript_path>
# 동작: assistant 메시지의 모든 text 블록을 NUL 구분자로 stdout 출력.
#       (한 응답 안에 text 블록이 여러 개면 각각 별도 레코드)
# 사용: while IFS= read -r -d '' _txt; do ... done < <(extract_all_assistant_texts "$tr")
extract_all_assistant_texts() {
  set -u
  _tp_check_file "$1" || return 1
  # jq -j: trailing newline 제거 → 직접 \u0000 emit으로 명확한 경계 표시
  jq -j '
    select(.type == "assistant")
    | .message.content[]?
    | select(.type == "text")
    | .text
    | select(. != null and . != "")
    | (. + "\u0000")
  ' "$1"
}

# extract_user_prompts <transcript_path>
# 동작: user 메시지 본문을 NUL 구분자로 stdout 출력.
#       content가 string인 경우/배열인 경우 모두 처리.
extract_user_prompts() {
  set -u
  _tp_check_file "$1" || return 1
  jq -j '
    select(.type == "user")
    | .message.content as $c
    | (
        if ($c | type) == "string" then $c
        elif ($c | type) == "array" then
          ($c | map(select(.type == "text") | .text) | join("\n"))
        else ""
        end
      )
    | select(. != null and . != "")
    | (. + "\u0000")
  ' "$1"
}

# get_session_meta <transcript_path>
# 출력 (정확히 4줄):
#   1) started_at  — 첫 레코드의 timestamp (없으면 "unknown")
#   2) ended_at    — 마지막 레코드의 timestamp (없으면 "unknown")
#   3) total_messages — JSONL 라인 수
#   4) model       — 마지막 assistant 메시지의 model (없으면 "unknown")
get_session_meta() {
  set -u
  _tp_check_file "$1" || return 1
  _tp_started=$(jq -rs '
    (map(select(.timestamp != null)) | first | .timestamp) // "unknown"
  ' "$1" 2>/dev/null || echo "unknown")
  _tp_ended=$(jq -rs '
    (map(select(.timestamp != null)) | last | .timestamp) // "unknown"
  ' "$1" 2>/dev/null || echo "unknown")
  # total_messages: 빈 줄 제외한 JSONL 라인 수
  _tp_total=$(grep -cv '^[[:space:]]*$' "$1" 2>/dev/null || echo 0)
  _tp_model=$(jq -rs '
    (map(select(.type == "assistant" and .message.model != null))
     | last | .message.model) // "unknown"
  ' "$1" 2>/dev/null || echo "unknown")
  [ -z "$_tp_started" ] || [ "$_tp_started" = "null" ] && _tp_started="unknown"
  [ -z "$_tp_ended" ]   || [ "$_tp_ended" = "null" ]   && _tp_ended="unknown"
  [ -z "$_tp_model" ]   || [ "$_tp_model" = "null" ]   && _tp_model="unknown"
  printf '%s\n%s\n%s\n%s\n' "$_tp_started" "$_tp_ended" "$_tp_total" "$_tp_model"
}
