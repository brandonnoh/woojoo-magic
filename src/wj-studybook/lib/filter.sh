#!/usr/bin/env bash
# filter.sh — 학습 가치 판정 + 민감정보 마스킹 (s4-filter)
# Usage:
#   source src/wj-studybook/lib/filter.sh
#   if is_educational "$text"; then ... fi
#   score=$(estimate_value "$text")        # 0.00 ~ 1.00
#   safe=$(redact_sensitive "$text")
#
# 외부 의존: bash 4+, sed (-E), grep, awk, bc (estimate_value)
# 주의: 이 파일은 source 전용. set -euo pipefail은 호출자 책임.
#       silent catch 금지 — 매칭 실패는 의도적 false 반환.
#
# 설계 원칙:
#   - 의도적으로 불완전 (Marsick 1990, Bjork 1994): 필터 너무 친절 X
#   - 액션 발화는 무조건 차단 → noise 폭증 방지
#   - 학습 키워드 + 코드 블록 페어만 통과

# ── 키워드/패턴 상수 ─────────────────────────────────────────────

# 학습 가치 키워드 (한국어 + 영어, grep -F 매칭)
WJ_FILTER_KEYWORDS=(
  # 한국어 — 개념/원리
  "패턴" "방식" "구조" "원리" "이유" "왜" "주의" "팁" "권장"
  "안티패턴" "문제" "설명" "예시" "예제" "기법" "전략"
  # 한국어 — 디버깅/수정
  "해결" "수정" "버그" "디버깅" "에러" "대책" "우회" "근본원인"
  # 한국어 — 아키텍처
  "아키텍처" "설계" "레이어" "컴포넌트" "인터페이스"
  "의존성" "모듈화" "확장성" "유지보수"
  # 영어 — 개념/원리
  "because" "why" "pattern" "anti-pattern" "trade-off" "tradeoff"
  "rationale" "approach" "best practice" "pitfall" "gotcha"
  "decision" "design" "architecture" "principle"
)

# 액션 발화 패턴 (bash 정규식, =~ 매칭) — 매칭 시 무조건 차단
WJ_FILTER_ACTION_PATTERNS=(
  '^(파일을 |파일들을 )?(읽|확인|보)겠습니다'
  '^(코드를 |명령을 )?실행하겠습니다'
  '^(파일을 |디렉토리를 )?생성하겠습니다'
  '^완료(되었|했)습니다\.?$'
  '^네\.?$'
  '^확인했습니다\.?$'
  '^Let me (read|check|run|create)'
  "^I'?ll (read|check|run|create)"
)

# 길이 임계값 (의도적 상수 — 50자 미만은 단편 정보)
WJ_FILTER_MIN_LEN=50

# ── 내부 헬퍼 ────────────────────────────────────────────────────

_wj_filter_err() {
  echo "filter.sh: $*" >&2
}

# 키워드 매칭 카운트 (학습 키워드 N개 발견 → echo N)
_wj_filter_kw_count() {
  set -u
  _ftxt="$1"
  _fcnt=0
  for _fkw in "${WJ_FILTER_KEYWORDS[@]}"; do
    if printf '%s' "$_ftxt" | grep -qF -- "$_fkw"; then
      _fcnt=$((_fcnt + 1))
    fi
  done
  printf '%s' "$_fcnt"
}

# 액션 발화 매칭 (매칭 시 0=true 반환)
_wj_filter_is_action() {
  set -u
  _ftxt="$1"
  for _fpat in "${WJ_FILTER_ACTION_PATTERNS[@]}"; do
    if [[ "$_ftxt" =~ $_fpat ]]; then
      return 0
    fi
  done
  return 1
}

# 코드 블록(```) 포함 + 코드 외 본문 50자 이상 (페어 학습 가치)
_wj_filter_has_code_pair() {
  set -u
  _ftxt="$1"
  printf '%s' "$_ftxt" | grep -q '```' || return 1
  _stripped=$(printf '%s\n' "$_ftxt" | sed '/^```/,/^```/d')
  [ "${#_stripped}" -gt "$WJ_FILTER_MIN_LEN" ]
}

# ── 공개 함수 ────────────────────────────────────────────────────

# is_educational <text> — 학습 가치 판정 (true=0, false=1)
# 통과 조건: 50자+ AND 액션 X AND (학습 키워드 1+ OR 코드 페어)
is_educational() {
  set -u
  _text="${1:-}"
  [ "${#_text}" -lt "$WJ_FILTER_MIN_LEN" ] && return 1
  _wj_filter_is_action "$_text" && return 1
  _kw_n=$(_wj_filter_kw_count "$_text")
  [ "$_kw_n" -gt 0 ] && return 0
  _wj_filter_has_code_pair "$_text" && return 0
  return 1
}

# estimate_value <text> — 학습 가치 점수 0.00 ~ 1.00 (소수점 2자리)
# 점수: 길이(0.4) + 키워드(0.05/개) + 코드(0.2), 캡 1.00
estimate_value() {
  set -u
  _text="${1:-}"
  _score=0.0
  _len=${#_text}
  [ "$_len" -ge 100 ] && _score=$(echo "$_score + 0.2" | bc -l)
  [ "$_len" -ge 300 ] && _score=$(echo "$_score + 0.2" | bc -l)
  _kw_n=$(_wj_filter_kw_count "$_text")
  _score=$(echo "$_score + ($_kw_n * 0.05)" | bc -l)
  if printf '%s' "$_text" | grep -q '```'; then
    _score=$(echo "$_score + 0.2" | bc -l)
  fi
  printf '%s' "$_score" | awk '{ v=$1+0; if (v>1) v=1; if (v<0) v=0; printf "%.2f", v }'
}

# redact_sensitive <text> — 민감정보 마스킹 (echo 결과)
# 마스킹 대상: API 키, Bearer 토큰, AWS 키, GitHub 토큰, 이메일,
#             /Users/<name>, /home/<name>, .env 라인의 값
redact_sensitive() {
  set -u
  _text="${1:-}"
  _text=$(printf '%s' "$_text" | sed -E 's/(sk_|pk_|sk-|rk_)[A-Za-z0-9_-]{20,}/[API_KEY_REDACTED]/g')
  _text=$(printf '%s' "$_text" | sed -E 's/(Bearer )[A-Za-z0-9._-]{20,}/\1[TOKEN_REDACTED]/g')
  _text=$(printf '%s' "$_text" | sed -E 's/(AKIA|ASIA)[A-Z0-9]{16}/[AWS_KEY_REDACTED]/g')
  _text=$(printf '%s' "$_text" | sed -E 's/(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{20,}/[GH_TOKEN_REDACTED]/g')
  _text=$(printf '%s' "$_text" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[EMAIL_REDACTED]/g')
  _text=$(printf '%s' "$_text" | sed -E 's|/Users/[^/[:space:]]+|/Users/***|g')
  _text=$(printf '%s' "$_text" | sed -E 's|/home/[^/[:space:]]+|/home/***|g')
  _text=$(printf '%s' "$_text" | sed -E 's/^([A-Z][A-Z0-9_]{2,}=)["'"'"']?[^"'"'"' ]+["'"'"']?$/\1[VALUE_REDACTED]/')
  printf '%s' "$_text"
}
