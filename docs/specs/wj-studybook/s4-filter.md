# s4-filter: 휴리스틱 필터 + 민감정보 마스킹

## 배경
Stop hook(s3)이 모든 발화를 무차별 저장하면 inbox가 노이즈로 폭발한다. 이 task에서 학습 가치 있는 발화만 통과시키고, 민감정보(API 키, 이메일 등)는 자동 마스킹한다. UX 리서치(Marsick 1990, Bjork 1994)에 따라 의도적으로 불완전하게 — 너무 친절하면 학습 효과 떨어짐.

## 변경 범위

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `src/wj-studybook/lib/filter.sh` | 신규 | is_educational + redact_sensitive |
| `src/wj-studybook/hooks/capture-stop.sh` | 수정 (s3에서 작성된 것) | filter.sh 호출 통합 |
| `tests/wj-studybook/test-filter.bats` | 신규 | 단위 테스트 |

## 구현 방향

### filter.sh

```bash
#!/usr/bin/env bash
# filter.sh — 학습 가치 판정 + 민감정보 마스킹

# 학습 키워드 (한국어 + 영어)
EDUCATIONAL_KEYWORDS=(
  # 한국어
  "패턴" "방식" "구조" "원리" "이유" "왜" "주의" "팁" "권장"
  "안티패턴" "문제" "설명" "예시" "예제" "기법" "전략"
  "해결" "수정" "버그" "디버깅" "에러" "대책" "우회" "근본원인"
  "아키텍처" "설계" "레이어" "컴포넌트" "인터페이스"
  "의존성" "모듈화" "확장성" "유지보수"
  # 영어
  "because" "why" "pattern" "anti-pattern" "trade-off" "tradeoff"
  "rationale" "approach" "best practice" "pitfall" "gotcha"
  "decision" "design" "architecture" "principle"
)

# 액션 발화 (필터 차단)
ACTION_PATTERNS=(
  "^(파일을 |파일들을 )?(읽|확인|보)겠습니다"
  "^(코드를 |명령을 )?실행하겠습니다"
  "^(파일을 |디렉토리를 )?생성하겠습니다"
  "^완료(되었|했)습니다\.$"
  "^네\.?$"
  "^확인했습니다\.?$"
  "^Let me (read|check|run|create)"
  "^I'?ll (read|check|run|create)"
)

is_educational() {
  local _text="$1"
  local _len=${#_text}

  # 1. 길이 체크
  [[ $_len -lt 50 ]] && return 1

  # 2. 액션 발화 차단
  for _pattern in "${ACTION_PATTERNS[@]}"; do
    if [[ "$_text" =~ $_pattern ]]; then
      return 1
    fi
  done

  # 3. 학습 키워드 매칭 (1개 이상)
  for _kw in "${EDUCATIONAL_KEYWORDS[@]}"; do
    if echo "$_text" | grep -qF "$_kw"; then
      return 0
    fi
  done

  # 4. 코드 블록 + 설명 페어 (백틱 3개 + 다른 텍스트 50자+)
  if echo "$_text" | grep -q '```'; then
    local _without_code
    _without_code=$(echo "$_text" | sed '/^```/,/^```/d')
    [[ ${#_without_code} -gt 50 ]] && return 0
  fi

  return 1
}

# 0~1 점수
estimate_value() {
  local _text="$1"
  local _score=0.0

  # 길이 점수
  local _len=${#_text}
  [[ $_len -ge 100 ]] && _score=$(echo "$_score + 0.2" | bc -l)
  [[ $_len -ge 300 ]] && _score=$(echo "$_score + 0.2" | bc -l)

  # 키워드 점수
  local _kw_count=0
  for _kw in "${EDUCATIONAL_KEYWORDS[@]}"; do
    if echo "$_text" | grep -qF "$_kw"; then
      _kw_count=$((_kw_count + 1))
    fi
  done
  _score=$(echo "$_score + ($_kw_count * 0.05)" | bc -l)

  # 코드 블록 점수
  if echo "$_text" | grep -q '```'; then
    _score=$(echo "$_score + 0.2" | bc -l)
  fi

  # 캡 1.0
  echo "$_score" | awk '{ if ($1 > 1) print 1; else printf "%.2f", $1 }'
}

# 민감정보 마스킹
redact_sensitive() {
  local _text="$1"

  # API 키 패턴
  _text=$(echo "$_text" | sed -E 's/(sk_|pk_|sk-|rk_)[A-Za-z0-9_-]{20,}/[API_KEY_REDACTED]/g')
  _text=$(echo "$_text" | sed -E 's/(Bearer )[A-Za-z0-9._-]{20,}/\1[TOKEN_REDACTED]/g')
  _text=$(echo "$_text" | sed -E 's/(AKIA|ASIA)[A-Z0-9]{16}/[AWS_KEY_REDACTED]/g')
  _text=$(echo "$_text" | sed -E 's/(ghp_|gho_|ghu_|ghs_|ghr_)[A-Za-z0-9]{20,}/[GH_TOKEN_REDACTED]/g')

  # 이메일
  _text=$(echo "$_text" | sed -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[EMAIL_REDACTED]/g')

  # 사용자명 경로
  _text=$(echo "$_text" | sed -E "s|/Users/[^/[:space:]]+|/Users/***|g")
  _text=$(echo "$_text" | sed -E "s|/home/[^/[:space:]]+|/home/***|g")

  # .env 스타일 KEY=value (대문자 KEY + = + 인용된 값)
  _text=$(echo "$_text" | sed -E 's/^([A-Z_]{3,}=)["'\''"]?[^"'\'' ]+["'\''"]?$/\1[VALUE_REDACTED]/g')

  echo "$_text"
}
```

### capture-stop.sh 수정 (s3에 추가)

```bash
# (s3 capture-stop.sh의 마지막 메시지 추출 후)

# 필터 적용
source "${_plugin_root}/lib/filter.sh"
if ! is_educational "$_last_msg"; then
  exit 0  # 학습 가치 없음 — 저장 X
fi

# 마스킹
_last_msg=$(redact_sensitive "$_last_msg")
_user_prompt=$(redact_sensitive "$_user_prompt")

# 점수 계산
_estimated_value=$(estimate_value "$_last_msg")

# (이후 inbox 저장 호출 시 _estimated_value 전달)
write_inbox_note ... --estimated-value "$_estimated_value"
```

### 테스트 케이스 (test-filter.bats)

```bash
@test "is_educational: 패턴 키워드 포함 시 통과" {
  source src/wj-studybook/lib/filter.sh
  run is_educational "useEffect의 클린업 함수는 메모리 누수를 방지하기 위한 패턴입니다. 컴포넌트 언마운트 시..."
  [ "$status" -eq 0 ]
}

@test "is_educational: 단순 액션 발화 차단" {
  source src/wj-studybook/lib/filter.sh
  run is_educational "파일을 읽겠습니다."
  [ "$status" -eq 1 ]
}

@test "is_educational: 50자 미만 차단" {
  source src/wj-studybook/lib/filter.sh
  run is_educational "짧은 응답"
  [ "$status" -eq 1 ]
}

@test "redact_sensitive: API key 마스킹" {
  source src/wj-studybook/lib/filter.sh
  result=$(redact_sensitive "토큰은 sk_test_abcdefghij1234567890 입니다")
  [[ "$result" == *"[API_KEY_REDACTED]"* ]]
  [[ "$result" != *"sk_test_abcdef"* ]]
}

@test "redact_sensitive: 이메일 마스킹" {
  source src/wj-studybook/lib/filter.sh
  result=$(redact_sensitive "연락은 user@example.com")
  [[ "$result" == *"[EMAIL_REDACTED]"* ]]
}

@test "redact_sensitive: /Users/ 경로 마스킹" {
  source src/wj-studybook/lib/filter.sh
  result=$(redact_sensitive "경로는 /Users/woojoo/secret")
  [[ "$result" == *"/Users/***"* ]]
  [[ "$result" != *"woojoo"* ]]
}
```

## 의존 관계

- 사용처: `hooks/capture-stop.sh` (s3), 향후 `hooks/capture-session-end.sh` (s9)도 사용
- 영향 받는 후속 task: s9(SessionEnd hook), s14(backfill — 같은 필터 재사용)

## 검증 명령

```bash
bats tests/wj-studybook/test-filter.bats

# 통합 검증: capture-stop.sh를 통과시킨 후 inbox에 액션 발화 안 들어가는지
echo '{"session_id":"t","cwd":"/tmp","last_assistant_message":"파일을 읽겠습니다."}' | bash src/wj-studybook/hooks/capture-stop.sh
ls ~/.studybook/inbox/ | wc -l  # 새 파일 0
```
