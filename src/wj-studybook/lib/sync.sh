#!/usr/bin/env bash
# sync.sh — /wj:studybook sync 구현 (s16)
# Usage:
#   source src/wj-studybook/lib/sync.sh
#   sync_run [--target <icloud|obsidian|git|none>] [--vault <path>]
#   sync_status
#   sync_detect_icloud_path   # stdout 경로 or 빈 문자열 (non-zero)
#   sync_create_symlink <src> <dst>
#
# 외부 의존: config-helpers.sh (선택). git은 target=git일 때만 필요.
# 주의: source 전용. set -euo pipefail은 호출자 책임.
#       P4 Local-first 원칙: 외부 전송 금지 — symlink/경로 안내만.
#       silent catch 금지 — 실패 시 stderr + non-zero exit.

# ── 의존 로드 ────────────────────────────────────────────────────
if [ -n "${BASH_SOURCE:-}" ]; then
  _SC_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  _SC_SRC="${(%):-%x}"
else
  _SC_SRC="$0"
fi
_SC_DIR="$(cd "$(dirname "$_SC_SRC")" && pwd)"
if [ -f "${_SC_DIR}/config-helpers.sh" ] && ! command -v get_active_profile >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  . "${_SC_DIR}/config-helpers.sh"
fi

# ── stderr ───────────────────────────────────────────────────────
_sc_err() { echo "sync.sh: $*" >&2; }

# ── 내부: 경로/프로필 ────────────────────────────────────────────
_sc_studybook_dir() {
  if command -v get_studybook_dir >/dev/null 2>&1; then
    get_studybook_dir
  else
    printf '%s\n' "${WJ_SB_HOME:-${HOME}/.studybook}"
  fi
}

_sc_active_profile() {
  if command -v get_active_profile >/dev/null 2>&1; then
    _sc_p=$(get_active_profile)
    [ -n "$_sc_p" ] && { printf '%s\n' "$_sc_p"; return 0; }
  fi
  printf '%s\n' "${WJ_SB_PROFILE:-default}"
}

_sc_book_dir() {
  set -u
  printf '%s/books/%s\n' "$(_sc_studybook_dir)" "$(_sc_active_profile)"
}

# ── 내부: 프로필 yaml에서 publish.sync_to 값 읽기 ────────────────
# 중첩 YAML: `publish:` 블록 안의 `  sync_to: <value>` 매칭
_sc_profile_yaml_path() {
  set -u
  _sc_pn=$(_sc_active_profile)
  if command -v get_profiles_dir >/dev/null 2>&1; then
    printf '%s/%s.yaml\n' "$(get_profiles_dir)" "$_sc_pn"
  else
    printf '%s/profiles/%s.yaml\n' "$(_sc_studybook_dir)" "$_sc_pn"
  fi
}

_sc_read_sync_to() {
  set -u
  _sc_yf=$(_sc_profile_yaml_path)
  [ -f "$_sc_yf" ] || { printf ''; return 0; }
  awk '
    /^publish:[[:space:]]*$/ { inblk=1; next }
    inblk && /^[^[:space:]]/ { inblk=0 }
    inblk && /^[[:space:]]+sync_to:[[:space:]]*/ {
      sub("^[[:space:]]+sync_to:[[:space:]]*", "")
      sub("[[:space:]]+$", "")
      print
      exit
    }
  ' "$_sc_yf"
}

# ── 내부: 홈 경계 검증 (외부 경로 symlink 방지) ──────────────────
# 0 = 안전 (HOME 하위), 1 = 외부
_sc_path_within_home() {
  set -u
  _sc_p="${1:-}"
  [ -z "$_sc_p" ] && return 1
  [ -z "${HOME:-}" ] && return 1
  case "$_sc_p" in
    "$HOME"|"$HOME"/*) return 0 ;;
    *) return 1 ;;
  esac
}

# ── 공개: iCloud 경로 자동 감지 ──────────────────────────────────
# 우선순위:
#   1) $HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook/
#   2) $HOME/Library/Mobile Documents/com~apple~CloudDocs/Studybook/
# 둘 중 부모 디렉토리(iCloud~md~obsidian/Documents 또는 com~apple~CloudDocs)
# 가 존재하면 해당 하위 Studybook/ 경로를 stdout으로 출력.
# 둘 다 없으면 빈 문자열 + non-zero.
sync_detect_icloud_path() {
  set -u
  [ -z "${HOME:-}" ] && { _sc_err "HOME 미설정"; printf ''; return 1; }
  _sc_base="${HOME}/Library/Mobile Documents"
  _sc_obs="${_sc_base}/iCloud~md~obsidian/Documents"
  _sc_cd="${_sc_base}/com~apple~CloudDocs"
  if [ -d "$_sc_obs" ]; then
    printf '%s/Studybook\n' "$_sc_obs"
    return 0
  fi
  if [ -d "$_sc_cd" ]; then
    printf '%s/Studybook\n' "$_sc_cd"
    return 0
  fi
  printf ''
  return 1
}

# ── 공개: symlink 생성 + 충돌 검사 ───────────────────────────────
# src: 원본 경로 (실제 디렉토리), dst: symlink 생성 경로
# - src 디렉토리 존재 확인
# - dst 부모는 HOME 하위여야 함 (pentest 방지)
# - dst가 이미 존재하고 같은 target의 symlink면 idempotent OK
# - dst가 symlink이지만 다른 target이면 에러
# - dst가 실제 파일/디렉토리면 에러
# _sc_dst_state — dst 상태를 stdout으로 출력 (set -e 안전)
# 결과: "match" | "conflict" | "file" | "empty"
_sc_dst_state() {
  set -u
  _sc_d="$1"; _sc_s="$2"
  if [ -L "$_sc_d" ]; then
    _sc_c=$(readlink "$_sc_d" 2>/dev/null || printf '')
    if [ "$_sc_c" = "$_sc_s" ]; then printf 'match\n'; else printf 'conflict:%s\n' "$_sc_c"; fi
    return 0
  fi
  if [ -e "$_sc_d" ]; then printf 'file\n'; else printf 'empty\n'; fi
}

sync_create_symlink() {
  set -u
  _sc_src="${1:-}"; _sc_dst="${2:-}"
  [ -n "$_sc_src" ] && [ -n "$_sc_dst" ] || {
    _sc_err "사용법: sync_create_symlink <src> <dst>"; return 1; }
  [ -d "$_sc_src" ] || { _sc_err "원본 디렉토리 없음: $_sc_src"; return 1; }
  _sc_parent=$(dirname "$_sc_dst")
  _sc_path_within_home "$_sc_parent" || {
    _sc_err "대상 부모 경로가 HOME 밖에 있음 (거부): $_sc_parent"; return 1; }
  _sc_state=$(_sc_dst_state "$_sc_dst" "$_sc_src")
  case "$_sc_state" in
    match)     return 0 ;;
    conflict:*) _sc_err "symlink 충돌: $_sc_dst -> ${_sc_state#conflict:}"; return 1 ;;
    file)      _sc_err "대상 경로가 이미 존재(심볼릭 아님): $_sc_dst"; return 1 ;;
  esac
  mkdir -p "$_sc_parent" || { _sc_err "부모 생성 실패: $_sc_parent"; return 1; }
  ln -s "$_sc_src" "$_sc_dst" || { _sc_err "symlink 생성 실패: $_sc_dst"; return 1; }
}

# ── 공개: 현재 sync 상태 ─────────────────────────────────────────
# books/<profile>/ 자체가 symlink인지 + 알려진 sync 경로(iCloud/obsidian 등)에
# 역방향 symlink가 있는지 스캔.
_sc_status_books_line() {
  set -u
  _sc_bd="$1"
  if [ ! -e "$_sc_bd" ]; then
    printf 'status:  책 디렉토리 없음 (아직 발간하지 않음)\n'; return 0
  fi
  if [ -L "$_sc_bd" ]; then
    _sc_t=$(readlink "$_sc_bd" 2>/dev/null || printf '')
    printf 'status:  books 디렉토리가 symlink -> %s\n' "$_sc_t"
  else
    printf 'status:  books 디렉토리는 일반 디렉토리\n'
  fi
}

sync_status() {
  set -u
  _sc_bd=$(_sc_book_dir)
  printf 'profile: %s\n' "$(_sc_active_profile)"
  printf 'books:   %s\n' "$_sc_bd"
  _sc_status_books_line "$_sc_bd"
  _sc_icloud=$(sync_detect_icloud_path 2>/dev/null || printf '')
  if [ -n "$_sc_icloud" ] && [ -L "$_sc_icloud" ]; then
    printf 'icloud:  %s -> %s\n' "$_sc_icloud" "$(readlink "$_sc_icloud" 2>/dev/null)"
  fi
  return 0
}

# ── 내부: 각 target 분기 ─────────────────────────────────────────
_sc_do_icloud() {
  set -u
  _sc_bd=$(_sc_book_dir)
  [ -d "$_sc_bd" ] || { _sc_err "책 디렉토리 없음: $_sc_bd (먼저 publish 실행)"; return 1; }
  _sc_ip=$(sync_detect_icloud_path 2>/dev/null || printf '')
  if [ -z "$_sc_ip" ]; then
    printf 'iCloud 경로 미발견. 후보:\n'
    printf '  %s/Library/Mobile Documents/iCloud~md~obsidian/Documents/Studybook/\n' "$HOME"
    printf '  %s/Library/Mobile Documents/com~apple~CloudDocs/Studybook/\n' "$HOME"
    return 1
  fi
  sync_create_symlink "$_sc_bd" "$_sc_ip" || return 1
  printf 'iCloud sync: %s -> %s\n' "$_sc_ip" "$_sc_bd"
  printf 'iCloud Drive 데몬이 자동 처리 (네트워크 호출 없음).\n'
}

_sc_do_obsidian() {
  set -u
  _sc_vault="${1:-}"
  [ -n "$_sc_vault" ] || { _sc_err "obsidian target은 --vault <path> 필수"; return 1; }
  # ~ 접두어를 $HOME으로 치환 (bash/zsh 모두 안전)
  case "$_sc_vault" in
    "~")    _sc_vault="$HOME" ;;
    "~/"*)  _sc_vault="${HOME}/$(printf '%s' "$_sc_vault" | awk 'NR==1{sub(/^~\//,""); print}')" ;;
  esac
  [ -d "$_sc_vault" ] || { _sc_err "vault 경로 없음: $_sc_vault"; return 1; }
  _sc_bd=$(_sc_book_dir)
  [ -d "$_sc_bd" ] || { _sc_err "책 디렉토리 없음: $_sc_bd (먼저 publish 실행)"; return 1; }
  _sc_dst="${_sc_vault}/Studybook"
  sync_create_symlink "$_sc_bd" "$_sc_dst" || return 1
  printf 'Obsidian sync: %s -> %s\n' "$_sc_dst" "$_sc_bd"
  printf 'Obsidian vault 내부에서 Studybook/ 로 인식됩니다.\n'
}

_sc_do_git() {
  set -u
  _sc_bd=$(_sc_book_dir)
  [ -d "$_sc_bd" ] || { _sc_err "책 디렉토리 없음: $_sc_bd (먼저 publish 실행)"; return 1; }
  command -v git >/dev/null 2>&1 || { _sc_err "git 명령을 찾을 수 없음"; return 1; }
  if [ -d "${_sc_bd}/.git" ]; then
    printf 'git repo 이미 존재: %s/.git\n' "$_sc_bd"
  else
    ( cd "$_sc_bd" && git init -q ) || { _sc_err "git init 실패: $_sc_bd"; return 1; }
    printf 'git init 완료: %s\n' "$_sc_bd"
  fi
  printf '\n다음 단계 (사용자 수동):\n'
  printf '  cd %s\n  git remote add origin <url>\n' "$_sc_bd"
  printf '  git add . && git commit -m "initial" && git push -u origin main\n'
  printf '자동 push 없음 (Local-first).\n'
}

_sc_do_none() {
  set -u
  _sc_bd=$(_sc_book_dir)
  printf '동기화 비활성 (sync_to=none).\n책 경로: %s\n' "$_sc_bd"
  [ -d "$_sc_bd" ] || printf '(아직 발간된 책 없음)\n'
}

# ── 공개: CLI 엔트리 ─────────────────────────────────────────────
# 옵션:
#   --target <icloud|obsidian|git|none>
#   --vault <path>   (obsidian 전용)
#   status            첫 인자가 status면 sync_status 호출
_sc_parse_args() {
  # 파싱 결과는 전역 _sc_target / _sc_vault_arg 에 쌓음
  set -u
  _sc_target=""; _sc_vault_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --target)    shift; _sc_target="${1:-}";     [ -n "$_sc_target" ]    || { _sc_err "--target 값 필요"; return 2; } ;;
      --target=*)  _sc_target="${1#--target=}" ;;
      --vault)     shift; _sc_vault_arg="${1:-}";  [ -n "$_sc_vault_arg" ] || { _sc_err "--vault 값 필요"; return 2; } ;;
      --vault=*)   _sc_vault_arg="${1#--vault=}" ;;
      "")          : ;;
      *)           _sc_err "알 수 없는 옵션: $1"; return 2 ;;
    esac
    shift || true
  done
  return 0
}

_sc_dispatch() {
  set -u
  case "${1:-none}" in
    icloud)   _sc_do_icloud ;;
    obsidian) _sc_do_obsidian "${2:-}" ;;
    git)      _sc_do_git ;;
    none)     _sc_do_none ;;
    *)        _sc_err "지원하지 않는 target: $1 (허용: icloud|obsidian|git|none)"; return 2 ;;
  esac
}

sync_run() {
  set -u
  [ "${1:-}" = "status" ] && { sync_status; return $?; }
  _sc_parse_args "$@" || return $?
  [ -z "$_sc_target" ] && _sc_target=$(_sc_read_sync_to)
  [ -z "$_sc_target" ] && _sc_target="none"
  _sc_dispatch "$_sc_target" "$_sc_vault_arg"
}
