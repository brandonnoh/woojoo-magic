#!/usr/bin/env bash
# woojoo-magic: 첫 세션 자동 부트스트랩
# - MCP dedup 설치 (유저 전역에 없는 것만 프로젝트 .mcp.json에 병합)
# - Ralph v2 자율 개발 루프 자동 설치 (기존 파일 보존)
# - 프로젝트별 마커로 재실행 방지
#
# 비활성화: WOOJOO_MAGIC_SKIP_BOOTSTRAP=1
# Ralph만 비활성화: WOOJOO_MAGIC_SKIP_RALPH=1
set -euo pipefail

if [[ "${WOOJOO_MAGIC_SKIP_BOOTSTRAP:-0}" == "1" ]]; then
  exit 0
fi

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

MESSAGES=()

# ───────────────────────────────────────────
# 1. MCP dedup 설치
# ───────────────────────────────────────────
if command -v jq >/dev/null 2>&1 && [[ -f "${PLUGIN_MCP}" ]]; then
  if [[ -f "${GLOBAL_MCP}" ]]; then
    GLOBAL_NAMES="$(jq -r '.mcpServers // {} | keys[]' "${GLOBAL_MCP}" 2>/dev/null || true)"
  else
    GLOBAL_NAMES=""
  fi

  if [[ -f "${PROJECT_MCP}" ]]; then
    PROJECT_NAMES="$(jq -r '.mcpServers // {} | keys[]' "${PROJECT_MCP}" 2>/dev/null || true)"
  else
    PROJECT_NAMES=""
  fi

  PLUGIN_NAMES="$(jq -r '.mcpServers | keys[]' "${PLUGIN_MCP}")"
  TO_ADD=()
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    if grep -qx "${name}" <<<"${GLOBAL_NAMES}"; then continue; fi
    if grep -qx "${name}" <<<"${PROJECT_NAMES}"; then continue; fi
    TO_ADD+=("${name}")
  done <<<"${PLUGIN_NAMES}"

  if [[ ${#TO_ADD[@]} -gt 0 ]]; then
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

    MESSAGES+=("MCP ${#TO_ADD[@]}개 설치: ${TO_ADD[*]}")
  fi
fi

# ───────────────────────────────────────────
# 2. Ralph v2 자동 설치
# ───────────────────────────────────────────
RALPH_SRC="${PLUGIN_ROOT}/templates/ralph-starter-kit"
if [[ "${WOOJOO_MAGIC_SKIP_RALPH:-0}" != "1" ]] && [[ -d "${RALPH_SRC}" ]]; then
  RALPH_INSTALLED=0

  # 핵심 파일/디렉토리 복사 (기존 파일은 보존)
  if [[ ! -f "${PROJECT_ROOT}/ralph.sh" && -f "${RALPH_SRC}/ralph.sh" ]]; then
    cp "${RALPH_SRC}/ralph.sh" "${PROJECT_ROOT}/ralph.sh"
    chmod +x "${PROJECT_ROOT}/ralph.sh"
    RALPH_INSTALLED=1
  fi

  if [[ ! -d "${PROJECT_ROOT}/lib" && -d "${RALPH_SRC}/lib" ]]; then
    cp -r "${RALPH_SRC}/lib" "${PROJECT_ROOT}/lib"
    find "${PROJECT_ROOT}/lib" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    RALPH_INSTALLED=1
  fi

  if [[ ! -d "${PROJECT_ROOT}/prompts" && -d "${RALPH_SRC}/prompts" ]]; then
    cp -r "${RALPH_SRC}/prompts" "${PROJECT_ROOT}/prompts"
    RALPH_INSTALLED=1
  fi

  if [[ ! -d "${PROJECT_ROOT}/schemas" && -d "${RALPH_SRC}/schemas" ]]; then
    cp -r "${RALPH_SRC}/schemas" "${PROJECT_ROOT}/schemas"
    RALPH_INSTALLED=1
  fi

  # 템플릿 → 실제 파일명
  if [[ ! -f "${PROJECT_ROOT}/prd.md" && -f "${RALPH_SRC}/templates/prd.template.md" ]]; then
    cp "${RALPH_SRC}/templates/prd.template.md" "${PROJECT_ROOT}/prd.md"
    RALPH_INSTALLED=1
  fi

  if [[ ! -f "${PROJECT_ROOT}/tests.json" && -f "${RALPH_SRC}/templates/tests.template.json" ]]; then
    cp "${RALPH_SRC}/templates/tests.template.json" "${PROJECT_ROOT}/tests.json"
    RALPH_INSTALLED=1
  fi

  if [[ ! -f "${PROJECT_ROOT}/progress.md" && -f "${RALPH_SRC}/templates/progress.template.md" ]]; then
    cp "${RALPH_SRC}/templates/progress.template.md" "${PROJECT_ROOT}/progress.md"
    RALPH_INSTALLED=1
  fi

  mkdir -p "${PROJECT_ROOT}/.ralph-state/logs"

  # 스택 감지
  if [[ -x "${PROJECT_ROOT}/lib/detect-stack.sh" ]]; then
    "${PROJECT_ROOT}/lib/detect-stack.sh" > "${PROJECT_ROOT}/.ralph-state/stack.json" 2>/dev/null || true
  fi

  if [[ "${RALPH_INSTALLED}" == "1" ]]; then
    MESSAGES+=("Ralph v2 설치: ralph.sh, lib/, prompts/, schemas/, prd.md, tests.json, progress.md")
  fi
fi

# ───────────────────────────────────────────
# 3. 마커 생성 + 결과 출력
# ───────────────────────────────────────────
: > "${MARKER}"

if [[ ${#MESSAGES[@]} -gt 0 ]]; then
  echo "[woojoo-magic] 부트스트랩 완료:"
  for m in "${MESSAGES[@]}"; do
    echo "  - ${m}"
  done
fi
