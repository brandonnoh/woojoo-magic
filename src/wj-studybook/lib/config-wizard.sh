#!/usr/bin/env bash
# config-wizard.sh — wj-studybook 프로필 마법사
# Usage:
#   source src/wj-studybook/lib/config-wizard.sh
#   wizard_main                                # 인터랙티브
#   wizard_create_profile woojoo adult intermediate ko-en "ai,bash" 친절 y
#   wizard_set_active woojoo
#
# 외부 의존: config-helpers.sh (같은 폴더)
# 주의: source 전용. set -euo pipefail은 호출자 책임.

# ── 의존 로드 ────────────────────────────────────────────────────
# bash: ${BASH_SOURCE[0]}, zsh: ${(%):-%x} — 둘 다 지원
if [ -n "${BASH_SOURCE:-}" ]; then
  _CW_SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  # zsh의 funcsourcetrace[1] 또는 ${(%):-%x}
  _CW_SRC="${(%):-%x}"
else
  _CW_SRC="$0"
fi
_CW_DIR="$(cd "$(dirname "$_CW_SRC")" && pwd)"
# shellcheck source=/dev/null
. "${_CW_DIR}/config-helpers.sh"

# ── stderr ───────────────────────────────────────────────────────
_cw_err() {
  echo "config-wizard.sh: $*" >&2
}

# ── 검증 헬퍼 ────────────────────────────────────────────────────

# _cw_validate_name — 프로필 이름 형식 검증 (소문자/숫자/_-)
_cw_validate_name() {
  _name="${1:-}"
  if [ -z "$_name" ]; then
    _cw_err "이름이 비었습니다"
    return 1
  fi
  if ! printf '%s' "$_name" | grep -qE '^[a-z0-9_-]+$'; then
    _cw_err "이름은 소문자/숫자/_/-만 허용 (받은 값: '$_name')"
    return 1
  fi
  return 0
}

# _cw_validate_enum <value> <label> <allowed1> <allowed2> ...
_cw_validate_enum() {
  _val="$1"; _label="$2"; shift 2
  for _ok in "$@"; do
    if [ "$_val" = "$_ok" ]; then
      return 0
    fi
  done
  _cw_err "${_label} 값이 잘못됨 (받은 값: '$_val', 허용: $*)"
  return 1
}

# _cw_iso_now — ISO 8601 timestamp (KST 가정 없이 시스템 TZ 사용)
_cw_iso_now() {
  date '+%Y-%m-%dT%H:%M:%S%z' \
    | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
}

# _cw_csv_to_yaml_list — "a,b,c" → "[a, b, c]" (공백 trim, 빈 항목 제거)
_cw_csv_to_yaml_list() {
  _csv="${1:-}"
  if [ -z "$_csv" ]; then
    printf '[]'
    return 0
  fi
  printf '%s' "$_csv" | awk -F',' '
    {
      out="["
      first=1
      for (i=1; i<=NF; i++) {
        item=$i
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", item)
        if (item == "") continue
        if (!first) out=out", "
        out=out item
        first=0
      }
      out=out"]"
      printf "%s", out
    }
  '
}

# ── yaml emit ────────────────────────────────────────────────────

# _cw_emit_profile_yaml <name> <age_group> <level> <language> <interests_csv> <tone> <use_emoji>
# stdout으로 yaml 본문 출력 (frontmatter 래퍼 없이 순수 yaml 파일용)
_cw_emit_profile_yaml() {
  _name="$1"; _age="$2"; _lvl="$3"; _lang="$4"
  _interests_csv="$5"; _tone="$6"; _emoji="$7"
  _ts=$(_cw_iso_now)
  _interests_yaml=$(_cw_csv_to_yaml_list "$_interests_csv")
  cat <<EOF
schema: studybook.profile/v1
name: ${_name}
created_at: ${_ts}
learner:
  age_group: ${_age}
  level: ${_lvl}
  language: ${_lang}
  interests: ${_interests_yaml}
book_style:
  tone: ${_tone}
  use_emoji: ${_emoji}
  reading_level: ${_lvl}
capture:
  mode: filtered
  redact_sensitive: true
publish:
  schedule: weekly
EOF
}

# ── 공개 함수 ────────────────────────────────────────────────────

# wizard_show_profiles — 기존 프로필 목록 + 메뉴 출력 (stdout)
wizard_show_profiles() {
  set -u
  _active=$(get_active_profile)
  _names=$(list_profile_names)
  if [ -z "$_names" ]; then
    echo "프로필 없음 — 신규 생성 안내"
    echo "[1] 새 프로필 만들기"
    echo "[0] 취소"
    return 0
  fi
  echo "기존 프로필:"
  _idx=0
  printf '%s\n' "$_names" | while IFS= read -r _n; do
    [ -z "$_n" ] && continue
    _idx=$((_idx + 1))
    if [ "$_n" = "$_active" ]; then
      printf '[%d] %s (활성)\n' "$_idx" "$_n"
    else
      printf '[%d] %s\n' "$_idx" "$_n"
    fi
  done
  _count=$(printf '%s\n' "$_names" | grep -c .)
  printf '[%d] 새 프로필 만들기\n' $((_count + 1))
  printf '[%d] 삭제·수정\n' $((_count + 2))
  echo "[0] 취소"
}

# wizard_set_active <name> — config.yaml의 active_profile을 갱신/생성
wizard_set_active() {
  set -u
  _name="${1:-}"
  _cw_validate_name "$_name" || return 1
  if ! profile_exists "$_name"; then
    _cw_err "존재하지 않는 프로필: $_name"
    return 1
  fi
  _cfg=$(get_config_path)
  _dir=$(get_studybook_dir)
  mkdir -p "$_dir"
  if [ -f "$_cfg" ] && grep -qE '^active_profile:' "$_cfg"; then
    # 기존 라인 교체 (in-place via tmp)
    _tmp="${_cfg}.tmp.$$"
    awk -v name="$_name" '
      /^active_profile:/ { print "active_profile: " name; next }
      { print }
    ' "$_cfg" > "$_tmp" && mv "$_tmp" "$_cfg"
  else
    # 신규 생성 또는 키 추가
    if [ ! -f "$_cfg" ]; then
      cat > "$_cfg" <<EOF
schema: studybook.config/v1
active_profile: ${_name}
EOF
    else
      printf 'active_profile: %s\n' "$_name" >> "$_cfg"
    fi
  fi
  return 0
}

# wizard_create_profile <name> <age_group> <level> <language> <interests_csv> <tone> <use_emoji>
# 비대화형. 검증 → yaml 파일 생성 → books/<name>/ 디렉토리 생성.
# active_profile은 갱신하지 않음 (호출자가 wizard_set_active로 별도).
wizard_create_profile() {
  set -u
  if [ "$#" -lt 7 ]; then
    _cw_err "wizard_create_profile: 7개 인자 필요 (name age_group level language interests tone use_emoji)"
    return 1
  fi
  _name="$1"; _age="$2"; _lvl="$3"; _lang="$4"
  _interests="$5"; _tone="$6"; _emoji="$7"

  _cw_validate_name "$_name" || return 1
  _cw_validate_enum "$_age"   "age_group" child teen adult || return 1
  _cw_validate_enum "$_lvl"   "level"     none beginner intermediate advanced || return 1
  _cw_validate_enum "$_lang"  "language"  ko en ko-en || return 1
  _cw_validate_enum "$_emoji" "use_emoji" y n true false || return 1

  if profile_exists "$_name"; then
    _cw_err "이미 존재하는 프로필: $_name"
    return 1
  fi

  _profiles_dir=$(get_profiles_dir)
  _books_dir=$(get_books_dir)
  mkdir -p "$_profiles_dir" \
           "${_books_dir}/${_name}/topics" \
           "${_books_dir}/${_name}/weekly" \
           "${_books_dir}/${_name}/monthly"

  _file="${_profiles_dir}/${_name}.yaml"
  _cw_emit_profile_yaml "$_name" "$_age" "$_lvl" "$_lang" "$_interests" "$_tone" "$_emoji" > "$_file"
  return 0
}

# _cw_prompt <prompt> <varname> [default]
# stdin에서 한 줄 읽어 변수에 저장. 빈값이고 default 있으면 default 사용.
_cw_prompt() {
  _p="$1"; _var="$2"; _def="${3:-}"
  if [ -n "$_def" ]; then
    printf '%s [%s]: ' "$_p" "$_def" >&2
  else
    printf '%s: ' "$_p" >&2
  fi
  IFS= read -r _ans || _ans=""
  if [ -z "$_ans" ] && [ -n "$_def" ]; then
    _ans="$_def"
  fi
  # 동적 할당 (eval 대신 printf -v 사용)
  printf -v "$_var" '%s' "$_ans"
}

# wizard_create_profile_interactive — stdin에서 7개 입력 받아 wizard_create_profile 호출
wizard_create_profile_interactive() {
  set -u
  _cw_prompt "이름 (소문자/숫자/_-)"        _i_name
  _cw_prompt "연령대 (child|teen|adult)"     _i_age   "adult"
  _cw_prompt "수준 (none|beginner|intermediate|advanced)" _i_lvl "beginner"
  _cw_prompt "언어 (ko|en|ko-en)"            _i_lang  "ko"
  _cw_prompt "관심 주제 (콤마 구분, 비워도 OK)" _i_int  ""
  _cw_prompt "톤 (친절|정중|캐주얼)"          _i_tone  "친절"
  _cw_prompt "이모지 사용 (y|n)"              _i_emj   "y"
  wizard_create_profile "$_i_name" "$_i_age" "$_i_lvl" "$_i_lang" "$_i_int" "$_i_tone" "$_i_emj"
}

# _cw_offer_schedule — macOS일 때 launchd 자동 publish 제안
_cw_offer_schedule() {
  if [ "$(uname -s)" != "Darwin" ]; then
    return 0
  fi
  printf '\n매주 월요일 자동 publish를 설정할까요? (y/n) [n]: ' >&2
  IFS= read -r _sched_ans || _sched_ans="n"
  case "$_sched_ans" in
    y|Y|yes|YES)
      # shellcheck source=/dev/null
      . "${_CW_DIR}/schedule.sh"
      schedule_install
      ;;
    *)
      echo "자동 스케줄 건너뜀 (나중에 config schedule install 로 설정 가능)"
      ;;
  esac
}

# wizard_main — 메인 진입점. stdin에서 메뉴 선택 → 분기.
wizard_main() {
  set -u
  wizard_show_profiles
  printf '선택: ' >&2
  IFS= read -r _choice || _choice="0"
  _names=$(list_profile_names)
  _count=$(printf '%s\n' "$_names" | grep -c . || true)

  if [ "$_choice" = "0" ]; then
    echo "취소됨"
    return 0
  fi

  # 신규 생성 (count=0이면 1, 아니면 count+1)
  _new_idx=$((_count == 0 ? 1 : _count + 1))
  if [ "$_choice" = "$_new_idx" ]; then
    wizard_create_profile_interactive || return 1
    # 마지막에 만든 프로필을 active로
    _last=$(list_profile_names | tail -n1)
    [ -n "$_last" ] && wizard_set_active "$_last"
    # macOS: 자동 스케줄 제안
    _cw_offer_schedule
    return 0
  fi

  # 기존 선택 [1..count]
  if [ "$_count" -gt 0 ] && [ "$_choice" -ge 1 ] && [ "$_choice" -le "$_count" ] 2>/dev/null; then
    _picked=$(printf '%s\n' "$_names" | sed -n "${_choice}p")
    wizard_set_active "$_picked"
    echo "활성 프로필: $_picked"
    return 0
  fi

  _cw_err "지원되지 않는 선택: $_choice"
  return 1
}
