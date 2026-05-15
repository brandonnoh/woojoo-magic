#!/usr/bin/env bash
# subagent-gate.sh — 서브에이전트 응답 종료 시 L1 정적 감사
# 서브에이전트가 코드 작성 후 메인 세션 복귀 전에 품질 체크.
# 위반 시 block → 서브에이전트가 자체 수정 후 재시도.
#
# 출력 형식 (JSON):
#   block:    {"decision":"block","reason":"..."}
#   continue: (빈 출력)
set -euo pipefail

_plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
_project_root="${CLAUDE_PROJECT_DIR:-$PWD}"
_lib="${_plugin_root}/lib"

# stdin JSON에서 transcript_path 추출 (있으면 MCP 사용 흔적 검사용)
_stdin_payload=""
if [[ ! -t 0 ]]; then
  _stdin_payload=$(cat 2>/dev/null || true)
fi

# MCP 사용 흔적 정적 검출 (transcript 가 있을 때만)
# 검색 패턴: sequential-thinking / serena / context7
# 0회면 경고만 출력 (block 하지 않음 — 너무 공격적)
if [[ -n "$_stdin_payload" ]]; then
  _transcript_path=""
  if command -v jq >/dev/null 2>&1; then
    _transcript_path=$(printf '%s' "$_stdin_payload" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  else
    # jq 부재 시 grep으로 폴백 추출
    _transcript_path=$(printf '%s' "$_stdin_payload" \
      | grep -oE '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]+"' \
      | head -n1 \
      | sed -E 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)
  fi

  if [[ -n "$_transcript_path" && -f "$_transcript_path" ]]; then
    _seq_cnt=$(grep -o 'mcp__sequential-thinking__' "$_transcript_path" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    _serena_cnt=$(grep -o 'mcp__serena__' "$_transcript_path" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    _ctx7_cnt=$(grep -o 'mcp__context7__' "$_transcript_path" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
    _total_mcp=$((_seq_cnt + _serena_cnt + _ctx7_cnt))

    if [[ $_total_mcp -eq 0 ]]; then
      echo "[wj-magic:subagent] ⚠️  MCP 사용 흔적 없음 — sequential-thinking/serena/context7 호출 0회 감지" >&2
      echo "[wj-magic:subagent]    추측 기반 작업 가능성. 결과물을 면밀히 검토할 것." >&2
    else
      echo "[wj-magic:subagent] ✓ MCP 호출 감지 (seq=${_seq_cnt}, serena=${_serena_cnt}, ctx7=${_ctx7_cnt})" >&2
    fi
  fi
fi

# 변경 파일 감지
_changed=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
if [[ -z "$_changed" ]]; then
  _changed=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
fi
[[ -z "$_changed" ]] && exit 0

# L1 정적 감사
echo "[wj-magic:subagent] ▶ L1 정적 감사 ..." >&2
_l1_exit=0
_l1_out=$(echo "$_changed" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?

if [[ $_l1_exit -ne 0 ]]; then
  echo "[wj-magic:subagent] ✗ L1 실패 — 수정 후 재시도" >&2
  printf '{"decision":"block","reason":"[wj-magic:subagent] L1 정적 감사 실패 — 메인 세션 복귀 전 수정 필요:\\n\\n%s\\n\\n위반 항목을 수정하세요."}' "$_l1_out"
  exit 0
fi

echo "[wj-magic:subagent] ✓ L1 통과" >&2
exit 0
