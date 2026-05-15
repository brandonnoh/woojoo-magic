#!/usr/bin/env bash
# wj-magic: 위험한 Bash 명령 차단 (PreToolUse)
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
  echo "[wj-magic] 차단된 명령: $1" >&2
  exit 2
}

# rm 재귀 삭제 — 루트/홈 경로 대상
# Step 1: rm 명령이 재귀 옵션을 포함하는지 확인
_rm_recursive=false
if [[ "${CMD}" =~ rm[[:space:]] ]]; then
  # -r, -R, --recursive (단독 또는 결합 플래그 -rf, -fr, -Rf, -rfi 등)
  if [[ "${CMD}" =~ rm[[:space:]]+(-[a-zA-Z]*[rR]|--recursive) ]]; then
    _rm_recursive=true
  elif [[ "${CMD}" =~ rm[[:space:]]+.*(-[a-zA-Z]*[rR]|--recursive) ]]; then
    _rm_recursive=true
  fi
fi

# Step 2: 재귀 rm이 루트(/) 또는 홈(~/) 경로를 대상으로 하는지 확인
if [[ "$_rm_recursive" == "true" ]]; then
  if [[ "${CMD}" =~ [[:space:]]/([[:space:]]|$) ]] || \
     [[ "${CMD}" =~ [[:space:]]~/?([[:space:]]|$) ]]; then
    deny "rm 재귀 삭제 — 루트/홈 경로 금지"
  fi
fi

# sudo
if [[ "${CMD}" =~ (^|[[:space:]])sudo([[:space:]]|$) ]]; then
  deny "sudo 사용 금지"
fi

# curl | sh / wget | sh
if [[ "${CMD}" =~ (curl|wget)[^|]*\|[[:space:]]*(sh|bash|zsh) ]]; then
  deny "curl/wget 파이프 실행 금지"
fi

# git push --force / -f (--force-with-lease는 안전하므로 허용)
if [[ "${CMD}" =~ git[[:space:]]+push ]]; then
  _is_force=false
  if [[ "${CMD}" =~ --force($|[[:space:]]) ]] && [[ ! "${CMD}" =~ --force-with-lease ]]; then
    _is_force=true
  elif [[ "${CMD}" =~ [[:space:]]-f($|[[:space:]]) ]] || [[ "${CMD}" =~ [[:space:]]-[a-zA-Z]*f($|[[:space:]]) ]]; then
    _is_force=true
  fi
  if [[ "$_is_force" == "true" ]] && [[ "${CMD}" =~ (main|master) ]]; then
    deny "main/master 강제 푸시 금지"
  fi
fi

# chmod 777
if [[ "${CMD}" =~ chmod[[:space:]]+777 ]]; then
  deny "chmod 777 금지"
fi

# dd if=/dev/* of=/dev/* (디스크 직접 쓰기)
if [[ "${CMD}" =~ (^|[[:space:]])dd[[:space:]] ]] && [[ "${CMD}" =~ of=/dev/ ]]; then
  deny "dd 디바이스 직접 쓰기 금지"
fi

# mkfs (파일시스템 포맷)
if [[ "${CMD}" =~ (^|[[:space:]])mkfs ]]; then
  deny "mkfs (파일시스템 포맷) 금지"
fi

# fork bomb 패턴
if [[ "${CMD}" =~ :\(\)\{.*\|.*\& ]]; then
  deny "fork bomb 금지"
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
