#!/usr/bin/env bats
# test-filter.bats — s4-filter unit tests
# Coverage:
#   - is_educational: educational utterances pass, action/short blocked
#   - estimate_value: 0.00 ~ 1.00, length/keyword/code weighting
#   - redact_sensitive: API key, Bearer, AWS, GH, email, /Users/, .env
#
# NOTE: 테스트 픽스처에서 시크릿 패턴을 쓸 때는 반드시 `sk_test_FAKE_*` 같은
# 명확한 더미 prefix를 사용할 것. `sk_live_*`는 GitHub secret scanning이
# 실 Stripe 키로 오탐하여 push를 차단함 (2026-04-16 이력 rewrite 사유).

setup() {
  _ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  FILTER_SH="${_ROOT}/src/wj-studybook/lib/filter.sh"
  # shellcheck source=/dev/null
  source "$FILTER_SH"
}

# ── is_educational: 10 educational utterances pass ───────────────

@test "is_educational: KR pattern keyword + 50chars passes" {
  run is_educational "useEffect의 클린업 함수는 메모리 누수를 방지하기 위한 패턴입니다. 컴포넌트 언마운트 시 호출됩니다."
  [ "$status" -eq 0 ]
}

@test "is_educational: KR principle keyword passes" {
  run is_educational "이 함수가 동작하는 원리는 클로저를 통한 상태 캡처에 있습니다. 호출 시점의 환경을 기억합니다."
  [ "$status" -eq 0 ]
}

@test "is_educational: KR anti-pattern keyword passes" {
  run is_educational "전역 변수로 상태를 공유하는 것은 대표적인 안티패턴입니다. 테스트가 어려워지고 사이드 이펙트가 늘어납니다."
  [ "$status" -eq 0 ]
}

@test "is_educational: KR debugging keyword passes" {
  run is_educational "이 에러는 비동기 콜백의 this 바인딩 손실 때문에 발생합니다. 화살표 함수로 디버깅 후 해결했습니다."
  [ "$status" -eq 0 ]
}

@test "is_educational: KR architecture keyword passes" {
  run is_educational "헥사고날 아키텍처는 도메인 로직과 외부 의존성을 분리하기 위한 설계 기법입니다. 포트와 어댑터로 구성됩니다."
  [ "$status" -eq 0 ]
}

@test "is_educational: EN because keyword passes" {
  run is_educational "We chose this approach because it minimizes coupling between modules and supports future extension."
  [ "$status" -eq 0 ]
}

@test "is_educational: EN trade-off keyword passes" {
  run is_educational "There is a trade-off between consistency and availability in this distributed design decision."
  [ "$status" -eq 0 ]
}

@test "is_educational: EN best practice keyword passes" {
  run is_educational "Using interfaces over concrete classes is a best practice that improves testability significantly."
  [ "$status" -eq 0 ]
}

@test "is_educational: code block + 50chars+ body passes (no keyword)" {
  _msg=$'다음 스니펫은 비동기 처리 모범 사례를 요약한 짧은 데모입니다. 추가 라인 더 들어갑니다 길이 확보용.\n\n```js\nasync function main() {\n  const data = await fetch(url);\n  return data.json();\n}\n```'
  run is_educational "$_msg"
  [ "$status" -eq 0 ]
}

@test "is_educational: KR dependency keyword passes" {
  run is_educational "의존성 역전 원리는 상위 모듈이 하위 모듈에 의존하지 않도록 추상화에 의존하게 만드는 설계 기법입니다."
  [ "$status" -eq 0 ]
}

# ── is_educational: 5 action utterances blocked ─────────────────

@test "is_educational: action read-file blocked" {
  run is_educational "파일을 읽겠습니다."
  [ "$status" -eq 1 ]
}

@test "is_educational: action execute blocked" {
  run is_educational "코드를 실행하겠습니다."
  [ "$status" -eq 1 ]
}

@test "is_educational: action done blocked" {
  run is_educational "완료했습니다."
  [ "$status" -eq 1 ]
}

@test "is_educational: action Let me read blocked" {
  run is_educational "Let me read the configuration file."
  [ "$status" -eq 1 ]
}

@test "is_educational: action Ill check blocked" {
  run is_educational "I'll check the test results."
  [ "$status" -eq 1 ]
}

# ── is_educational: short / no-keyword blocked ──────────────────

@test "is_educational: under 50 chars blocked" {
  run is_educational "짧은 응답입니다"
  [ "$status" -eq 1 ]
}

@test "is_educational: chitchat with no keyword blocked" {
  run is_educational "오늘 날씨가 정말 좋네요. 산책하기 좋은 하루입니다. 점심 먹고 잠시 쉬는 게 어떨까요 하루종일 일했어요."
  [ "$status" -eq 1 ]
}

@test "is_educational: empty string blocked" {
  run is_educational ""
  [ "$status" -eq 1 ]
}

# ── estimate_value: range + scoring ─────────────────────────────

@test "estimate_value: empty string is 0.00" {
  result=$(estimate_value "")
  [ "$result" = "0.00" ]
}

@test "estimate_value: short generic text low score (<= 0.10)" {
  result=$(estimate_value "짧은 텍스트")
  awk -v v="$result" 'BEGIN { exit !(v+0 <= 0.10) }'
}

@test "estimate_value: 100chars+ length adds >= 0.20" {
  _txt=$(printf 'a%.0s' {1..120})
  result=$(estimate_value "$_txt")
  awk -v v="$result" 'BEGIN { exit !(v+0 >= 0.20) }'
}

@test "estimate_value: many keywords + long text >= 0.30" {
  _txt="이 패턴은 안티패턴을 피하기 위한 설계 기법으로, 의존성 역전과 인터페이스 분리 원리를 결합한 아키텍처입니다."
  result=$(estimate_value "$_txt")
  awk -v v="$result" 'BEGIN { exit !(v+0 >= 0.30) }'
}

@test "estimate_value: always within 0.00 ~ 1.00" {
  _huge=$(printf 'design pattern architecture interface 의존성 모듈화 확장성 유지보수 %.0s' {1..50})
  result=$(estimate_value "$_huge")
  awk -v v="$result" 'BEGIN { exit !(v+0 >= 0.0 && v+0 <= 1.0) }'
}

@test "estimate_value: 1.00 cap when all weights" {
  _txt=$(printf '패턴 설계 아키텍처 의존성 모듈화 because pattern architecture %.0s' {1..30})
  _txt="${_txt}"$'\n```\ncode block\n```'
  result=$(estimate_value "$_txt")
  [ "$result" = "1.00" ]
}

# ── redact_sensitive: masking ───────────────────────────────────

@test "redact_sensitive: API key (sk_) masked" {
  result=$(redact_sensitive "토큰은 sk_test_abcdefghij1234567890XYZ 입니다")
  [[ "$result" == *"[API_KEY_REDACTED]"* ]]
  [[ "$result" != *"sk_test_abcdef"* ]]
}

@test "redact_sensitive: GitHub token (ghp_) masked" {
  result=$(redact_sensitive "GH 토큰: ghp_FAKE_abcdefghij1234567890")
  [[ "$result" == *"[GH_TOKEN_REDACTED]"* ]]
  [[ "$result" != *"ghp_FAKE_abcdef"* ]]
}

@test "redact_sensitive: AWS key (AKIA) masked" {
  result=$(redact_sensitive "AWS=AKIAIOSFODNN7EXAMPLE end")
  [[ "$result" == *"[AWS_KEY_REDACTED]"* ]]
  [[ "$result" != *"AKIAIOSFODNN7EXAMPLE"* ]]
}

@test "redact_sensitive: Bearer token masked" {
  result=$(redact_sensitive "Authorization: Bearer abc.def.ghijklmnopqrstuvwxyz")
  [[ "$result" == *"Bearer [TOKEN_REDACTED]"* ]]
  [[ "$result" != *"abc.def.ghijklmnopqrstuvwxyz"* ]]
}

@test "redact_sensitive: email masked" {
  result=$(redact_sensitive "연락은 user.name+tag@example.co.kr 으로")
  [[ "$result" == *"[EMAIL_REDACTED]"* ]]
  [[ "$result" != *"user.name"* ]]
}

@test "redact_sensitive: /Users/<name> path masked" {
  result=$(redact_sensitive "경로는 /Users/woojoo/secret/data 입니다")
  [[ "$result" == *"/Users/***"* ]]
  [[ "$result" != *"woojoo"* ]]
}

@test "redact_sensitive: /home/<name> path masked" {
  result=$(redact_sensitive "경로는 /home/alice/.config/file")
  [[ "$result" == *"/home/***"* ]]
  [[ "$result" != *"alice"* ]]
}

@test "redact_sensitive: .env style KEY=value masked" {
  result=$(redact_sensitive 'DATABASE_URL=postgres://user:pass@host/db')
  [[ "$result" == *"DATABASE_URL=[VALUE_REDACTED]"* ]]
  [[ "$result" != *"postgres://user:pass"* ]]
}

@test "redact_sensitive: plain text unchanged" {
  _txt="이 함수는 메모리 누수 방지 패턴입니다."
  result=$(redact_sensitive "$_txt")
  [ "$result" = "$_txt" ]
}

@test "redact_sensitive: multiple sensitive items masked together" {
  _txt="API: sk_test_FAKE_abcdefghij1234567890XYZ Email: a@b.com Path: /Users/foo/x"
  result=$(redact_sensitive "$_txt")
  [[ "$result" == *"[API_KEY_REDACTED]"* ]]
  [[ "$result" == *"[EMAIL_REDACTED]"* ]]
  [[ "$result" == *"/Users/***"* ]]
}

# ── integration with capture-stop.sh ────────────────────────────

@test "integration: action utterance not saved to inbox" {
  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
  CAPTURE_SH="${_ROOT}/src/wj-studybook/hooks/capture-stop.sh"
  _payload='{"session_id":"a","transcript_path":"/dev/null","cwd":"/tmp","last_assistant_message":"파일을 읽겠습니다."}'
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _count=$(ls "$HOME/.studybook/inbox/" 2>/dev/null | wc -l | tr -d ' ')
  [ "$_count" -eq 0 ]
  rm -rf "$TMP"
}

@test "integration: educational utterance records estimated_value" {
  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
  CAPTURE_SH="${_ROOT}/src/wj-studybook/hooks/capture-stop.sh"
  _msg="useEffect cleanup 함수는 메모리 누수 방지를 위한 핵심 패턴이며 언마운트 시 호출됩니다."
  _payload="{\"session_id\":\"b\",\"transcript_path\":\"/dev/null\",\"cwd\":\"/tmp\",\"last_assistant_message\":\"$_msg\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _f=$(ls "$HOME/.studybook/inbox/"*.md 2>/dev/null | head -n1)
  [ -n "$_f" ]
  run grep -E '^estimated_value: [0-9]+\.[0-9]+$' "$_f"
  [ "$status" -eq 0 ]
  rm -rf "$TMP"
}

@test "integration: API key in body masked before save" {
  TMP="$(mktemp -d)"
  export HOME="$TMP"
  mkdir -p "$HOME/.studybook/inbox"
  export CLAUDE_PLUGIN_ROOT="${_ROOT}/src/wj-studybook"
  CAPTURE_SH="${_ROOT}/src/wj-studybook/hooks/capture-stop.sh"
  _msg="API 키 sk_test_FAKE_KEY_abcdef1234567890 는 노출 금지 패턴입니다 보안 원칙 어기지 마세요."
  _payload="{\"session_id\":\"c\",\"transcript_path\":\"/dev/null\",\"cwd\":\"/tmp\",\"last_assistant_message\":\"$_msg\"}"
  run bash -c "echo '$_payload' | bash '$CAPTURE_SH'"
  [ "$status" -eq 0 ]
  _f=$(ls "$HOME/.studybook/inbox/"*.md 2>/dev/null | head -n1)
  [ -n "$_f" ]
  run grep -q "secretkeyabcdef" "$_f"
  [ "$status" -ne 0 ]
  run grep -q "API_KEY_REDACTED" "$_f"
  [ "$status" -eq 0 ]
  rm -rf "$TMP"
}
