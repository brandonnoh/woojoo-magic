#!/usr/bin/env bash
# woojoo-magic: 민감 파일 Write/Edit 차단 (PreToolUse)
# stdin: JSON { "tool_name": "...", "tool_input": { "file_path": "..." } }
# exit 2 → 차단
set -euo pipefail

INPUT="$(cat || true)"
[[ -z "${INPUT}" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

FILE="$(printf '%s' "${INPUT}" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
[[ -z "${FILE}" ]] && exit 0

_base="$(basename "${FILE}")"
_dir="$(dirname "${FILE}")"

deny() {
  echo "[woojoo-magic] 차단: $1" >&2
  exit 2
}

# 환경 변수 / 시크릿 파일
case "${_base}" in
  .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.jks)
    deny "${_base} — 민감 파일 직접 수정 금지. 사용자에게 수동 편집을 안내하세요."
    ;;
  credentials.json|service-account*.json|secrets.yaml|secrets.yml)
    deny "${_base} — 시크릿 파일 수정 금지."
    ;;
  id_rsa|id_ed25519|*.secret)
    deny "${_base} — 인증 키 파일 수정 금지."
    ;;
esac

exit 0
