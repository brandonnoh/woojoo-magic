#!/usr/bin/env bash
# schema.sh — wj-studybook frontmatter helper 라이브러리
# Usage:
#   source src/wj-studybook/lib/schema.sh
#   ulid=$(ulid_generate)
#   emit_frontmatter "$yaml" > note.md
#   read_frontmatter note.md
#   validate_note_schema note.md
#
# 외부 의존: 없음 (ULID는 순수 bash + /dev/urandom + date)
#            yq는 선택. 미사용 (POSIX 도구로 충분).
# 주의: 이 파일은 source 전용. set -euo pipefail은 호출자 책임.
#       각 함수 내부에서 set -u로 strict 가드.

# ── 내부 상수 ────────────────────────────────────────────────────
# Crockford base32 (I, L, O, U 제외 — 시각 혼동/욕설 방지)
WJ_SB_CROCKFORD='0123456789ABCDEFGHJKMNPQRSTVWXYZ'

# ── 내부 헬퍼 ────────────────────────────────────────────────────

# stderr 출력 (silent catch 금지 — 항상 명확한 에러 메시지)
_sb_err() {
  echo "schema.sh: $*" >&2
}

# 현재 epoch ms (macOS/Linux 호환)
_sb_epoch_ms() {
  # macOS의 date는 %N을 지원하지 않음 → python 또는 perl fallback
  if date +%s%N 2>/dev/null | grep -qv 'N$'; then
    echo $(($(date +%s%N) / 1000000))
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()*1000))'
  else
    # 최후 fallback: 초 단위 * 1000 (밀리초 정밀도 손실)
    echo $(($(date +%s) * 1000))
  fi
}

# 정수를 Crockford base32 N자리로 인코딩 (zero-padded)
_sb_int_to_b32() {
  _n="$1"
  _len="$2"
  _out=""
  _i=0
  while [ "$_i" -lt "$_len" ]; do
    _idx=$((_n % 32))
    _out="${WJ_SB_CROCKFORD:$_idx:1}${_out}"
    _n=$((_n / 32))
    _i=$((_i + 1))
  done
  printf '%s' "$_out"
}

# /dev/urandom에서 N자리 Crockford base32 랜덤 문자열 생성
_sb_random_b32() {
  _len="$1"
  _out=""
  _i=0
  while [ "$_i" -lt "$_len" ]; do
    # od로 1바이트 → 0~255, mod 32로 인덱스
    _byte=$(LC_ALL=C od -An -N1 -tu1 /dev/urandom | tr -d ' \n')
    _idx=$((_byte % 32))
    _out="${_out}${WJ_SB_CROCKFORD:$_idx:1}"
    _i=$((_i + 1))
  done
  printf '%s' "$_out"
}

# ── 공개 함수 ────────────────────────────────────────────────────

# ulid_generate — 26자 ULID (10자 시간 + 16자 랜덤, Crockford base32)
ulid_generate() {
  set -u
  _ms=$(_sb_epoch_ms)
  _ts_part=$(_sb_int_to_b32 "$_ms" 10)
  _rand_part=$(_sb_random_b32 16)
  printf '%s%s\n' "$_ts_part" "$_rand_part"
}

# emit_frontmatter <yaml_string> — yaml을 ---...--- 블록으로 감싸 stdout 출력
emit_frontmatter() {
  set -u
  if [ "$#" -lt 1 ]; then
    _sb_err "emit_frontmatter: yaml 인자 필요"
    return 1
  fi
  printf -- '---\n'
  printf '%s\n' "$1"
  printf -- '---\n'
}

# read_frontmatter <file> — 파일에서 첫 ---...--- 블록 본문만 stdout 출력
# 내부: 파일에서 첫 ---...--- 블록 본문만 추출 (awk)
_sb_extract_block() {
  awk '
    NR==1 && $0!="---" { exit 2 }
    NR==1 && $0=="---" { inblk=1; next }
    inblk && $0=="---" { exit 0 }
    inblk { print }
  ' "$1"
}

read_frontmatter() {
  set -u
  _file="${1:-}"
  if [ -z "$_file" ] || [ ! -f "$_file" ]; then
    _sb_err "read_frontmatter: 파일이 없습니다: ${_file:-<empty>}"
    return 1
  fi
  _yaml=$(_sb_extract_block "$_file") || true
  if [ -z "$_yaml" ]; then
    _sb_err "read_frontmatter: frontmatter 블록 없음: $_file"
    return 1
  fi
  printf '%s\n' "$_yaml"
}

# 내부: yaml에서 top-level key 값 추출 (간이 파서, key: value 한 줄만)
_sb_yaml_get() {
  _yaml="$1"
  _key="$2"
  printf '%s\n' "$_yaml" \
    | awk -v k="$_key" '
        $0 ~ "^"k":" {
          sub("^"k":[[:space:]]*", "")
          sub("[[:space:]]+$", "")
          print
          exit
        }'
}

# 내부: yaml에 top-level key가 존재하는지 (값/블록 모두 포함)
_sb_yaml_has() {
  _yaml="$1"
  _key="$2"
  printf '%s\n' "$_yaml" | grep -qE "^${_key}:"
}

# validate_note_schema <file> — note 스키마 필수 필드 검증
# 내부: yaml에 누락된 필수 키들의 에러 메시지 누적
_sb_check_required() {
  _yaml="$1"; _label="$2"; shift 2
  _missing=""
  for _k in "$@"; do
    if ! _sb_yaml_has "$_yaml" "$_k"; then
      _missing="${_missing}- ${_label}: ${_k}"$'\n'
    fi
  done
  printf '%s' "$_missing"
}

# 내부: schema 필드 형식 검증 (studybook.note/v\d+)
_sb_check_note_schema_field() {
  _schema=$(_sb_yaml_get "$1" "schema")
  if ! printf '%s' "$_schema" | grep -qE '^studybook\.note/v[0-9]+$'; then
    printf '%s\n' "- schema 필드 형식 위반 (현재: '${_schema}')"
  fi
}

validate_note_schema() {
  set -u
  _file="${1:-}"
  _yaml=$(read_frontmatter "$_file") || return 1
  _errors=$(_sb_check_note_schema_field "$_yaml")
  _errors="${_errors}$(_sb_check_required "$_yaml" "필수 필드 누락" id type status captured_at)"
  if [ "$(_sb_yaml_get "$_yaml" "type")" = "topic" ]; then
    _errors="${_errors}$(_sb_check_required "$_yaml" "type=topic 필수 필드 누락" category profile sources)"
  fi
  if [ -n "$_errors" ]; then
    _sb_err "validate_note_schema 실패 (${_file}):"
    printf '%s\n' "$_errors" >&2
    return 1
  fi
  return 0
}
