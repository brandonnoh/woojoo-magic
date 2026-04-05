#!/usr/bin/env bash
# woojoo-magic: 위험한 Bash 명령 차단 (PreToolUse)
# stdin: JSON { "tool_name": "...", "tool_input": { "command": "..." } }
# exit 2 → 차단 + reason을 stderr로 반환
set -euo pipefail

INPUT="$(cat || true)"
if [[ -z "${INPUT}" ]]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

CMD="$(printf '%s' "${INPUT}" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
if [[ -z "${CMD}" ]]; then
  exit 0
fi

deny() {
  echo "[woojoo-magic] 차단된 명령: $1" >&2
  exit 2
}

# rm -rf / 또는 루트 경로 대상
if [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+/ ]] || [[ "${CMD}" =~ rm[[:space:]]+-rf?[[:space:]]+~/?([[:space:]]|$) ]]; then
  deny "rm -rf 루트/홈 경로 금지"
fi

# sudo
if [[ "${CMD}" =~ (^|[[:space:]])sudo([[:space:]]|$) ]]; then
  deny "sudo 사용 금지"
fi

# curl | sh / wget | sh
if [[ "${CMD}" =~ (curl|wget)[^|]*\|[[:space:]]*(sh|bash|zsh) ]]; then
  deny "curl/wget 파이프 실행 금지"
fi

# git push --force to main/master
if [[ "${CMD}" =~ git[[:space:]]+push.*(--force|[[:space:]]-f[[:space:]]) ]]; then
  if [[ "${CMD}" =~ (main|master) ]]; then
    deny "main/master 강제 푸시 금지"
  fi
fi

# chmod 777
if [[ "${CMD}" =~ chmod[[:space:]]+777 ]]; then
  deny "chmod 777 금지"
fi

# > /dev/<device>  (안전한 /dev/null, /dev/stderr, /dev/stdout, /dev/tty, /dev/fd/* 는 허용)
if [[ "${CMD}" =~ \>[[:space:]]*/dev/([A-Za-z0-9_]+) ]]; then
  target="${BASH_REMATCH[1]}"
  case "${target}" in
    null|stderr|stdout|tty|fd) : ;;
    *) deny "/dev/${target} 리다이렉트 금지" ;;
  esac
fi

exit 0
