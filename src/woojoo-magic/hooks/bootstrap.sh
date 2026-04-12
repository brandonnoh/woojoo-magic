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

MESSAGES=()

# ───────────────────────────────────────────
# 0. Ralph 인프라 자동 업그레이드 (마커와 무관하게 매 세션 실행)
# ───────────────────────────────────────────
RALPH_SRC="${PLUGIN_ROOT}/templates/ralph-starter-kit"
PLUGIN_VERSION="$(jq -r '.version // "0.0.0"' "${PLUGIN_ROOT}/.claude-plugin/plugin.json" 2>/dev/null || echo "0.0.0")"

if [[ -d "${RALPH_SRC}" && -d "${PROJECT_ROOT}/lib" ]]; then
  INSTALLED_VERSION=""
  VERSION_FILE="${PROJECT_ROOT}/.ralph-state/.plugin-version"
  [[ -f "${VERSION_FILE}" ]] && INSTALLED_VERSION="$(cat "${VERSION_FILE}")"

  if [[ "${INSTALLED_VERSION}" != "${PLUGIN_VERSION}" ]]; then
    # 인프라 파일만 덮어쓰기 (사용자 데이터 prd.md, tests.json, progress.md는 절대 안 건드림)
    cp "${RALPH_SRC}/ralph.sh" "${PROJECT_ROOT}/ralph.sh" 2>/dev/null && chmod +x "${PROJECT_ROOT}/ralph.sh"
    cp -r "${RALPH_SRC}/lib/." "${PROJECT_ROOT}/lib/" 2>/dev/null || true
    find "${PROJECT_ROOT}/lib" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
    cp -r "${RALPH_SRC}/prompts/." "${PROJECT_ROOT}/prompts/" 2>/dev/null || true
    cp -r "${RALPH_SRC}/schemas/." "${PROJECT_ROOT}/schemas/" 2>/dev/null || true

    mkdir -p "${PROJECT_ROOT}/.ralph-state"
    echo "${PLUGIN_VERSION}" > "${VERSION_FILE}"

    # 업그레이드된 파일을 자동 커밋 (dirty tree 방지)
    if git -C "${PROJECT_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
      git -C "${PROJECT_ROOT}" add ralph.sh lib/ prompts/ schemas/ 2>/dev/null || true
      git -C "${PROJECT_ROOT}" commit --no-verify \
        -m "chore(ralph): 인프라 자동 업그레이드 ${INSTALLED_VERSION:-없음} → ${PLUGIN_VERSION}" \
        >/dev/null 2>&1 || true
    fi
    MESSAGES+=("Ralph 인프라 업그레이드: ${INSTALLED_VERSION:-없음} → ${PLUGIN_VERSION}")
  fi
fi

if [[ -f "${MARKER}" ]]; then
  # 초기 설치는 완료됐지만, 위 업그레이드 메시지가 있으면 출력
  if [[ ${#MESSAGES[@]} -gt 0 ]]; then
    echo "[woojoo-magic] 업그레이드:"
    for m in "${MESSAGES[@]}"; do
      echo "  - ${m}"
    done
  fi
  exit 0
fi

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
# 2. Ralph v2 초기 설치 (인프라는 섹션 0에서 처리, 여기선 사용자 데이터만)
# ───────────────────────────────────────────
if [[ "${WOOJOO_MAGIC_SKIP_RALPH:-0}" != "1" ]] && [[ -d "${RALPH_SRC}" ]]; then
  RALPH_INSTALLED=0

  # 인프라 파일 초기 설치 (이미 있으면 섹션 0이 버전 기반 업그레이드 담당)
  for target in ralph.sh; do
    if [[ ! -f "${PROJECT_ROOT}/${target}" && -f "${RALPH_SRC}/${target}" ]]; then
      cp "${RALPH_SRC}/${target}" "${PROJECT_ROOT}/${target}"
      chmod +x "${PROJECT_ROOT}/${target}"
      RALPH_INSTALLED=1
    fi
  done
  for dir in lib prompts schemas; do
    if [[ ! -d "${PROJECT_ROOT}/${dir}" && -d "${RALPH_SRC}/${dir}" ]]; then
      cp -r "${RALPH_SRC}/${dir}" "${PROJECT_ROOT}/${dir}"
      RALPH_INSTALLED=1
    fi
  done
  find "${PROJECT_ROOT}/lib" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

  # 사용자 데이터 템플릿 (최초 1회만, 절대 덮어쓰지 않음)
  for pair in "prd.md:prd.template.md" "tests.json:tests.template.json" "progress.md:progress.template.md"; do
    target="${pair%%:*}"
    template="${pair##*:}"
    if [[ ! -f "${PROJECT_ROOT}/${target}" && -f "${RALPH_SRC}/templates/${template}" ]]; then
      cp "${RALPH_SRC}/templates/${template}" "${PROJECT_ROOT}/${target}"
      RALPH_INSTALLED=1
    fi
  done

  mkdir -p "${PROJECT_ROOT}/.ralph-state/logs"
  mkdir -p "${PROJECT_ROOT}/specs"

  # 스택 감지
  if [[ -x "${PROJECT_ROOT}/lib/detect-stack.sh" ]]; then
    "${PROJECT_ROOT}/lib/detect-stack.sh" > "${PROJECT_ROOT}/.ralph-state/stack.json" 2>/dev/null || true
  fi

  # 초기 설치 시 버전 마커도 기록
  if [[ "${RALPH_INSTALLED}" == "1" ]]; then
    echo "${PLUGIN_VERSION}" > "${PROJECT_ROOT}/.ralph-state/.plugin-version"
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
