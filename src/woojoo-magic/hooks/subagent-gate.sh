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

# 변경 파일 감지
_changed=$(git -C "$_project_root" diff --name-only HEAD 2>/dev/null || true)
if [[ -z "$_changed" ]]; then
  _changed=$(git -C "$_project_root" diff --name-only 2>/dev/null || true)
fi
[[ -z "$_changed" ]] && exit 0

# L1 정적 감사
echo "[wj:subagent] ▶ L1 정적 감사 ..." >&2
_l1_exit=0
_l1_out=$(echo "$_changed" | bash "$_lib/gate-l1.sh" 2>&1) || _l1_exit=$?

if [[ $_l1_exit -ne 0 ]]; then
  echo "[wj:subagent] ✗ L1 실패 — 수정 후 재시도" >&2
  printf '{"decision":"block","reason":"[wj:subagent] L1 정적 감사 실패 — 메인 세션 복귀 전 수정 필요:\\n\\n%s\\n\\n위반 항목을 수정하세요."}' "$_l1_out"
  exit 0
fi

echo "[wj:subagent] ✓ L1 통과" >&2
exit 0
