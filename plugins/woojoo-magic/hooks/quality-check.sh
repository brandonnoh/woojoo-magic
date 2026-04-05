#!/usr/bin/env bash
# woojoo-magic: Edit/Write 후 품질 체크 (PostToolUse)
# stdin: JSON { tool_name, tool_input: { file_path, ... } }
set -euo pipefail

INPUT="$(cat || true)"
if [[ -z "${INPUT}" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

FILE="$(printf '%s' "${INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
if [[ -z "${FILE}" || ! -f "${FILE}" ]]; then
  exit 0
fi

# TS/JS 계열만 검사
case "${FILE}" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

WARN=()

# 300줄 초과
LINES=$(wc -l < "${FILE}" 2>/dev/null || echo 0)
if [[ "${LINES}" -gt 300 ]]; then
  WARN+=("파일 ${LINES}줄: 300줄 초과 — 분할 권장")
fi

# any
if grep -En ': any\b|<any>|as any\b' "${FILE}" >/dev/null 2>&1; then
  WARN+=("any 사용 감지 — unknown + 타입 가드 권장")
fi

# !.
if grep -En '!\.' "${FILE}" >/dev/null 2>&1; then
  WARN+=("!. (non-null assertion) 감지 — 타입 가드/Result 권장")
fi

# Silent catch: catch (...) { } / catch (...) 다음 줄이 } 만
if grep -Pzo 'catch\s*\([^)]*\)\s*\{\s*\}' "${FILE}" >/dev/null 2>&1; then
  WARN+=("Silent catch 감지 — 최소한 로깅/복구 필요")
fi

if [[ ${#WARN[@]} -gt 0 ]]; then
  echo "[woojoo-magic] 품질 경고: ${FILE}"
  for w in "${WARN[@]}"; do
    echo "  - ${w}"
  done
fi

exit 0
