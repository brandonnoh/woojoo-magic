#!/usr/bin/env bash
# woojoo-magic: 플러그인 MCP 자동 설치 (dedup)
# - 전역(~/.claude.json)에 이미 있는 MCP는 스킵
# - 현재 프로젝트 .mcp.json에 없는 MCP만 병합
# - 프로젝트별 마커로 재실행 방지
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PLUGIN_MCP="${PLUGIN_ROOT}/mcp-presets/default.json"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_MCP="${PROJECT_ROOT}/.mcp.json"
GLOBAL_MCP="${HOME}/.claude.json"

MARKER_DIR="${HOME}/.woojoo-magic"
mkdir -p "${MARKER_DIR}"

PROJECT_HASH="$(printf '%s' "${PROJECT_ROOT}" | shasum | awk '{print $1}')"
MARKER="${MARKER_DIR}/installed-${PROJECT_HASH}"

if [[ -f "${MARKER}" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[woojoo-magic] jq 미설치 → MCP 자동 설치 생략" >&2
  exit 0
fi

if [[ ! -f "${PLUGIN_MCP}" ]]; then
  echo "[woojoo-magic] 플러그인 .mcp.json 미발견: ${PLUGIN_MCP}" >&2
  exit 0
fi

# 전역 MCP 이름 목록
if [[ -f "${GLOBAL_MCP}" ]]; then
  GLOBAL_NAMES="$(jq -r '.mcpServers // {} | keys[]' "${GLOBAL_MCP}" 2>/dev/null || true)"
else
  GLOBAL_NAMES=""
fi

# 프로젝트 MCP 이름 목록
if [[ -f "${PROJECT_MCP}" ]]; then
  PROJECT_NAMES="$(jq -r '.mcpServers // {} | keys[]' "${PROJECT_MCP}" 2>/dev/null || true)"
else
  PROJECT_NAMES=""
fi

# 플러그인이 제공하는 MCP 중 전역/프로젝트에 모두 없는 것만 선별
PLUGIN_NAMES="$(jq -r '.mcpServers | keys[]' "${PLUGIN_MCP}")"
TO_ADD=()
while IFS= read -r name; do
  [[ -z "${name}" ]] && continue
  if grep -qx "${name}" <<<"${GLOBAL_NAMES}"; then continue; fi
  if grep -qx "${name}" <<<"${PROJECT_NAMES}"; then continue; fi
  TO_ADD+=("${name}")
done <<<"${PLUGIN_NAMES}"

if [[ ${#TO_ADD[@]} -eq 0 ]]; then
  : > "${MARKER}"
  exit 0
fi

# 병합 대상 JSON 구성
NAMES_JSON="$(printf '%s\n' "${TO_ADD[@]}" | jq -R . | jq -s .)"
ADD_JSON="$(jq --argjson names "${NAMES_JSON}" '
  .mcpServers as $src
  | reduce $names[] as $n ({}; .[$n] = $src[$n])
' "${PLUGIN_MCP}")"

if [[ -f "${PROJECT_MCP}" ]]; then
  TMP="$(mktemp)"
  jq --argjson add "${ADD_JSON}" '
    .mcpServers = ((.mcpServers // {}) + $add)
  ' "${PROJECT_MCP}" > "${TMP}"
  mv "${TMP}" "${PROJECT_MCP}"
else
  jq --argjson add "${ADD_JSON}" -n '{ mcpServers: $add }' > "${PROJECT_MCP}"
fi

echo "[woojoo-magic] ${#TO_ADD[@]}개 MCP 설치 완료: ${TO_ADD[*]}"
: > "${MARKER}"
