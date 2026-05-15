#!/usr/bin/env bash
# wj-magic: 민감 파일 Write/Edit 차단 (PreToolUse)
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
  echo "[wj-magic] 차단: $1" >&2
  exit 2
}

# 환경 변수 / 시크릿 파일
case "${_base}" in
  *.pem|*.key|*.p12|*.pfx|*.jks)
    deny "${_base} — 인증서/키 파일 직접 수정 금지. 사용자에게 수동 편집을 안내하세요."
    ;;
  credentials.json|service-account*.json|secrets.yaml|secrets.yml)
    deny "${_base} — 시크릿 파일 수정 금지."
    ;;
  id_rsa|id_ed25519|*.secret)
    deny "${_base} — 인증 키 파일 수정 금지."
    ;;
esac

# .dev/audit/ 파일에 실제 시크릿 값이 포함되면 차단
case "${FILE}" in
  */.dev/audit/*.md|*/.dev/audit/*.json)
    # Write → content, Edit → new_string 에서 시크릿 패턴 검사
    _content="$(printf '%s' "${INPUT}" | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null || true)"
    if [[ -n "${_content}" ]]; then
      # 공통 시크릿 패턴 (patterns.sh의 WJ_SECRET_* 와 동일)
      _secret_regex='AKIA[A-Z0-9]{16}|AIzaSy[a-zA-Z0-9_-]{33}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|ghu_[a-zA-Z0-9]{36}|ghs_[a-zA-Z0-9]{36}|sk_live_[a-zA-Z0-9]{24,}|rk_live_[a-zA-Z0-9]{24,}|xox[bpas]-[a-zA-Z0-9-]+|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|eyJ[a-zA-Z0-9_-]{20,}\.eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]+'
      if printf '%s' "${_content}" | grep -Eq "${_secret_regex}" 2>/dev/null; then
        deny "audit 리포트에 실제 시크릿 값 포함 감지 — 마스킹 필수 (앞 6자 + ***). GitHub Secret Scanning이 키를 차단합니다."
      fi
    fi
    ;;
esac

# 코드 파일 수정 시 Serena 사용 리마인더 (stderr → Claude 컨텍스트에 주입)
case "${_base}" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.swift|*.kt|*.kts)
    echo "[wj-magic:mcp-remind] 코드 수정 감지 — Serena(find_symbol/find_referencing_symbols)로 참조 관계를 확인했는가? Context7로 라이브러리 API 문서를 조회했는가? 추측 기반 수정은 2차 버그를 만든다." >&2
    ;;
esac

exit 0
